"""Inspect or restore one indexed historical copy without overwriting a file.

No --output means a dry run. The private manifest stays outside public Git.
Git-backed copies are restored as exact raw blobs, without checkout filters.
"""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import uuid


def io_path(path):
    value = os.path.abspath(path)
    if os.name != 'nt' or value.startswith('\\\\?\\'):
        return value
    return '\\\\?\\UNC\\' + value[2:] if value.startswith('\\\\') else '\\\\?\\' + value


def safe_relative(value):
    p = PurePosixPath(value.replace('\\', '/'))
    if not value or p.is_absolute() or '..' in p.parts or ':' in value:
        raise ValueError('Expected an indexed relative path')
    return p


def plain_ancestors(path):
    for p in (path, *path.parents):
        if os.path.lexists(io_path(p)) and getattr(os.lstat(io_path(p)), 'st_file_attributes', 0) & 0x400:
            raise ValueError('Reparse-point paths are not accepted: ' + str(p))


def select_record(manifest, original):
    safe_relative(original)
    opener = gzip.open if manifest.suffix == '.gz' else open
    found = None
    with opener(io_path(manifest), 'rt', encoding='utf-8') as source:
        for line in source:
            row = json.loads(line)
            if row['original_relative'] == original:
                if found is not None:
                    raise ValueError('Duplicate original path in manifest')
                found = row
    if found is None:
        raise ValueError('Original path is not indexed')
    return found


def copy_verified(source, destination, expected):
    digest = hashlib.sha256()
    size = 0
    with open(io_path(destination), 'xb') as target:
        while block := source.read(1024 * 1024):
            target.write(block)
            digest.update(block)
            size += len(block)
    if size != expected['logical_bytes'] or digest.hexdigest() != expected['sha256']:
        raise ValueError('Restored bytes do not match the indexed hash')


def restore(repo, row, output=None):
    action = row['action']
    if action not in ('represent_in_retained_git', 'move_exact_private_evidence'):
        raise ValueError('Unknown recovery action')
    if not re.fullmatch('[0-9a-f]{64}', row['sha256']):
        raise ValueError('Invalid indexed SHA256')
    if action == 'represent_in_retained_git':
        if not re.fullmatch('[0-9a-f]{40}', row['git_blob_oid']):
            raise ValueError('Invalid Git blob identity')
        if row.get('alternate_streams'):
            raise ValueError('A raw Git blob cannot recover alternate streams')
    else:
        relative = safe_relative(row['destination_relative'])
        if relative.parts[:2] not in (('.tmp', 'evidence'), ('.git', 'recovery')):
            raise ValueError('Private recovery source is outside indexed evidence roots')
        canonical = repo.joinpath(*relative.parts)
        plain_ancestors(canonical)
        if not os.path.isfile(io_path(canonical)):
            raise ValueError('Indexed private recovery source is missing')
    plan = {'original_relative': row['original_relative'], 'action': action,
            'logical_bytes': row['logical_bytes'], 'sha256': row['sha256'],
            'output': str(output) if output else None, 'dry_run': output is None}
    if output is None:
        return plan
    output = Path(output).absolute()
    plain_ancestors(output)
    if os.path.lexists(io_path(output)):
        raise FileExistsError('Refusing to overwrite ' + str(output))
    os.makedirs(io_path(output.parent), exist_ok=True)
    partial = output.with_name(output.name + '.partial-' + uuid.uuid4().hex)
    process = None
    try:
        if action == 'represent_in_retained_git':
            process = subprocess.Popen(
                ['git', '-c', 'safe.directory=' + repo.as_posix(), '--no-optional-locks',
                 '-C', str(repo), 'cat-file', 'blob', row['git_blob_oid']],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                env={**os.environ, 'GIT_OPTIONAL_LOCKS': '0'})
            copy_verified(process.stdout, partial, row)
            process.stdout.close()
            error = process.stderr.read()
            if process.wait(timeout=30):
                raise ValueError('Git could not read the retained blob: ' + error.decode(errors='replace'))
        else:
            with open(io_path(canonical), 'rb') as source:
                copy_verified(source, partial, row)
            for stream in row.get('alternate_streams', []):
                if not re.fullmatch(r':[^:/\\]+:\$DATA', stream['name']):
                    raise ValueError('Invalid indexed alternate stream')
                with open(io_path(str(canonical) + stream['name']), 'rb') as source:
                    copy_verified(source, str(partial) + stream['name'],
                                  {'logical_bytes': stream['bytes'], 'sha256': stream['sha256']})
        # Prepare metadata before publishing so failures leave no final output.
        os.utime(io_path(partial), ns=(row['mtime_ns'], row['mtime_ns']))
        # On Windows rename refuses an existing destination, including a file
        # created after the initial check. Never replace the user's file.
        if os.name == 'nt':
            os.rename(io_path(partial), io_path(output))
        else:
            os.link(io_path(partial), io_path(output))
            os.unlink(io_path(partial))
        return {**plan, 'dry_run': False, 'restored': True}
    finally:
        if process is not None:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=30)
            for pipe in (process.stdout, process.stderr):
                if pipe is not None and not pipe.closed:
                    pipe.close()
        if os.path.lexists(io_path(partial)):
            os.unlink(io_path(partial))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--original', required=True)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path, help='Explicit new output file; omitted for a dry run')
    args = parser.parse_args()
    row = select_record(args.manifest, args.original)
    print(json.dumps(restore(args.repo.absolute(), row, args.output), indent=2))


if __name__ == '__main__':
    main()
