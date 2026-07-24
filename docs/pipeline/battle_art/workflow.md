# 戰鬥立繪製作流程

## 目的

建立符合本專案美術規格的戰鬥立繪，
並確保所有素材皆能直接用於 Godot 專案。

---

# Step 1 建立需求與選擇動作

輸入：

- 魔物圖鑑
- 世界觀
- 角色設定

輸出：

- 本次需要產製的角色
- 動作與動作模板
- 特殊要求

先確認單位、面向與要產製的動畫。再依 `prompts/actions/` 的資料集，以對話方式讓 John 選擇
動作模板；不可只填入籠統的 `attack` 或 `cast`。

- `idle`：選擇重心與呼吸幅度。
- `hurt`：選擇受擊方向與防禦反應。
- `cast`：選擇施法媒介、施法手與法術發射方向。
- `death`：選擇倒下或潰散方式。
- `attack`：選擇招式、主手與武器運動方向。

資料集的動作 ID、必填選項與硬限制是 prompt 的權威來源；角色描述只補足該單位的外觀與裝備。

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

使用目前正式 preset：角色 `prompts/presets/battle_role_hd_pixel_v3.md`、敵人 `prompts/presets/battle_enemy_v2.md`。
- **先產 seed，再產動作首幀**。seed 是唯一角色外觀 reference，不屬於 idle 或任何動畫；持武器角色另以 weapon reference 鎖定武器外觀。seed 驗收通過後才依 `idle → hurt → cast → death → attack` 產製。
- 各動作首幀驗收通過後，再進入該動作的 strip 動畫製作。
- 組裝規則見 `prompts/role.md`（敵人 `prompts/enemy.md`）。
- 填入單位描述（各單位最後一版見 `prompts/descriptions/<id>.md`）。
- 加入所選 `prompts/actions/<action>.md` 模板的文字與選項；持武器角色必須帶入其武器規格與獨立 weapon reference。
- 要實驗新規則：只改 `prompts/sections/` 對應檔，成功後另存新 preset，再回來更新上面那一行。

---

# Step 4 AI 產圖

先產三張 **seed** 候選圖。seed 必須是非動作的中性備戰站姿，只用來鎖定角色外觀、服裝、配色、比例與基準面向；不得當作 idle 或任何動作的首幀。持武器角色產 seed 時，必須實際附上 weapon reference 與角色設定圖，讓武器外觀與手部持握在 seed 階段即固定。
seed 驗收通過後，才產指定動作的三張候選首幀。每次產動作都必須附上該單位已驗收的 `battle_seed_alpha.png` 作為 image reference；持武器角色還必須同時附上 `battle_weapon_<id>_alpha.png`。換對話也一樣，固定檔名或專案路徑本身不會使產圖工具自動讀圖。
若結果不符合規格：
回到 Step 3 修正 Prompt。

動畫 strip 產法：
以已核可、**不屬於任何動作幀**的 seed（中性備戰站姿、基準面向、定造型）為角色 reference；持武器角色另附已驗收 weapon reference 鎖定武器外觀，
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

通過 strip 預覽與逐幀驗收後，將正式輸出存放至素材源（與既有素材同一套位置）。產線檔名一律固定、不得附日期；同一單位重產時覆蓋對應檔案：

- 角色：`assets-source/role/main/<id>/`
- 敵人：`assets-source/role/enemies/<id>/`（`combat_0/1.png`，從 0 連號）

角色檔名：

| 用途 | 固定檔名 |
|---|---|
| Seed 候選 | `battle_seed_candidate_1_raw.png` 至 `candidate_3_raw.png` |
| 外觀錨點 | `battle_seed_raw.png`、`battle_seed_alpha.png` |
| 動作首幀候選 | `battle_<action>_candidate_1_raw.png` 至 `candidate_3_raw.png` |
| 核可的動作首幀 | `battle_<action>_raw.png`、`battle_<action>_alpha.png` |
| 動畫 strip | `battle_<action>_strip_raw.png`、`battle_<action>_strip_alpha.png` |
| 從 strip 拆出的來源逐幀圖 | `battle_<action>_0.png` 至 `battle_<action>_N.png` |
| 驗收 montage | `battle_<action>_review_montage.png` |

敵人沿用相同 `battle_*` 來源檔命名；正式 runtime 檔才依 Step 8 的 `hero_`／`foe_` 規則命名。若要保留舊版，必須由 John 明確指定另行封存，不能把日期帶入正式產線。

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
