# 戰鬥立繪製作流程

## 目的

建立符合本專案美術規格的戰鬥立繪，
並確保所有素材皆能直接用於 Godot 專案。

## 不可跳過的驗收 Gate

| Gate | 交付物 | 通過後才能做 |
|---|---|---|
| G0 Reference 鎖定 | Menu Art／角色設定、weapon reference、頭身與面向 | 產 Seed 候選 |
| G1 Seed 靜態驗收 | 滿版鍵色 `battle_seed_candidate_*_raw.png` | 正式去背 Seed |
| G2 Seed Alpha 驗收 | `battle_seed_alpha.png`，邊緣、手腳、武器完整 | 產任一動作首幀 |
| G3 動作首幀驗收 | 滿版鍵色 `battle_<action>_raw.png` | 產該動作 strip |
| G4 Strip 靜態驗收 | 鍵色原始 strip／逐幀 PNG／幀號 montage | 正式去背 strip |
| G5 Alpha 靜態驗收 | 透明 strip 與透明逐幀 PNG | 合成驗收 GIF |
| G6 GIF 動態驗收 | 透明循環 GIF，檢查 root-lock、武器與首尾幀 | 列為可整合候選 |
| G7 正式整合核可 | John 明確回覆「可以」或等價語句 | 覆寫 runtime 素材、更新 CREDITS、import 與測試 |

任一 Gate 未通過就停在該階段修正。GIF 不得取代靜態幀驗收；多幀素材不得在 G4 之前去背，單幀素材不得在 G3 之前去背。在 G7 之前，所有候選只存於預覽位置，不得寫入 `assets-source/`、`godot-project/assets/`、CREDITS 或 import 流程。

上表的 G4 與 G6 專用於多幀動畫（`idle`、`attack`）。單幀動作（`hurt`、`cast`、`death`）的路徑為 `G3 鍵色靜態 → G5 Alpha 靜態 → G7 整合核可`，不為單幀強行製作 strip 或 GIF。所有路徑仍必須先驗收鍵色靜態圖，再去背。

## 交付格式合約

| 交付物 | 格式 | 硬性規則 |
|---|---|---|
| Key-color Raw | PNG，不透明 | 背景滿版單一純鍵色；同一動作所有幀同色，無漸層、spill、投影、邊框或 UI |
| Raw Strip | PNG，不透明 | 單列、等格、左至右；每格輪廓前後至少 85px 鍵色留白，相鄰輪廓至少 170px 純鍵色空間 |
| Alpha Strip／Frames | PNG RGBA | 完整 Alpha channel；畫布、縮放、bottom-center 錨點與腳底線一致；無鍵色 spill 或誤刪像素 |
| Review Montage | PNG | 可在圖片外的驗收區標幀號；不得把幀號、格線或 UI 畫進任一來源幀 |
| Review GIF | 無限循環 GIF | 使用與 runtime 一致的幀順序，預設每幀 `0.18s`；只用於動態驗收，不是 runtime 真相源 |

來源檔名一律使用下方 Step 6 的固定命名，不帶日期。正式 runtime 一幀一張 PNG，不直接讀 strip 或 GIF。

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

- 我方角色約 3.5 頭身（可接受 3.3～3.7）；敵人依物種解剖比例
- Pixel Style
- 配色
- 光源
- Outline
- 鍵色
- 畫面比例

---

# Step 3 建立 Prompt

使用目前正式 preset：角色 `prompts/presets/battle_role_hd_pixel_v5.md`、敵人 `prompts/presets/battle_enemy_v2.md`。
- **先產 seed，再產動作首幀**。seed 是唯一角色外觀 reference，不屬於 idle 或任何動畫；持武器角色另以 weapon reference 鎖定武器外觀。seed 驗收通過後才依 `idle → hurt → cast → death → attack` 產製。
- 各動作首幀驗收通過後，再進入該動作的 strip 動畫製作。
- 組裝規則見 `prompts/role.md`（敵人 `prompts/enemy.md`）。
- 填入單位描述（各單位最後一版見 `prompts/descriptions/<id>.md`）。
- 加入所選 `prompts/actions/<action>.md` 模板的文字與選項；持武器角色必須帶入其武器規格與獨立 weapon reference。
- 要實驗新規則：只改 `prompts/sections/` 對應檔，成功後另存新 preset，再回來更新上面那一行。

---

# Step 4 AI 產圖

先產三張滿版單一鍵色的 **seed** 候選圖。seed 必須是非動作的中性備戰站姿，只用來鎖定角色外觀、服裝、配色、3.5 頭身比例與基準面向；不得當作 idle 或任何動作的首幀。持武器角色產 seed 時，必須實際附上 weapon reference 與角色設定圖，讓武器外觀與手部持握在 seed 階段即固定。G1 驗收後才去背製作 `battle_seed_alpha.png`，G2 再驗收透明邊緣與完整性。
seed 驗收通過後，才產指定動作的三張候選首幀。每次產動作都必須附上該單位已驗收的 `battle_seed_alpha.png` 作為 image reference；持武器角色還必須同時附上 `battle_weapon_<id>_alpha.png`。換對話也一樣，固定檔名或專案路徑本身不會使產圖工具自動讀圖。
若結果不符合規格：
回到 Step 3 修正 Prompt。

動畫 strip 產法：
以已核可、**不屬於任何動作幀**的 seed（中性備戰站姿、基準面向、定造型）為角色 reference；持武器角色另附已驗收 weapon reference 鎖定武器外觀，
再於**同一次生成**完成整條 horizontal strip；不得將各幀分開產圖後拼接。整條 strip 後製時只使用一個 global scale、共同畫布與 bottom-center 腳點，禁止逐幀 fit-to-cell；若首幀已經核可，正規化時必須保持它的實際人物尺寸與腳點。
各幀必須是符合動作相位的真實局部重繪；禁止把同一張圖逐幀平移、縮放或用大塊腳部矩形硬湊成動畫。
對所有多幀素材（`idle`、`attack`、`walk` 等），每一格的角色、武器與特效輪廓前後都必須保留**至少 85px 的單色鍵色安全留白**；相鄰兩格之間因此至少有 170px 的乾淨鍵色區域。此數值以產圖原始解析度計算，不得靠後續縮放補足。整張 strip 四周也必須留白；角色、武器與特效不可貼邊或跨格。

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

## 5.2 人工逐幀驗收（先看靜態圖）

先把原始 strip、逐幀 PNG 與 Review montage 提供給 John 驗收；此時**不得先以 GIF 取代靜態逐幀檢查**。驗收重點是：每幀內容完整、每格角色前後各有至少 85px 鍵色安全留白、沒有前後幀像素、腳底基準線一致。

John 確認靜態圖後，才進入下一節處理去背與對齊。

## 5.3 去背、鎖錨點與 GIF 動態驗收

1. 以鍵色去背輸出透明 RGBA 逐幀圖。
2. 以每幀腳底的 bottom-center 為共同錨點，放進同尺寸畫布；不得以角色 bbox 或劍尖作為錨點。播放時人物不得左右或上下漂移。
3. 再次逐幀檢查透明畫布：主體外不得殘留前一幀／下一幀的角色、武器或特效像素。
4. 以上三項都通過後，才輸出循環 GIF 給 John 驗證動作連續性與 root-lock。GIF 只用於驗證，不取代原始 strip 與透明逐幀 PNG。

若未通過：回到 Step 3 重修 Prompt，或回到本步驟重新切幀；未通過前不得進入 Godot 整合。

---

# Step 6 預覽素材整理

通過 strip 預覽與逐幀驗收後，先在 preview／visualization 位置按下列固定檔名整理候選；G7 正式整合核可後，才將同一組核可輸出存入素材源。正式檔名不得附日期；同一單位重產時覆蓋對應檔案：

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
- 程式引用：`battle_state_machine.gd`（`HERO_SLOTS` 已有站位）。**idle／attack 已接（2026-07-27 作法B）**：`_load_frames` 讀 `hero_<id>_idle_0..3`、`_load_anim_frames` 讀單一 `hero_<id>_attack_0..N`（所有普攻/技能共用此 attack 動畫，不再分 slash/thrust/spellcast）。**hurt／death 已接（2026-07-27）**：受傷時換 `hero_<id>_hurt.png`＋震動、HP 歸零換 `hero_<id>_death.png`（見 `battle_state_machine.gd` 我方 sprite 貼圖優先序）。**cast 暫不接**（尚無元素魔法技能）。
- 更新 `CREDITS_素材授權.md`；`godot --headless --check-only` 過。

建立 Resource。
完成。

---
