# ludo 路德

- 底色: 螢光綠 `#00FF00`
- ref: `godot-project/assets/ui/menuart_ludo.png`
- seed ref: `assets-source/role/main/ludo/battle_seed_alpha.png`（2026-08-10 已驗收；165 cm、約 3.5 頭身、雙手持劍候選 3；後續所有動作必須實際附圖）
- weapon ref: `assets-source/role/main/ludo/battle_weapon_ludo_alpha.png`（劍的外觀錨點；產 seed、動作首幀與 strip 時必須實際附圖）
- 比例狀態: **G1／G2 已通過**；2026-08-10 驗收 165 cm、約 3.5 頭身的雙手持劍 Seed 候選 3，Alpha、等高比例與設定身高 lineup 均通過。
- 武器規格: 劍型沿用既有單手劍 weapon reference，但 Seed 與後續動作固定採雙手持握；右手靠護手、左手靠柄尾，雙手拇指與四指完整環握同一段握柄，雙腕與劍柄同軸且不得重疊。劍總長（劍尖至劍柄尾端）約為角色從頭頂到鞋底完整高度的 2/3，劍身約為劍柄的 4 倍，銀灰劍身、中央血槽、暖金色護手與菱形劍首、深棕劍柄。可整體縮放以使雙手正確握住，但不得改變部件比例或增加第二個柄尾／裝飾。
- idle: `ready_guard`；G3 首幀 `assets-source/role/main/ludo/battle_idle_raw.png`（2026-08-11 已驗收候選 A；低重心防守、右手靠護手與左手靠柄尾，雙手完整持握同一劍柄）。前兩次完整 strip 因首幀漂移、安全留白不足與跨幀比例變化退回；2026-08-12 改採 John 核可的分段 key pose fallback，Frame 2 選候選 A、Frame 1 使用固定端點 motion-compensated midpoint，正式循環 `0 → 1 → 2 → 1`。G4～G6 已驗收，G7 以共用 0.5× Nearest 正規化為 543×724、角色可見中心約 `x=268`、可見框下界 `y=659`，整合至 `hero_ludo_idle_0..3.png`；舊 runtime 四幀封存於 `unofficial/idle/runtime_before_3_5_head/`。
- hurt: `recoil_guard`；受擊來自畫面左側，上身向右短促後仰、雙腳保持接地，右手靠護手與左手靠柄尾持續雙手握住同一把劍，劍身斜護胸前。G3 採候選 A 的劍身拉直修正版，保存為 `assets-source/role/main/ludo/battle_hurt_raw.png`；G5 去背版為 `battle_hurt_alpha.png`。2026-08-13 完成 G7，以 0.5× Nearest 正規化至 543×724、可見中心 `x=267`、腳底最後可見像素 `y=658`，整合至 `hero_ludo_hurt.png`；舊 runtime 封存於 `unofficial/hurt/runtime_before_3_5_head/`。依 John 指示，本次只整合素材與文件，Godot import／測試暫緩。
- cast: `two_hand_focus`；本動作依 John 指定作為雙手持劍常規的例外：完整左側身、閉眼集中，雙手離開武器向畫面左側伸直，十指呈發射姿勢但不含任何魔法特效；長劍完整收入右腰劍鞘，鞘尖延伸至小腿肚。G3／G5 已驗收，來源保存為 `assets-source/role/main/ludo/battle_cast_{raw,alpha}.png`。2026-08-13 完成 G7，以 0.5× Nearest 正規化至 543×724、可見中心 `x=267`、腳底最後可見像素 `y=658`，新增 `hero_ludo_cast.png`；此前 runtime 無同名 Cast，舊二頭身來源僅留在 `unofficial/battle/legacy_2026_07/source_bundle/`。Cast 尚未接入戰鬥程式；Godot import／測試依 John 指示延後至路德剩餘動作整合後一併執行。
- death: `fall_forward`；戰敗後五體投地趴伏，臉朝下、胸腹貼地、雙臂無力攤在前方、雙腿向後伸展，披風覆背鋪地；長劍完整掉落在手邊。G3／G5 已驗收，來源保存為 `assets-source/role/main/ludo/battle_death_{raw,alpha}.png`。2026-08-13 完成 G7，以 0.5× Nearest 保持同角色尺度，置入 543×724 Runtime 並將橫向趴地剪影中心對齊 `x=268`、最低可見像素對齊共同地面線 `y=658`，整合至 `hero_ludo_death.png`；舊 runtime 封存於 `unofficial/death/runtime_before_3_5_head/`。Godot import／測試依 John 指示延後至 Attack 整合後一併執行。
- 最後一版: 2026-08-13 雙手持劍 Seed、`idle / ready_guard` 四幀循環、`hurt / recoil_guard`、`cast / two_hand_focus` 與 `death / fall_forward` 均已完成分階段驗收並整合 runtime；僅 attack 尚待依新 3.5 頭身規格重製。2026-07-22 的 idle／hurt／cast／death 與 2026-07-27 attack 皆為舊二頭身技術紀錄，只保留作為動作方向、切幀與 root-lock 錯誤排查參考，不屬於新規格已驗收素材。

```
15 歲少年，蓬鬆棕髮、金褐色眼睛、開朗有活力；身穿白襯衫，外罩棕色皮甲，搭配簡化皮帶扣，披一件紅色披風，帶金色紋飾滾邊；前臂戴簡化刻花皮革護腕，繫皮腰帶，穿長靴。雙手持握一把簡潔長劍：右手靠護手、左手靠柄尾，兩手依序環握同一段深棕握柄，劍身由身前斜指畫面左上。臉和視線朝向畫面左側，低重心中性備戰站姿，雙腳前後站立，披風微微揚起；腳底固定於基準線，角色輪廓清楚。這段只定義外觀與 seed，不取代任何動畫動作描述。
```
