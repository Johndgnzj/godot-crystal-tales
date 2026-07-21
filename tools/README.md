# 開發工具集（tools/）

本機小工具，都是**純 Python 標準庫的網頁**，不裝任何套件。

## 啟動

```bash
./tools/start.sh        # 起 hub，自動開瀏覽器 → http://localhost:8800
```

hub 一個入口用漢堡選單整合下面三個網頁工具，同一視窗切換（不用開三次）。

## 各目錄

| 目錄 | 用途 | 單獨啟動（可選）|
|---|---|---|
| `hub/` | **統一入口**：漢堡選單整合下面三個工具（`start.sh` 起的就是它）| `python3 tools/hub/serve.py` → `:8800` |
| `map_editor/` | 地圖連通維護：regions/maps 連通、出入口、備註 → `map-def.json` | `python3 tools/map_editor/serve.py` → `:8770` |
| `role_slicer/` | 角色立繪切圖：去背＋框選，匯出 face/portrait/menuart 三張 | `python3 tools/role_slicer/serve.py` → `:8777` |
| `stickman_animator/` | 火柴人骨架動畫：動作參考 | `python3 tools/stickman_animator/serve.py` → `:8778` |
| `codex/` | 設定集 codex（push 後 CI 自動發佈 GitHub Pages）| 見 [`codex/README.md`](codex/README.md) |
| `githooks/` | git pre-commit hook | — |
| `compose_map_overviews.py` | 舊地圖總覽拼圖腳本（**已過時**）| — |

## 使用說明

各工具的操作說明**寫在工具網頁內**。地圖工具另有完整設計手冊：[`docs/design/地圖區域設計.md`](../docs/design/地圖區域設計.md)。
