# 設定集 codex 產生器

《水晶傳說》HTML 設定集（game-codex）的產生器：把遊戲資料組成一份可搜尋的單頁 HTML，發佈成 claude.ai Artifact（John 私人用）。

> 之前放在 session scratchpad、每次 session 消失；2026-07-18 收進 repo 並改成自給自足。

## 檔案
- `build_codex.py` — 解析 `content_db.tres` → 遊戲 JSON，解析對話 `.tres` 真相源（`dialogue_db.tres` 聚合的 `npc/*.tres`＋`cuts/*.tres`）、注入立繪縮圖（PIL 即時從 `godot-project/assets/ui/portrait_<id>.png` 等比縮 280px、保留透明）、敵人像素圖 → `crystal_codex.html`。路徑由 `__file__` 推導，跨機器可攜。
- `codex_template.html` — 單頁模板（含手寫 `META`：NPC 說明、地圖、sprite 尺寸、party/NPC 立繪 `img` 對照）。
- `crystal_codex.html` — 完整單頁產出（含內嵌圖，~1.8MB，gitignored，勿提交；對外分享走 Artifact）。
- `data.json` — 資料快照（`{game, dialogue}`，不含圖、~90KB、deterministic）。**進版控**，可用 `git diff` 一眼看出資料異動；由下方 pre-commit hook 自動同步。

## 產生 + 更新 Artifact
```bash
python3 tools/codex/build_codex.py     # 需 Python3 + Pillow(PIL)
```
產出 `crystal_codex.html` 後，用 Claude 的 Artifact 工具帶 `url` 重發**同一網址**（見 memory `game-codex-artifact`）：
- 網址：https://claude.ai/code/artifact/c415ebd5-2431-4065-85d7-5d292a898775

## 資料同步（git pre-commit hook）

`tools/githooks/pre-commit`：commit 動到 `godot-project/resources/content/**` 時，自動重跑本腳本、把最新 `data.json` 加進該次 commit，確保版控快照永遠跟 `.tres` 真相源一致、不脫勾。

- **啟用（每台機器一次）**：`git config core.hooksPath tools/githooks`
- **緊急略過**：`git commit --no-verify`
- 只在 content 變更時觸發，其餘 commit 不受影響；build 失敗會擋 commit（提醒你資料沒同步好）。

## 什麼自動更新 / 什麼要手改
| 類別 | 來源 | 重跑即更新？ |
|---|---|---|
| 數值/裝備/技能/敵人/商店/道具/寶箱 | `content_db.tres` | ✅ 自動 |
| 對話全文（NPC＋過場）| `dialogue/**/*.tres`（`dialogue_db.tres` 聚合）| ✅ 自動 |
| 角色立繪縮圖 | `assets/ui/portrait_<id>.png` | ✅ 自動 |
| NPC/地圖**文字說明**、`partyMeta`/`npcs[]` 立繪對照 | `codex_template.html` 的 `META` | ✋ 手改 |
| 新增角色立繪 | `build_codex.py` 的 `portrait_ids` 清單 | ✋ 手加 |
