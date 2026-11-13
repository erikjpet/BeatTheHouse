from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
import sys,json,threading
# Read-only server; all mutable runtime/evidence paths belong to the outer
# maintained storage gate and capped Job. This helper spawns no child process.
directory=Path(sys.argv[1]).resolve()
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*args,**kwargs): super().__init__(*args,directory=str(directory),**kwargs)
 def end_headers(self):
  self.send_header('Cross-Origin-Opener-Policy','same-origin')
  self.send_header('Cross-Origin-Embedder-Policy','require-corp')
  super().end_headers()
 def do_POST(self):
  if self.path!='/__shutdown': self.send_error(404); return
  self.send_response(200); self.end_headers(); self.wfile.write(b'closed')
  threading.Thread(target=self.server.shutdown,daemon=True).start()
server=ThreadingHTTPServer(('127.0.0.1',int(sys.argv[2]) if len(sys.argv)>2 else 0),Handler)
print('ENVART_QA_SERVER '+json.dumps({'url':'http://127.0.0.1:'+str(server.server_port),'directory':str(directory)}),flush=True)
server.serve_forever()
server.server_close()
