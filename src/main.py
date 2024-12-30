from http.server import HTTPServer, SimpleHTTPRequestHandler
import os

# Retrieve PORT from environment, default to 8000
PORT = int(os.getenv("PORT", "8000"))

class MyHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-type", "text/plain")
        self.end_headers()
        self.wfile.write(b"Hello from Trilogy App")

if __name__ == '__main__':
    httpd = HTTPServer(('0.0.0.0', PORT), MyHandler)
    print(f"Serving on port {PORT}")
    httpd.serve_forever()

