# alan 亞倫

- 底色: 螢光洋紅 `#FF00FF`
- ref: `godot-project/assets/ui/menuart_alan.png`
- seed ref: `assets-source/role/main/alan/battle_seed_alpha.png`（2026-07-27 已驗收；產 idle、hurt、cast、death、attack 的首幀與 strip 時必須實際附圖）
- weapon ref: `assets-source/role/main/alan/battle_weapon_alan_alpha.png`（單手劍外觀錨點；產 seed、動作首幀與 strip 時必須實際附圖）
- 武器規格: 右手主手；單手直劍總長約角色完整身高的 2/3，劍身約為劍柄的 4 倍。窄而略收尖的深灰雙刃劍身、中央血槽、舊金色微下彎十字護手、深棕皮革纏柄與圓形舊金色柄首。可整體縮放以使右手完整握住劍柄，但不得改變部件比例。
- 最後一版: 2026-07-30 `idle / calm_ready` 四幀 strip（基準 → 微抬 → 呼吸頂點 → 回落；左向、重心穩定、劍收於可立即出招的位置，已以腳底與角色中心錨點鎖定並整合為 runtime）；`hurt / recoil_guard` 首幀（候選 2；左向、右手劍身斜護胸前、左手護住腹側、雙腳仍接地）；`cast / forward_palm` 首幀（修正版；左手掌朝敵方前伸、視線跟隨手勢、右手低位持劍，無法術特效）；`death / kneel_collapse` 首幀（候選 2；單膝失力、上身前垂，單手劍自然掉落於右手側）；`attack / sword_horizontal_slash` 五幀 strip（John 選幀：準備 → 蓄力 → 右手持劍向左水平揮出 → 右後方收招 → 回復；為保留第 2 幀完整劍尖，以共用 68% 等比縮放放入 543×724 畫布，雙腳錨點與腳底 y=605 鎖定並整合為 runtime）。

```
青年劍士（26 歲），身形精悍、姿態隨性，深色短髮微亂、藍色眼睛、掛著吊兒郎當的笑、臉上一道小刀疤。深灰藍輕便旅裝／簡化輕甲，棕色破舊披風，深棕皮革護腕、皮腰帶與深色長靴。面向畫面左側，右手完整握住單手直劍，左手自然前伸保持平衡；低重心中性備戰姿勢，雙腳前後站立、腳底固定於基準線。這段只定義外觀與 seed，不取代任何動畫動作描述。
```
