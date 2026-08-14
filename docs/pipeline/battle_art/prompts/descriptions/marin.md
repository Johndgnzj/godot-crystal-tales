# marin 瑪琳

- 底色: 螢光洋紅 `#FF00FF`
- ref: `godot-project/assets/ui/menuart_marin.png`
- seed ref: `assets-source/role/main/marin/battle_seed_alpha.png`（2026-08-11 已驗收的 3.5 頭身、左手持短刀候選 3；產所有新動作時必須實際附圖）
- weapon ref: `assets-source/role/main/marin/battle_weapon_marin_alpha.png`（短刀外觀錨點；產 seed、動作首幀與 strip 時必須實際附圖）
- 比例狀態: **Seed 已驗收**；158 cm、約 3.5 頭身，已通過 G1／G2 與五人等主體高度／設定身高 lineup。idle／attack 已完成 G7；hurt／cast／death 已通過 G5、待 G7
- idle: `calm_ready`；G3 首幀 `assets-source/role/main/marin/battle_idle_raw.png`（2026-08-11 已驗收候選 3；低重心沉穩備戰、左手短刀低位朝畫面左側、右手靠近腰帶、雙腳完整接地）；第一批 G4～G6 因邊緣污染與相位方向退回，重做改用青色鍵色與 `0 → 1 → 2 → 1` 分段 key pose。Frame 2 與固定端點插值 Frame 1 已驗收，最終採 John 手動去背的三張 `*_finetune.png`；G6 通過，G7 已整合 `battle_idle_0..3.png` 與 runtime `hero_marin_idle_0..3.png`（543×724、腳底 `y=628`）
- hurt: `recoil_guard`；2026-08-13 G3 採候選 1：攻擊由畫面左側命中，上身向右微後仰，右前臂護住胸口，左手短刀橫向護於腰腹前，雙腳完整接地且仍維持戰鬥狀態。正式鍵色來源為 `battle_hurt_raw.png`；G5 `battle_hurt_alpha.png` 已通過驗收，髮梢紫紅 spill 已在不改變 Alpha 輪廓的前提下修正。
- cast: `offhand_rear_cast`；2026-08-13 G3 採背面候選 1 的刀身軸線修正版：三分之二背面、披肩朝鏡頭，頭部越過左肩望向畫面左側，戴護具的右手向敵方伸出施法，左手在後腰側持短刀；不含魔法特效。正式鍵色來源為 `battle_cast_raw.png`；G5 `battle_cast_alpha.png` 已通過驗收，採二值 Alpha 並只重著色 195 個明顯洋紅污染像素，未改變人物、武器輪廓或深色外框。
- death: `fall_forward`；2026-08-13 G3 採側趴倒地候選 1：頭、肩、軀幹、髖部與雙腿均落於同一地面，雙臂未支撐上身，左手短刀完整掉落於原持手附近。正式鍵色來源為 `battle_death_raw.png`；G5 `battle_death_alpha.png` 已通過驗收，採二值 Alpha，只移除背景及修正輪廓鍵色污染，人物、衣服、飾品與短刀皆保持完全不透明。
- attack: `dagger_thrust`；2026-08-13 五幀依序為起手 → 下沉 → 深度蓄力 → 向畫面左側突刺 → 收招。G4 修正第 0／1／3／4 幀非持刀手為拇指＋四指，G5 以二值 Alpha 清除洋紅背景、孔洞與外緣污染，G6 動態預覽通過。G7 五幀共用 543×724 cell，以畫面右側左腳鞋底最下方三列的接地中心鎖定 `(390,628)`；不縮放、不重新取樣，突刺刀尖保留安全邊距。正式來源為 `battle_attack_0..4.png`、`battle_attack_strip_{raw,alpha}.png`、`battle_attack_review_montage.png`、`battle_attack_review.gif`，runtime 為 `hero_marin_attack_0..4.png`。
- 武器規格: 左手主手；短刀總長約角色完整身高的 1/3，刀身約為刀柄四倍長；銀灰寬刀身、長形深色血槽、金色護手、深棕纏繩刀柄與金色柄尾。可整體縮放以使左手完整握住刀柄，但不得改變部件比例。
- 最後一版: 2026-08-13 的 3.5 頭身 Seed、`idle / calm_ready`、`hurt / recoil_guard`、`cast / offhand_rear_cast`、`death / fall_forward` 與 `attack / dagger_thrust` 均已驗收；Idle／Attack 已完成 G7，hurt／cast／death 已通過 G5、待統一進入 G7。Idle 正式來源為 John 手動去背的三張 `finetune`，四幀循環 `0 → 1 → 2 → 1`、每幀 0.18 秒、543×724、腳底 `y=628`；Attack 為五幀、543×724、左腳鞋底錨點 `(390,628)`。正式 PNG 採二值 Alpha，GIF 同為二值透明。舊二頭身素材僅保留作為動作方向與錯誤排查參考。

```
14 歲少女，紅褐色高馬尾＋齊瀏海、綠色眼睛、溫和冷靜的表情；白色襯衫洋裝外罩藍色繡白花短披肩（雙金釦），腰間棕色皮束帶（心形釦扣），右手戴棕色皮護具，下身裙裝配棕色皮靴；身手靈巧、冷靜務實的氣質。`attack / dagger_thrust` 為左手主手的五幀序列：預備 → 回復預備 → 低重心蓄力（身體下沉、後移，左肘約 90°、短刀刀尖朝上）→ 背身軀幹的左手向畫面左側突刺 → 收刀回轉。臉與綠色眼睛全程維持朝畫面左側；軀幹背身時僅轉披風與身體，頭部不轉向。雙腳維持 bottom-center root-lock。短刀外觀嚴格依 weapon reference：銀灰寬刀身、長形深色血槽、金色護手、深棕纏繩刀柄與金色柄尾；不得改變部件相對比例；左手拇指與四指完整環握刀柄，手腕與刀柄同軸。
```
