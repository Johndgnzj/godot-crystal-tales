#!/usr/bin/env python3
"""Sprite 幀對齊工具 — 本機伺服器（純標準庫，零外部套件）。

流程：載入分離幀或幀條 → 瀏覽器端去背＋錨點對齊＋統一裁切框 → 匯出對齊好的
多幀 PNG（<prefix>_0.png…）到 assets-source/<subdir>/（素材暫存區，未整合進遊戲；
符合 CLAUDE.md「產圖驗收流程」的預覽階段）。也可純用瀏覽器「下載 PNG」不經伺服器。

用法:
    python3 tools/frame_aligner/serve.py            # 起服務並自動開瀏覽器
    python3 tools/frame_aligner/serve.py --port 9000
    python3 tools/frame_aligner/serve.py --no-open
"""
import argparse
import base64
import json
import re
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent.parent                      # tools/frame_aligner -> repo 根
EXPORT_BASE = (REPO_ROOT / "assets-source").resolve()   # 只允許寫進素材源

SUBDIR_RE = re.compile(r"^[a-z0-9_]+(?:/[a-z0-9_]+)*$")  # 例：role/enemies/bear_dire
FILE_RE = re.compile(r"^[a-z][a-z0-9_]*\.png$")          # 例：combat_0.png
DATAURL_RE = re.compile(r"^data:image/png;base64,(.+)$", re.S)
STATIC_TYPES = {".html": "text/html; charset=utf-8",
                ".js": "text/javascript; charset=utf-8",
                ".css": "text/css; charset=utf-8"}
MAX_BODY = 128 * 1024 * 1024                             # request body 上限，擋超大輸入


class Handler(BaseHTTPRequestHandler):
    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # ---- 靜態檔（只服務工具目錄內，擋路徑穿越）----
    def do_GET(self):
        rel = self.path.split("?", 1)[0].lstrip("/") or "index.html"
        target = (TOOL_DIR / rel).resolve()
        if TOOL_DIR not in target.parents and target != TOOL_DIR:
            self._json(403, {"error": "forbidden"})
            return
        if not target.is_file():
            self._json(404, {"error": "not found"})
            return
        data = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type",
                         STATIC_TYPES.get(target.suffix, "application/octet-stream"))
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    # ---- 匯出：POST /api/frames-save {subdir, files:[{name, dataURL}]} ----
    def do_POST(self):
        if self.path.split("?", 1)[0] != "/api/frames-save":
            self._json(404, {"error": "unknown endpoint"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._json(400, {"error": "bad Content-Length"})
            return
        if not 0 < length <= MAX_BODY:
            self._json(413, {"error": "body 為空或過大"})
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (ValueError, UnicodeDecodeError) as e:
            self._json(400, {"error": f"JSON 解析失敗: {e}"})
            return

        subdir = str(payload.get("subdir", "")).strip().strip("/")
        if not SUBDIR_RE.match(subdir):
            self._json(400, {"error": "輸出目錄需為 assets-source 下的相對路徑（小寫英數底線／斜線）"})
            return
        files = payload.get("files")
        if not isinstance(files, list) or not files:
            self._json(400, {"error": "沒有要儲存的檔案"})
            return

        out_dir = (EXPORT_BASE / subdir).resolve()
        if EXPORT_BASE not in out_dir.parents and out_dir != EXPORT_BASE:
            self._json(400, {"error": "非法輸出路徑（超出 assets-source）"})
            return

        # 先全部驗證＋解碼，任一張不合法就整批拒絕（避免只寫一半）
        decoded = []
        for f in files:
            name = str(f.get("name", ""))
            if not FILE_RE.match(name):
                self._json(400, {"error": f"非法檔名: {name}"})
                return
            m = DATAURL_RE.match(str(f.get("dataURL", "")))
            if not m:
                self._json(400, {"error": f"{name} 不是 PNG data URL"})
                return
            try:
                raw = base64.b64decode(m.group(1), validate=True)  # binascii.Error ⊂ ValueError
            except ValueError as e:
                self._json(400, {"error": f"{name} base64 解碼失敗: {e}"})
                return
            decoded.append((name, raw))

        try:
            out_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            self._json(500, {"error": f"建立目錄失敗: {e}"})
            return

        saved = []
        for name, raw in decoded:
            try:
                (out_dir / name).write_bytes(raw)
            except OSError as e:
                self._json(500, {"error": f"寫檔失敗 {name}: {e}"})
                return
            saved.append(str((out_dir / name).relative_to(REPO_ROOT)))

        print("  已匯出 →", "、".join(saved))
        self._json(200, {"saved": saved, "dir": str(out_dir.relative_to(REPO_ROOT))})

    def log_message(self, *args):
        pass  # 靜音預設逐請求 log；匯出成功另外印在 do_POST


def main():
    ap = argparse.ArgumentParser(description="Sprite 幀對齊工具")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8779)
    ap.add_argument("--no-open", action="store_true", help="不自動開瀏覽器")
    args = ap.parse_args()
    sys.stdout.reconfigure(line_buffering=True)   # 即時輸出（含匯出紀錄），別被 block buffer 吃掉

    try:
        server = ThreadingHTTPServer((args.host, args.port), Handler)
    except OSError as e:
        print(f"無法在 {args.host}:{args.port} 啟動（{e}）。用 --port 換個埠再試。")
        sys.exit(1)

    url = f"http://{args.host}:{args.port}/"
    print("Sprite 幀對齊工具已啟動")
    print(f"  網址　：{url}")
    print(f"  匯出至：{EXPORT_BASE}/<輸出目錄>")
    print("  按 Ctrl+C 結束。")
    if not args.no_open:
        try:
            webbrowser.open(url)
        except OSError:
            print("（無法自動開啟瀏覽器，請手動貼上上面的網址）")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n已結束。")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
