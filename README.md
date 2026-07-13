# 水晶戰記 — Godot 遷移準備區

這裡不是遊戲本體，是把 `../gd-crystal-tales`（GDevelop 版《水晶戰記 Crystal Tale》）換到 Godot 引擎前的
**規格與任務準備工作區**。現階段 GDevelop 版仍是唯一可玩版本，本目錄的產出是文件與（未來的）Godot 專案骨架。

## 這裡有什麼

| 目錄/檔案 | 內容 |
|---|---|
| `CLAUDE.md` | 轉換期規範：目錄結構、Godot 版本/技術選型、程式碼規範、多 subagent 協作總則 |
| `MIGRATION_OVERVIEW.md` | 可複用 vs 需重寫盤點總表（承接自 GDevelop 現況分析） |
| `TASKS/` | 拆到可執行程度的任務清單，分「核心 CORE-*」與「模組 MOD-*」兩層 |
| `specs/` | 從 GDevelop 原始碼（`build_cq2.py`）凍結抄錄出的權威規格：存檔 schema、戰鬥公式、對話系統資料格式 |
| `godot-project/` | Godot 專案骨架（目錄結構先建好，玩法程式碼待 CORE 任務展開後才動工） |

## 怎麼開始

1. 先讀 `CLAUDE.md`。
2. 看 `MIGRATION_OVERVIEW.md` 了解整體盤點結論。
3. 認領任務前讀 `TASKS/11_並行協作規則.md`，確認沒有跟其他進行中任務搶檔案。
4. 依 `TASKS/00_核心任務.md` 的順序，核心任務要先完成，模組任務（`01`~`09`）才能平行開工。

## 現況

- 遷移尚未開始寫玩法程式碼，目前是規格/任務準備階段。
- GDevelop 版本進度見 `../gd-crystal-tales/projects/crystal-quest/ROADMAP_開發計畫.md`（目前約完成到第二章）。
