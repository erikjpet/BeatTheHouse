"""Local Web server with the isolation headers required by the Web export."""

import argparse
import os
from pathlib import Path
import threading
import time
from http.server import HTTPServer, SimpleHTTPRequestHandler


class IsolatedHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, directory: str, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self) -> None:
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def copyfile(self, source, outputfile) -> None:
        # Browsers routinely abort/re-request large assets; ignore the noise.
        try:
            super().copyfile(source, outputfile)
        except ConnectionError:
            pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--root", required=True)
    parser.add_argument("--shutdown-file")
    parser.add_argument("--shutdown-ack-file")
    parser.add_argument("--shutdown-nonce")
    args = parser.parse_args()

    shutdown_values = (args.shutdown_file, args.shutdown_ack_file, args.shutdown_nonce)
    if any(shutdown_values) and not all(shutdown_values):
        parser.error("shutdown request, acknowledgement and nonce must be supplied together")

    if all(shutdown_values):
        request_path = Path(args.shutdown_file)
        acknowledgement_path = Path(args.shutdown_ack_file)

        def acknowledge_shutdown() -> None:
            while True:
                try:
                    if request_path.read_text(encoding="ascii") == args.shutdown_nonce:
                        temporary_path = Path(f"{acknowledgement_path}.{os.getpid()}.tmp")
                        temporary_path.write_text(
                            f"{args.shutdown_nonce}:{os.getpid()}", encoding="ascii"
                        )
                        os.replace(temporary_path, acknowledgement_path)
                        return
                except OSError:
                    pass
                time.sleep(0.02)

        threading.Thread(target=acknowledge_shutdown, daemon=True).start()

    def handler(*handler_args, **handler_kwargs):
        return IsolatedHandler(*handler_args, directory=args.root, **handler_kwargs)

    print(f"Serving {args.root}", flush=True)
    print(
        f"  http://127.0.0.1:{args.port}  "
        "(required GDExtension isolation headers)",
        flush=True,
    )
    print("  Ctrl+C to stop.", flush=True)
    HTTPServer(("127.0.0.1", args.port), handler).serve_forever()


if __name__ == "__main__":
    main()
