"""Tiny HTTP health server. Run as a standalone process alongside lichess-bot."""
import http.server
import os

PORT = int(os.environ.get("PORT", 10000))

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, *args):
        pass  # silence access logs

print(f"[health] listening on port {PORT}", flush=True)
http.server.HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
