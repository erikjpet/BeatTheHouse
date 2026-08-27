"""Local Web server with the isolation headers required by the Web export."""

import argparse
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
    args = parser.parse_args()

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
