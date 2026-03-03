import http.server
import socketserver
import os

os.chdir('/home/user/flutter_app/build/web')

class CORSHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('X-Frame-Options', 'ALLOWALL')
        self.send_header('Content-Security-Policy', 'frame-ancestors *')
        super().end_headers()

    def log_message(self, format, *args):
        pass  # Suppress logs to keep process lightweight

PORT = 5060
with socketserver.TCPServer(('0.0.0.0', PORT), CORSHandler) as httpd:
    print(f'Serving on port {PORT}...')
    httpd.serve_forever()
