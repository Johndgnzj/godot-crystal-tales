# 戰鬥立繪製作流程

## 目的

建立符合本專案美術規格的戰鬥立繪，
並確保所有素材皆能直接用於 Godot 專案。

---

# Step 1 建立需求

輸入：

- 魔物圖鑑
- 世界觀
- 角色設定

輸出：

- 本次需要產製的角色
- 動作
- 特殊要求

---

# Step 2 確認美術規格

閱讀：`docs/design/戰鬥立繪規格.md`

確認：

- 比例
- Pixel Style
- 配色
- 光源
- Outline
- 鍵色
- 畫面比例

---

# Step 3 建立 Prompt

使用目前正式 preset：角色 `prompts/presets/battle_role_hd_pixel_v2.md`、敵人 `prompts/presets/battle_enemy_v2.md`。
- 首幀產製順序：idle → hurt → cast → death → attack，各動作首幀驗收通過後，再進入 strip 動畫製作
- 組裝規則見 `prompts/role.md`（敵人 `prompts/enemy.md`）。
- 填入單位描述（各單位最後一版見 `prompts/descriptions/<id>.md`）。
- 要實驗新規則：只改 `prompts/sections/` 對應檔，成功後另存新 preset，再回來更新上面那一行。

---

# Step 4 AI 產圖

產生三張候選圖。
若結果不符合規格：
回到 Step 3 修正 Prompt。

動畫 strip 產法：
先核可 1 張 seed frame（中性站姿、基準面向、定造型）當唯一 reference，
再一次產完整條 strip。
禁止逐幀硬湊。
strip 必須在每格之間保留固定空白間距，並在整張圖四周保留安全留邊；角色、武器與特效不可貼邊或跨格。

---

# Step 5 驗收

## 5.1 產生 strip 預覽包

多幀 strip 產出後，先使用 `tools/frame_aligner/` 產生預覽包，不直接匯入 Godot。
預覽包必須同時保留：

- 原始 strip：檢查幀距、外圍留邊、是否有角色或特效跨格
- 逐幀 PNG：每幀獨立顯示，檢查是否混入前一幀或下一幀內容
- Review montage：所有逐幀 PNG 橫向排列並標示幀號，檢查動作連續性與 anchor

目前 `frame_aligner` 已支援切圖與逐幀輸出；Review montage 自動產生仍是工具補強項。
在工具完成前，montage 可由既有影像處理流程產生，但不得把外部工具當成固定人工依賴。

切圖不可只依賴等寬硬切。若角色、武器或特效跨越預定分界，應依實際輪廓重新判定幀範圍，並將每幀放回統一尺寸畫布；無法判定時標記為需要人工確認，不可默默交付。

## 5.2 人工逐幀驗收

Review 時必須同時查看原始 strip 與逐幀 PNG／montage，依 `checklist.md` 的「動畫 Strip」逐項確認。
驗收重點是：每幀內容完整、沒有前後幀像素、幀距與外圍留邊足夠、腳底基準線一致。

若未通過：回到 Step 3 重修 Prompt，或回到本步驟重新切幀；未通過前不得進入 Godot 整合。

---

# Step 6 素材整理

通過 strip 預覽與逐幀驗收後，將正式輸出存放至素材源（與既有素材同一套位置）：

- 角色：`assets-source/role/main/<id>/`
- 敵人：`assets-source/role/enemies/<id>/`（`combat_0/1.png`，從 0 連號）

依素材管理規範命名。

---

# Step 7 後續加工

依需求：

- 去背
- 對齊
- 切圖
- Resize
- 建立 Animation

正規化：最終為透明 RGBA、邊緣乾淨；
每格經同一套縮放、裁切與 **bottom-center（腳底置中）錨點**。
幀對齊輔助工具：`tools/frame_aligner/`；其輸出的逐幀 PNG 與 Review montage
只能作為驗收及素材整理依據，不能取代原始 strip 的保留。

---

# Step 8 匯入 Godot

放入： `godot-project/assets/battle/`，命名：

| 動畫 | 我方（`hero_`）| 敵方（`foe_`）|
|---|---|---|
| idle | `hero_<id>_idle_0..3.png` | `foe_<id>_0..N.png` |
| attack | `hero_<id>_attack_0..N.png` | `foe_<id>_attack_0..N.png` |
| hurt/death/cast | `hero_<id>_{hurt,death,cast}.png` | `foe_<id>_{hurt,death,cast}.png` |

- 敵人幀從 0 連號（載入器掃連號循環，不留舊 `_2/_3`）。
- 像素圖 `.import` 用 **Nearest**。
- 程式引用：`battle_state_machine.gd`（`HERO_SLOTS` 已有站位）；戰鬥動畫載入待接。
- 更新 `CREDITS_素材授權.md`；`godot --headless --check-only` 過。

建立 Resource。
完成。

---
