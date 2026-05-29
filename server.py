#!/usr/bin/env python3
"""Simple HTTP server with download support."""
import http.server
import os
import urllib.parse

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class DownloadHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)

        # /download/<filename> serves file as attachment
        if parsed.path.startswith('/download/'):
            filename = parsed.path[len('/download/'):]
            filepath = os.path.join(DIRECTORY, filename)
            if os.path.isfile(filepath):
                self.send_response(200)
                self.send_header('Content-Type', 'application/octet-stream')
                self.send_header('Content-Disposition', f'attachment; filename="{filename}"')
                fs = os.path.getsize(filepath)
                self.send_header('Content-Length', str(fs))
                self.end_headers()
                with open(filepath, 'rb') as f:
                    self.copyfile(f, self.wfile)
                return
            else:
                self.send_error(404, "File not found")
                return

        # Normal file serving
        super().do_GET()

    def list_directory(self, path):
        """Generate a directory listing with download links."""
        try:
            entries = sorted(os.listdir(path))
        except OSError:
            self.send_error(500, "Unable to list directory")
            return None

        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()

        html = f'''<!DOCTYPE html>
<html lang="pt">
<head>
<meta charset="utf-8">
<title>Workspace Files</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    background: #0d1117; color: #c9d1d9; padding: 2rem; max-width: 800px; margin: auto;
  }}
  h1 {{ font-size: 1.5rem; margin-bottom: 1.5rem; color: #58a6ff; }}
  ul {{ list-style: none; }}
  li {{
    display: flex; align-items: center; gap: 1rem;
    padding: 0.75rem 1rem; margin-bottom: 0.5rem;
    background: #161b22; border: 1px solid #30363d; border-radius: 6px;
    transition: border-color 0.2s;
  }}
  li:hover {{ border-color: #58a6ff; }}
  .file-icon {{ font-size: 1.2rem; }}
  .file-name {{ flex: 1; color: #58a6ff; text-decoration: none; }}
  .file-name:hover {{ text-decoration: underline; }}
  .download-link {{ 
    padding: 0.3rem 0.8rem; background: #21262d; color: #c9d1d9;
    border: 1px solid #30363d; border-radius: 4px; text-decoration: none;
    font-size: 0.85rem; transition: all 0.2s;
  }}
  .download-link:hover {{ background: #30363d; border-color: #58a6ff; color: #58a6ff; }}
  .size {{ color: #8b949e; font-size: 0.85rem; }}
  .path {{ font-size: 0.85rem; color: #8b949e; margin-bottom: 1rem; }}
</style>
</head>
<body>
<h1>📂 Workspace Files</h1>
<div class="path">{self.path}</div>
<ul>
'''
        for name in entries:
            if name.startswith('.'):
                continue
            fullpath = os.path.join(path, name)
            is_dir = os.path.isdir(fullpath)
            try:
                size = os.path.getsize(fullpath)
            except OSError:
                size = 0
            icon = '📁' if is_dir else '📄'
            size_str = f'{size:,} bytes' if not is_dir else ''
            view_url = urllib.parse.quote(name)
            download_url = f'/download/{urllib.parse.quote(name)}'

            html += f'''<li>
  <span class="file-icon">{icon}</span>
  <a href="{view_url}" class="file-name">{name}</a>
  <span class="size">{size_str}</span>
  <a href="{download_url}" class="download-link">⬇ Download</a>
</li>\n'''

        html += '''</ul>
</body>
</html>'''
        self.wfile.write(html.encode('utf-8'))
        return None


if __name__ == '__main__':
    os.chdir(DIRECTORY)
    server = http.server.HTTPServer(('0.0.0.0', PORT), DownloadHandler)
    print(f'Servidor em http://0.0.0.0:{PORT}')
    print(f'Download disponível via /download/<ficheiro>')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\nServidor parado.')
