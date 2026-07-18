# 設定集 codex 產生器

《水晶戰記》HTML 設定集（game-codex）的產生器：把遊戲資料組成一份可搜尋的單頁 HTML，發佈成 claude.ai Artifact（John 私人用）。

> 之前放在 session scratchpad、每次 session 消失；2026-07-18 收進 repo 並改成自給自足。

## 檔案
- `build_codex.py` — 解析 `content_db.tres` → 遊戲 JSON，注入 `dialogue.json`、立繪縮圖（PIL 即時從 `godot-project/assets/ui/portrait_<id>.png` 等比縮 280px、保留透明）、敵人像素圖 → `crystal_codex.html`。路徑由 `__file__` 推導，跨機器可攜。
- `codex_template.html` — 單頁模板（含手寫 `META`：NPC 說明、地圖、sprite 尺寸、party/NPC 立繪 `img` 對照）。
- `crystal_codex.html` — 產出（gitignored，勿提交）。

## 產生 + 更新 Artifact
```bash
python3 tools/codex/build_codex.py     # 需 Python3 + Pillow(PIL)
```
產出 `crystal_codex.html` 後，用 Claude 的 Artifact 工具帶 `url` 重發**同一網址**（見 memory `game-codex-artifact`）：
- 網址：https://claude.ai/code/artifact/c415ebd5-2431-4065-85d7-5d292a898775

## 什麼自動更新 / 什麼要手改
| 類別 | 來源 | 重跑即更新？ |
|---|---|---|
| 數值/裝備/技能/敵人/商店/道具/寶箱 | `content_db.tres` | ✅ 自動 |
| 對話全文 | `dialogue.json` | ✅ 自動 |
| 角色立繪縮圖 | `assets/ui/portrait_<id>.png` | ✅ 自動 |
| NPC/地圖**文字說明**、`partyMeta`/`npcs[]` 立繪對照 | `codex_template.html` 的 `META` | ✋ 手改 |
| 新增角色立繪 | `build_codex.py` 的 `portrait_ids` 清單 | ✋ 手加 |
