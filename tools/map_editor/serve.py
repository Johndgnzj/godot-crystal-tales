#!/usr/bin/env python3
"""水晶傳說 — 地圖連通維護工具（塊 A）本地伺服器。

啟動：python3 tools/map_editor/serve.py  → 瀏覽器開 http://localhost:8770

只用 Python 標準庫。提供：
  GET  /                → 編輯器前端 index.html
  GET  /api/map-def     → 讀 assets-source/map/map-def.json
  POST /api/map-def     → 覆寫 map-def.json（存檔前先驗證 JSON，並備份成 .json.bak）
  GET  /assets/<path>   → 唯讀提供 assets-source/ 下的地圖縮圖（設計工具以素材源為準，僅 png）
"""
import http.server
import json
import shutil
import socketserver
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]                     # repo 根目錄
HERE = Path(__file__).resolve().parent
MAP_DEF = ROOT / "assets-source" / "map" / "map-def.json"
ASSETS = (ROOT / "assets-source").resolve()                    # 設計工具以素材源為準，不讀專案產物
PORT = 8770


class Handler(http.server.BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        data = body if isinstance(body, (bytes, bytearray)) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            try:
                self._send(200, (HERE / "index.html").read_bytes(), "text/html; charset=utf-8")
            except OSError as e:
                self._send(500, json.dumps({"error": str(e)}))
            return
        if path == "/api/map-def":
            try:
                self._send(200, MAP_DEF.read_bytes())
            except FileNotFoundError:
                self._send(200, json.dumps({"version": 1, "regions": {}}))
            except OSError as e:
                self._send(500, json.dumps({"error": str(e)}))
            return
        if path.startswith("/assets/"):
            rel = urllib.parse.unquote(path[len("/assets/"):])
            target = (ASSETS / rel).resolve()
            # 防目錄穿越：resolve 後必須仍落在 assets/ 內，且是實際檔案
            if (ASSETS != target and ASSETS not in target.parents) or not target.is_file():
                self._send(404, json.dumps({"error": "not found"}))
                return
            ctype = "image/png" if target.suffix.lower() == ".png" else "application/octet-stream"
            try:
                self._send(200, target.read_bytes(), ctype)
            except OSError as e:
                self._send(500, json.dumps({"error": str(e)}))
            return
        self._send(404, json.dumps({"error": "not found"}))

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path != "/api/map-def":
            self._send(404, json.dumps({"error": "not found"}))
            return
        try:
            length = int(self.headers.get("Content-Length", 0))
            raw = self.rfile.read(length)
            parsed = json.loads(raw)                           # 存檔前先確認是合法 JSON
        except (ValueError, OSError) as e:
            self._send(400, json.dumps({"error": "invalid json: %s" % e}))
            return
        try:
            MAP_DEF.parent.mkdir(parents=True, exist_ok=True)
            if MAP_DEF.exists():
                shutil.copy2(MAP_DEF, MAP_DEF.with_suffix(".json.bak"))   # 覆寫前備份
            MAP_DEF.write_text(json.dumps(parsed, ensure_ascii=False, indent=2) + "\n", "utf-8")
        except OSError as e:
            self._send(500, json.dumps({"error": str(e)}))
            return
        self._send(200, json.dumps({"ok": True}))

    def log_message(self, *_a):                                # 靜音預設每請求逐行 log
        pass


def main():
    socketserver.TCPServer.allow_reuse_address = True          # 重啟免等 TIME_WAIT
    with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
        print("地圖工具已啟動 → http://localhost:%d  (Ctrl+C 結束)" % PORT)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n已停止")


if __name__ == "__main__":
    main()
