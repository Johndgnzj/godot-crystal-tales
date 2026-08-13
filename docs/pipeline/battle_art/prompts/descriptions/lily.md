# lily 莉莉

- 底色: 螢光綠 `#00FF00`
- ref: `godot-project/assets/ui/menuart_lily.png`
- seed ref: `assets-source/role/main/lily/battle_seed_alpha.png`（2026-08-08 已驗收；產 `idle`／`hurt`／`cast`／`death`／`attack` 的首幀與 strip 時必須實際附圖）
- weapon ref: `assets-source/role/main/lily/battle_weapon_lily_alpha.png`（木質渦旋長法杖外觀錨點；2026-08-08 已驗收；產 seed、動作首幀與 strip 時必須實際附圖）
- 比例狀態: 約 3.5 頭身基準，可繼續使用；中性顯示高度依 162 cm 角色身高換算
- 武器規格: 右手主手；細長深褐色木質長法杖，總長接近角色完整身高。杖頭由上下兩股厚實木枝相向捲曲成未完全封閉的雙層圓形渦旋，中央嵌一顆小型淡紫水晶；只在杖頭與杖身接合處保留少量銀色箍環。可整體縮放以使右手完整握住杖身，但不得改變渦旋、水晶、杖身與銀箍的部件比例。
- idle: `calm_ready`；首幀 `assets-source/role/main/lily/battle_idle_alpha.png`；四幀 strip `assets-source/role/main/lily/battle_idle_strip_alpha.png` 與 `battle_idle_0..3.png`（2026-08-08 已驗收；法杖向敵方前移一步、左手五指完整、表情帶克制怒意；杖頭水晶依 `0° 中央 → 45° 上浮 → 90° 中央 → 135° 下沉` 循環；小腿與鞋部逐像素 root-lock）
- hurt: `stagger`；單幀 `assets-source/role/main/lily/battle_hurt_alpha.png`（2026-08-09 已驗收；受擊來自畫面左側，身體向右短暫失衡、雙腳保持接地，左手五指張開維持平衡，右手完整握杖，未加入受擊特效）
- cast: `weapon_channel` 雙手持杖吟唱；單幀 `assets-source/role/main/lily/battle_cast_alpha.png`（2026-08-09 已驗收；法杖直立於身側，雙手上下錯開完整環握杖身，閉眼低頭、嘴唇微啟凝神吟唱，未加入任何魔法特效）
- 最後一版: 2026-08-09 戰鬥 seed、weapon reference、`idle / calm_ready` 四幀 strip、`hurt / stagger` 單幀與 `cast / weapon_channel` 雙手持杖吟唱單幀；`death`、`attack` 尚未製作

```
莉莉，16 歲的纖細少女魔法師。黑色長直髮束成低馬尾，保留少量整齊瀏海與兩側髮束；紫色眼睛，神情高貴、沉著而略帶不安。身穿墨紫與深藏青色的兜帽旅行斗篷，兜帽放下；斗篷下是剪裁精緻、以大型色塊簡化的紫色連身裙，胸前保留一枚低調、小巧、做工精良的銀色王室工藝胸針。右手完整環握細長深褐色木質長法杖，法杖外觀嚴格依 weapon reference：杖頭由上下兩股厚實木枝相向捲曲成未完全封閉的雙層圓形渦旋，中央嵌一顆小型淡紫水晶，只在杖頭接合處保留少量銀色箍環。面向畫面左側，採低重心中性備戰站姿，雙腳前後自然站穩、腳底固定於基準線；法杖近乎垂直立於身側並完整留在畫布內，左手自然微抬。這段只定義外觀與 seed，不取代任何動畫動作描述。
```
