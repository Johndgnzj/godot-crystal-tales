# 設定集 codex 產生器

《水晶傳說》HTML 設定集（game-codex）的產生器：把遊戲資料組成一份可搜尋的單頁 HTML，
**由 GitHub Actions 在 push 後建置並發佈到 GitHub Pages**（取代舊的 claude.ai Artifact 發佈）。

> 沿革：最早放 session scratchpad（每次消失）→ 2026-07-18 收進 repo、自給自足 →
> 2026-07-21 改為 **CI 建置＋GitHub Pages 發佈**，不再手動重發 Artifact。

## 檔案
- `build_codex.py` — 解析 `content_db.tres` → 遊戲 JSON，解析對話 `.tres` 真相源（`dialogue_db.tres`
  聚合的 `npc/*.tres`＋`cuts/*.tres`），掃 `assets-source/role/` 產**圖片相對路徑映射**（`IMG`，
  非 base64——圖片直接參考專案素材），注入 `codex_template.html` → `crystal_codex.html`＋`data.json`。
  路徑由 `__file__` 推導、跨機器可攜；**只用 Python3 標準庫，無外部相依**。
- `codex_template.html` — 單頁模板（骨架／樣式／vanilla JS 邏輯，含 `__IMG_JSON__`/`__DLG_JSON__`/
  `__GAME_JSON__` 佔位符與手寫 `META`：NPC/地圖文字說明、關鍵角色 `keyChars`、敵人 `foeArt`/`foeDesc`、
  `partyMeta`）。版面依 claude.ai/design 設計稿（見 memory `codex-design-source`）。
- `crystal_codex.html` — 完整單頁產出（文字內嵌、圖片走相對路徑 `../../assets-source/role/...`）。
  **gitignored、不進版控**：由 CI 建置＋部署，本地重跑腳本也會產一份供預覽。
- `data.json` — 資料快照（`{game, dialogue}`，不含圖、~90KB、deterministic）。**進版控**，
  可用 `git diff` 一眼看出資料異動；由下方 pre-commit hook 自動同步。

## 發佈：GitHub Actions → GitHub Pages
`.github/workflows/codex.yml`：push 到 `main` 且動到「資料／立繪素材／模板／產生器」其一時（或手動
`workflow_dispatch`），CI 會 `python3 tools/codex/build_codex.py`、只挑 HTML 實際引用到的圖組成站台、
部署到 GitHub Pages。

- **網址**：https://johndgnzj.github.io/godot-crystal-tales/ （根目錄自動轉址到 codex）
- **一次性設定**（repo 設定，只需做一次）：Settings → Pages → Build and deployment → Source 選
  **GitHub Actions**。沒開的話 CI 的 deploy 步驟會失敗。
- 圖片是全解析度原圖（依「圖片直接參考專案素材」策略），站台約 ~78MB；瀏覽器 `loading=lazy` 只載可見的。

## 本地預覽
```bash
python3 tools/codex/build_codex.py          # 產出 crystal_codex.html＋data.json（無需 pip install）
# 圖片是相對路徑，需從 repo root 起 server 才載得到圖：
python3 -m http.server 8899                  # 然後開 http://127.0.0.1:8899/tools/codex/crystal_codex.html
```

## 資料同步（git pre-commit hook）
`tools/githooks/pre-commit`：commit 動到 `godot-project/resources/content/**` 時，自動重跑本腳本、
把最新 `data.json` 加進該次 commit，確保版控快照永遠跟 `.tres` 真相源一致、不脫勾。
（`crystal_codex.html` 不由 hook 管——它由 CI 建置發佈。）

- **啟用（每台機器一次）**：`git config core.hooksPath tools/githooks`
- **緊急略過**：`git commit --no-verify`
- 只在 content 變更時觸發；build 失敗會擋 commit（提醒你資料沒同步好）。

## 什麼自動更新 / 什麼要手改
| 類別 | 來源 | 重跑即更新？ |
|---|---|---|
| 數值/裝備/技能/敵人/商店/道具/寶箱 | `content_db.tres` | ✅ 自動 |
| 對話全文（NPC＋過場）| `dialogue/**/*.tres`（`dialogue_db.tres` 聚合）| ✅ 自動 |
| 立繪／頭像／敵人圖 | `assets-source/role/<類>/<id>/`（face/portrait/menuart/bounty/combat/battle_idle）| ✅ 自動（`build_img()` 掃目錄）|
| NPC/地圖**文字說明**、關鍵角色、敵人描述、立繪對照 | `codex_template.html` 的 `META`（`npcs`/`keyChars`/`foeArt`/`foeDesc`/`partyMeta`）| ✋ 手改 |
