#!/usr/bin/env python3
"""水晶傳說工具集 Hub — 一個 port 整合四個本機工具。

一次啟動、一個入口頁（漢堡選單），四個工具在同一視窗切換（同源 iframe）：
  地圖連通維護（map_editor）／角色立繪切圖（role_slicer）／火柴人動畫（stickman_animator）
  ／Sprite 幀對齊（frame_aligner）。取代各別的 serve.py／start.sh。純標準庫、零外部套件。

用法:
    python3 tools/hub/serve.py                     # 起服務並自動開瀏覽器
    python3 tools/hub/serve.py --port 8800
    python3 tools/hub/serve.py --no-open
    python3 tools/hub/serve.py --map-def <path>    # 指定要載入哪份 map-def.json
    python3 tools/hub/serve.py --out <dir>         # 立繪切圖匯出根目錄（預設：執行目錄下 exports/）
"""
import argparse
import base64
import json
import re
import shutil
import sys
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HUB_DIR = Path(__file__).resolve().parent           # tools/hub
TOOLS_DIR = HUB_DIR.parent                           # tools
REPO_ROOT = TOOLS_DIR.parent                         # repo 根

# 前綴 → 該工具前端目錄（同源 iframe 從這裡載入）
TOOL_FRONTENDS = {
    "map": TOOLS_DIR / "map_editor",
    "slicer": TOOLS_DIR / "role_slicer",
    "stickman": TOOLS_DIR / "stickman_animator",
    "aligner": TOOLS_DIR / "frame_aligner",
}

DEFAULT_MAP_DEF = REPO_ROOT / "assets-source" / "map" / "map-def.json"
ASSETS = (REPO_ROOT / "assets-source").resolve()     # 地圖縮圖來源＝素材源

# 立繪切圖：檔名／id 驗證（沿用 role_slicer）
ID_RE = re.compile(r"^[a-z][a-z0-9_]{0,31}$")
FILE_RE = re.compile(r"^(face|portrait|menuart)_[a-z0-9_]{1,32}\.png$")
DATAURL_RE = re.compile(r"^data:image/png;base64,(.+)$", re.S)
MAX_BODY = 96 * 1024 * 1024

# Sprite 幀對齊：輸出目錄／檔名驗證（沿用 frame_aligner，直接寫回 assets-source）
SUBDIR_RE = re.compile(r"^[a-z0-9_]+(?:/[a-z0-9_]+)*$")
FRAME_FILE_RE = re.compile(r"^[a-z][a-z0-9_]*\.png$")

STATIC_TYPES = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8",
                ".css": "text/css; charset=utf-8", ".json": "application/json; charset=utf-8",
                ".png": "image/png"}

# 由 main() 依參數覆寫
MAP_DEF = DEFAULT_MAP_DEF
EXPORT_BASE = Path.cwd() / "exports"


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        data = body if isinstance(body, (bytes, bytearray)) else body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def _static(self, base: Path, rel: str):
        target = (base / rel).resolve()
        if base != target and base not in target.parents:      # 擋路徑穿越
            self._json(403, {"error": "forbidden"})
            return
        if not target.is_file():
            self._json(404, {"error": "not found"})
            return
        self._send(200, target.read_bytes(),
                   STATIC_TYPES.get(target.suffix.lower(), "application/octet-stream"))

    def do_GET(self):
        path = self.path.split("?", 1)[0]
        if path in ("/", "/index.html"):
            self._static(HUB_DIR, "index.html")
            return
        # 三個工具前端：/map/…、/slicer/…、/stickman/…
        for key, base in TOOL_FRONTENDS.items():
            if path == f"/{key}" or path == f"/{key}/":
                self._static(base, "index.html")
                return
            if path.startswith(f"/{key}/"):
                self._static(base, path[len(f"/{key}/"):])
                return
        # 地圖維護 API：載入目前選定的 map-def.json
        if path == "/api/map-def":
            try:
                self._send(200, MAP_DEF.read_bytes())
            except FileNotFoundError:
                self._send(200, json.dumps({"version": 1, "regions": {}}))
            except OSError as e:
                self._json(500, {"error": str(e)})
            return
        # 目前載入的 map-def 是哪份（給前端顯示）
        if path == "/api/map-def-info":
            self._json(200, {"path": str(MAP_DEF),
                             "name": MAP_DEF.name,
                             "exists": MAP_DEF.is_file()})
            return
        # 同目錄下可選的 map-def（讓前端切換）
        if path == "/api/map-defs":
            d = MAP_DEF.parent
            files = sorted(f.name for f in d.glob("*.json")) if d.is_dir() else []
            self._json(200, {"dir": str(d), "current": MAP_DEF.name, "files": files})
            return
        # 立繪切圖的匯出根目錄（給前端顯示，反映 --out）
        if path == "/api/export-info":
            self._json(200, {"base": str(EXPORT_BASE)})
            return
        # 地圖縮圖（唯讀，來自 assets-source）
        if path.startswith("/assets/"):
            target = (ASSETS / path[len("/assets/"):]).resolve()
            if (ASSETS != target and ASSETS not in target.parents) or not target.is_file():
                self._json(404, {"error": "not found"})
                return
            ctype = "image/png" if target.suffix.lower() == ".png" else "application/octet-stream"
            self._send(200, target.read_bytes(), ctype)
            return
        self._json(404, {"error": "not found"})

    def do_POST(self):
        path = self.path.split("?", 1)[0]
        if path == "/api/map-def":
            self._save_map_def()
        elif path == "/api/map-def-select":
            self._select_map_def()
        elif path == "/save":
            self._save_portraits()
        elif path == "/api/frames-save":
            self._save_frames()
        else:
            self._json(404, {"error": "unknown endpoint"})

    def _read_body(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            return None, (400, "bad Content-Length")
        if not 0 < length <= MAX_BODY:
            return None, (413, "body 為空或過大")
        return self.rfile.read(length), None

    def _save_map_def(self):
        raw, err = self._read_body()
        if err:
            self._json(err[0], {"error": err[1]})
            return
        try:
            parsed = json.loads(raw)
        except ValueError as e:
            self._json(400, {"error": f"invalid json: {e}"})
            return
        try:
            MAP_DEF.parent.mkdir(parents=True, exist_ok=True)
            if MAP_DEF.exists():
                shutil.copy2(MAP_DEF, MAP_DEF.with_suffix(".json.bak"))
            MAP_DEF.write_text(json.dumps(parsed, ensure_ascii=False, indent=2) + "\n", "utf-8")
        except OSError as e:
            self._json(500, {"error": str(e)})
            return
        self._json(200, {"ok": True})

    def _select_map_def(self):
        global MAP_DEF
        raw, err = self._read_body()
        if err:
            self._json(err[0], {"error": err[1]})
            return
        try:
            name = str(json.loads(raw).get("name", ""))
        except ValueError as e:
            self._json(400, {"error": f"invalid json: {e}"})
            return
        cand = (MAP_DEF.parent / name).resolve()   # 只允許同目錄下的 .json，擋路徑穿越
        if cand.parent != MAP_DEF.parent or cand.suffix != ".json" or not cand.is_file():
            self._json(400, {"error": "只能切換到同目錄下存在的 .json"})
            return
        MAP_DEF = cand
        print("  切換 map-def →", MAP_DEF)
        self._json(200, {"ok": True, "current": MAP_DEF.name})

    def _save_portraits(self):
        raw, err = self._read_body()
        if err:
            self._json(err[0], {"error": err[1]})
            return
        try:
            payload = json.loads(raw.decode("utf-8"))
        except (ValueError, UnicodeDecodeError) as e:
            self._json(400, {"error": f"JSON 解析失敗: {e}"})
            return
        char_id = str(payload.get("id", "")).strip().lower()
        if not ID_RE.match(char_id):
            self._json(400, {"error": "角色 id 需字母開頭、只含英數底線"})
            return
        files = payload.get("files")
        if not isinstance(files, list) or not files:
            self._json(400, {"error": "沒有要儲存的檔案"})
            return
        out_dir = (EXPORT_BASE / char_id).resolve()
        if EXPORT_BASE != out_dir.parent and EXPORT_BASE not in out_dir.parents:
            self._json(400, {"error": "非法輸出路徑"})
            return
        # 先全部驗證＋解碼，任一張不合法就整批拒絕（避免只寫一半）
        decoded = []
        for f in files:
            name = str(f.get("name", ""))
            if not FILE_RE.match(name) or not name.endswith(f"_{char_id}.png"):
                self._json(400, {"error": f"檔名與 id 不符或非法: {name}"})
                return
            m = DATAURL_RE.match(str(f.get("dataURL", "")))
            if not m:
                self._json(400, {"error": f"{name} 不是 PNG data URL"})
                return
            try:
                data = base64.b64decode(m.group(1), validate=True)
            except ValueError as e:
                self._json(400, {"error": f"{name} base64 解碼失敗: {e}"})
                return
            decoded.append((name, data))
        try:
            out_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            self._json(500, {"error": f"建立目錄失敗: {e}"})
            return
        saved = []
        for name, data in decoded:
            try:
                (out_dir / name).write_bytes(data)
            except OSError as e:
                self._json(500, {"error": f"寫檔失敗 {name}: {e}"})
                return
            saved.append(name)
        print("  已匯出 →", out_dir, "：", "、".join(saved))
        self._json(200, {"saved": saved, "dir": str(out_dir)})

    def _save_frames(self):
        """Sprite 幀對齊：寫回 assets-source/<subdir>（沿用 frame_aligner/serve.py 的防護）。"""
        raw, err = self._read_body()
        if err:
            self._json(err[0], {"error": err[1]})
            return
        try:
            payload = json.loads(raw.decode("utf-8"))
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
        out_dir = (ASSETS / subdir).resolve()
        if ASSETS != out_dir and ASSETS not in out_dir.parents:
            self._json(400, {"error": "非法輸出路徑（超出 assets-source）"})
            return
        # 先全部驗證＋解碼，任一張不合法就整批拒絕（避免只寫一半）
        decoded = []
        for f in files:
            name = str(f.get("name", ""))
            if not FRAME_FILE_RE.match(name):
                self._json(400, {"error": f"非法檔名: {name}"})
                return
            m = DATAURL_RE.match(str(f.get("dataURL", "")))
            if not m:
                self._json(400, {"error": f"{name} 不是 PNG data URL"})
                return
            try:
                data = base64.b64decode(m.group(1), validate=True)
            except ValueError as e:
                self._json(400, {"error": f"{name} base64 解碼失敗: {e}"})
                return
            decoded.append((name, data))
        try:
            out_dir.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            self._json(500, {"error": f"建立目錄失敗: {e}"})
            return
        saved = []
        for name, data in decoded:
            try:
                (out_dir / name).write_bytes(data)
            except OSError as e:
                self._json(500, {"error": f"寫檔失敗 {name}: {e}"})
                return
            saved.append(name)
        print("  已匯出（幀對齊）→", out_dir, "：", "、".join(saved))
        self._json(200, {"saved": saved, "dir": str(out_dir.relative_to(REPO_ROOT))})

    def log_message(self, *args):
        pass  # 靜音逐請求 log；匯出成功另外印在 _save_portraits／_save_frames


def main():
    global MAP_DEF, EXPORT_BASE
    ap = argparse.ArgumentParser(description="水晶傳說工具集 Hub")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8800)
    ap.add_argument("--no-open", action="store_true", help="不自動開瀏覽器")
    ap.add_argument("--map-def", default=str(DEFAULT_MAP_DEF),
                    help="要載入的 map-def.json（預設：專案 assets-source/map/map-def.json）")
    ap.add_argument("--out", default=str(Path.cwd() / "exports"),
                    help="立繪切圖匯出根目錄（預設：執行目錄下 exports/）")
    args = ap.parse_args()

    MAP_DEF = Path(args.map_def).resolve()
    EXPORT_BASE = Path(args.out).resolve()
    sys.stdout.reconfigure(line_buffering=True)

    try:
        server = ThreadingHTTPServer((args.host, args.port), Handler)
    except OSError as e:
        print(f"無法在 {args.host}:{args.port} 啟動（{e}）。用 --port 換個埠再試。")
        sys.exit(1)

    url = f"http://{args.host}:{args.port}/"
    print("水晶傳說工具集 Hub 已啟動")
    print(f"  入口　：{url}")
    print(f"  地圖　：{MAP_DEF}")
    print(f"  匯出至：{EXPORT_BASE}")
    print("  Ctrl+C 結束。")
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
