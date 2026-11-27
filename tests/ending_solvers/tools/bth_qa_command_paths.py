"""Admit known writable CLI paths without reading or executing the command.

Unknown flags, positional inputs and hardcoded paths inside scripts are outside
this adapter's scope; workers must still follow their admitted storage manifest.
"""
import ntpath
import os
from pathlib import Path

from bth_qa_storage import StorageGuardError, validate_layout

_FLAGS = {"--user-data-dir", "--disk-cache-dir", "--log-file", "--output",
          "--output-dir", "--path"}
_IDENTITIES = {"--user-data-dir": "profile", "--path": "workspace"}


def _key(path):
    return ntpath.normcase(ntpath.normpath(os.fspath(path)))


def command_write_paths(layout, command):
    """Validate known path arguments and return paths for the final launch gate.

    Relative values are based on layout.workspace, never the caller's cwd.
    Repeated profile/workspace flags are allowed only with the same identity.
    """
    if isinstance(command, (str, bytes)):
        raise StorageGuardError("invalid_command", command, "pass an argument sequence, not shell text")
    try:
        tokens = tuple(os.fspath(value) for value in command)
    except TypeError as error:
        raise StorageGuardError("invalid_command", command, "command arguments must be strings") from error
    if any(not isinstance(token, str) for token in tokens):
        raise StorageGuardError("invalid_command", command, "command arguments must be strings")
    paths, identities = [], {}
    index = 0
    while index < len(tokens):
        flag, separator, value = tokens[index].partition("=")
        index += 1
        if flag not in _FLAGS:
            continue
        if not separator:
            if index >= len(tokens) or tokens[index].startswith("--"):
                raise StorageGuardError("missing_command_path", flag, "known writable flag requires a value")
            value = tokens[index]
            index += 1
        if not value or not value.strip():
            raise StorageGuardError("missing_command_path", flag, "known writable flag requires a value")
        path = Path(ntpath.join(str(layout.workspace), value))
        paths.append(path)
        if flag in _IDENTITIES:
            if flag in identities and _key(identities[flag]) != _key(path):
                raise StorageGuardError("conflicting_command_path", flag, "repeated identity flags disagree")
            identities[flag] = path
    admitted = tuple(paths)
    validate_layout(layout, extra_write_paths=admitted)
    for flag, path in identities.items():
        expected = getattr(layout, _IDENTITIES[flag])
        if _key(path) != _key(expected):
            raise StorageGuardError("command_path_mismatch", path, f"{flag} must equal admitted {_IDENTITIES[flag]} {expected}")
    return admitted
