# GDevelop 凍結參考快照

原 GDevelop 專案（`../GDevelop/projects/crystal-quest`）中仍被本 repo 引用的檔案，於 **2026-07-16**
複製進來的**唯讀凍結快照**。自此本 repo 不再依賴 GDevelop 目錄的存在。

| 檔案 | 原始位置 | 用途 |
|---|---|---|
| `build_cq2.py` | `projects/crystal-quest/scripts/` | 遊戲規則唯一真相來源（specs/ 的行號皆對照此檔）；`extract_dialogue.py`／`verify_dialogue.py` 的抽取來源 |
| `CONTENT.json` | `projects/crystal-quest/` | 最初的資料種子；`sync_content.py` 重新匯入時的來源（平時不用，.tres 才是真相源） |
| `DEV_開發指南.md` | `projects/crystal-quest/` | WORLD_JS／BATTLE_JS 系統邊界的權威說明，TASKS/ 模組拆分依據 |

- **不要修改這些檔案**：它們是快照，不是工作檔。GDevelop 版若日後有異動且需要重新拉資料，
  重新複製並在此註記新快照日期。
- 舊文件（TASKS/、specs/、程式註解）中的 `../GDevelop/projects/crystal-quest/...` 或
  `../gd-crystal-tales/...` 路徑，一律對應本目錄的同名檔案。
