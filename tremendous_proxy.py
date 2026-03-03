#!/usr/bin/env python3
"""
Tremendous API Proxy Server for BMB Mobile (web preview).

Runs on port 5061. The Flutter web app calls this proxy instead of
Tremendous directly, avoiding CORS blocks. The proxy forwards requests
to testflight.tremendous.com with the API key and returns the response
with CORS headers.

Endpoints:
  POST /api/orders        -> POST  testflight.tremendous.com/api/v2/orders
  GET  /api/orders/<id>   -> GET   testflight.tremendous.com/api/v2/orders/<id>
  GET  /api/products      -> GET   testflight.tremendous.com/api/v2/products
  GET  /api/funding       -> GET   testflight.tremendous.com/api/v2/funding_sources
  GET  /health            -> 200 OK (health check)
"""

import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

TREMENDOUS_BASE = 'https://testflight.tremendous.com/api/v2'
API_KEY = 'TEST_PmLSvF78C--TRuLwTDtU4sbN2Dq1JsQeERXpwqEIc8V'
PORT = 5061


class ProxyHandler(BaseHTTPRequestHandler):
    """Proxies requests to Tremendous API with CORS headers."""

    def _cors_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers',
                         'Content-Type, Authorization, Accept')
        self.send_header('Content-Type', 'application/json')

    def do_OPTIONS(self):
        self.send_response(200)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        path = self.path

        if path == '/health':
            self.send_response(200)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode())
            return

        # Map local paths to Tremendous endpoints
        tremendous_path = None
        if path.startswith('/api/orders/'):
            order_id = path.split('/api/orders/')[1]
            tremendous_path = f'/orders/{order_id}'
        elif path == '/api/products':
            tremendous_path = '/products'
        elif path == '/api/funding':
            tremendous_path = '/funding_sources'

        if tremendous_path is None:
            self.send_response(404)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'error': 'Not found'}).encode())
            return

        self._proxy_get(tremendous_path)

    def do_POST(self):
        if self.path == '/api/orders':
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else b''
            self._proxy_post('/orders', body)
        else:
            self.send_response(404)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'error': 'Not found'}).encode())

    def _proxy_get(self, path):
        url = f'{TREMENDOUS_BASE}{path}'
        req = Request(url, method='GET')
        req.add_header('Authorization', f'Bearer {API_KEY}')
        req.add_header('Accept', 'application/json')

        try:
            with urlopen(req) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self._cors_headers()
                self.end_headers()
                self.wfile.write(data)
        except HTTPError as e:
            self.send_response(e.code)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(e.read())
        except URLError as e:
            self.send_response(502)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def _proxy_post(self, path, body):
        url = f'{TREMENDOUS_BASE}{path}'
        req = Request(url, data=body, method='POST')
        req.add_header('Authorization', f'Bearer {API_KEY}')
        req.add_header('Content-Type', 'application/json')
        req.add_header('Accept', 'application/json')

        try:
            with urlopen(req) as resp:
                data = resp.read()
                self.send_response(resp.status)
                self._cors_headers()
                self.end_headers()
                self.wfile.write(data)
        except HTTPError as e:
            self.send_response(e.code)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(e.read())
        except URLError as e:
            self.send_response(502)
            self._cors_headers()
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def log_message(self, format, *args):
        """Suppress default logging to keep output clean."""
        pass


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else PORT
    server = HTTPServer(('0.0.0.0', port), ProxyHandler)
    print(f'Tremendous proxy running on port {port}')
    server.serve_forever()
