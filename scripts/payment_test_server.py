"""Local server for payment-gateway testing.

Serves build/web_uat (scripts/build_web_uat.ps1) on a fixed port. The gateway returns the user with a POST to
the return / cancel URL, which a plain static server rejects: POST requests
are logged (first 500 bytes of the body) and answered with a 303 redirect to
"/" so the browser reloads the app with a GET.

The UAT build uses --base-href /vytldev/, so its asset URLs start with
/vytldev/; that prefix is stripped so the build also works from "/".

The app uses path URLs (/vytldev/open), so a path with no file behind it and
no extension is answered with index.html, as the real server must do.
"""

import os
import socketserver
from functools import partial
from http.server import HTTPServer, SimpleHTTPRequestHandler

PORT = 8000
BASE_HREF = "/vytldev"
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web_uat")


class PaymentTestHandler(SimpleHTTPRequestHandler):
    def translate_path(self, path):
        if path == BASE_HREF or path.startswith(BASE_HREF + "/"):
            path = path[len(BASE_HREF):] or "/"

        result = super().translate_path(path)

        if not os.path.exists(result) and "." not in os.path.basename(result):
            result = os.path.join(self.directory, "index.html")

        return result

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length > 0 else b""

        print(f"POST {self.path} ({length} bytes)")
        print(body[:500])

        self.send_response(303)
        self.send_header("Location", "/")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def log_message(self, format, *args):
        pass


class ThreadingHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    handler = partial(PaymentTestHandler, directory=os.path.abspath(WEB_DIR))

    with ThreadingHTTPServer(("", PORT), handler) as server:
        print(f"Serving {os.path.abspath(WEB_DIR)} on http://localhost:{PORT}/")
        server.serve_forever()
