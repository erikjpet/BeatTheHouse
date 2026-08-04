# Serves the local Web build with production-compatible isolation headers.
#
# The shipped 0.5 Web preset is single-threaded and does not require
# SharedArrayBuffer. These headers preserve compatibility with isolated hosting
# and make this local server representative of stricter production embeds:
#   Cross-Origin-Opener-Policy: same-origin
#   Cross-Origin-Embedder-Policy: require-corp
# This script serves builds/web with those headers while retaining normal
# single-thread operation when a host does not provide them.
#
# Examples:
#   .\tools\serve_web.ps1               # serve at http://127.0.0.1:8060 and open a browser
#   .\tools\serve_web.ps1 -Port 9000
#   .\tools\serve_web.ps1 -NoBrowser
#
# Requires Python 3 on PATH. Press Ctrl+C to stop.

param(
    [int]$Port = 8060,
    [switch]$NoBrowser
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$webDir = Join-Path $root "builds/web"

if (-not (Test-Path (Join-Path $webDir "index.html"))) {
    throw "No web build found at $webDir. Run .\tools\export_itch.ps1 first."
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python 3 was not found on PATH (needed for the local headers server)."
}

$server = @'
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler

port = int(sys.argv[1])
directory = sys.argv[2]

class IsolatedHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=directory, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()

    def copyfile(self, source, outputfile):
        # Browsers routinely abort/re-request large assets; ignore the noise.
        try:
            super().copyfile(source, outputfile)
        except ConnectionError:
            pass

print(f"Serving {directory}")
print(f"  http://127.0.0.1:{port}  (production-compatible isolation headers)")
print("  Ctrl+C to stop.")
HTTPServer(("127.0.0.1", port), IsolatedHandler).serve_forever()
'@

if (-not $NoBrowser) {
    Start-Process "http://127.0.0.1:$Port"
}

$server | python - $Port $webDir
