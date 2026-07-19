#!/usr/bin/env python3
"""火柴人骨架動畫工具 — 本地伺服器（純靜態）。

用法：python3 serve.py  → 自動開瀏覽器。
一般瀏覽器直接雙擊 index.html 也能用；此檔僅為與 role_slicer 一致的零摩擦啟動。
"""
import http.server
import socketserver
import webbrowser
import os
import threading

PORT = 8778


class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):  # 靜音存取紀錄
        pass


def main():
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    url = f"http://127.0.0.1:{PORT}/index.html"
    try:
        with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
            print(f"火柴人骨架動畫工具 → {url}\n（Ctrl+C 結束）")
            threading.Timer(0.6, lambda: webbrowser.open(url)).start()
            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\n再見！")
    except OSError as e:
        print(f"啟動失敗（連接埠 {PORT} 可能被占用）：{e}")


if __name__ == "__main__":
    main()
