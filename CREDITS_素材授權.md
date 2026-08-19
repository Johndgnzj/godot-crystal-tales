> **[Godot 遷移副本說明]** 本檔案於 **2026-07-14** 隨 `godot-project/assets/` 的資產一併從
> `gd-crystal-tales/projects/crystal-quest/CREDITS_素材授權.md` 複製而來（MOD-I 任務）。
> 自複製日起，GDevelop 版與 Godot 版的資產各自演進時，兩邊的授權文件需**分別維護**——
> Godot 端動任何素材，改的是本檔案；GDevelop 端的更新不會自動同步過來。
> 文中提及的 `tools/`、`design/`、`art_v*.py`、`build_cq2.py` 等路徑為 GDevelop 端工作區路徑，
> 生成腳本依 TASKS/09 決議留在 GDevelop 端，Godot 專案只消費產出的 PNG/音檔。

# 素材授權標註（水晶傳說）

## 角色
LPC 角色產生器圖層合成（CC-BY-SA/GPL），圖層配方參考 overworld-demo/CREDITS_素材授權.md；戰鬥怪物與道具為 GDevelop 商店 CC0（16x16 dungeon tileset、grafxkid、western fps 2d 等包）。

- `assets/char/ludo_{Up,Left,Down,Right}_0..8.png`（2026-07-28 終版基準簡易版）：路德 64px overworld walk，由 OpenAI 內建 imagegen 依芳蕾鎮中央實機地圖 style seed 生成，經 John 逐方向驗收四向 `Idle / Step L / Step R`。所有幀完成 bottom-center、色調、手勢、解剖腳位與逐 pixel 去背殘色檢查；runtime 的 1..8 依 `L/R` 交替填入。來源 raw／alpha／64px frame 保留於 `assets-source/role/main/ludo/overworld_final/`。Right 步態由核可 Left 成對鏡射後鎖回獨立 Right Idle 並校色；提示詞作者 John／協作 Agent。此為簡易驗證版，後續仍會擴充正式 8 相位。
- `assets/char/alan_{Up,Left,Down,Right}_0..8.png`（2026-07-28 終版基準簡易版）：亞倫 64px overworld walk，由 OpenAI 內建 imagegen 沿用路德終版基準、亞倫正式立繪與芳蕾鎮實機地圖色盤生成。John 核可 `Down Idle` world style seed 後，再逐方向驗收四向 `Idle / Step L / Step R`；所有幀通過 bottom-center、方向、解剖腳位交換、材質色票與逐 pixel 去背殘色檢查。runtime `0=Idle`，1..8 依 `L/R` 交替填入，走路期間不插入 Idle；來源 raw／alpha／64px frame 與 review 保存於 `assets-source/role/main/alan/overworld_final/`。提示詞作者 John／協作 Agent。此為簡易驗證版，後續仍會擴充正式 8 相位。
- `assets/char/marin_{Up,Left,Down,Right}_0..8.png`（2026-07-27）：瑪琳二頭身 overworld walk 簡易驗證版。OpenAI 內建 imagegen 依已驗收瑪琳立繪與戰鬥 seed 參考生成；John 驗收 v2 後以洋紅鍵去背、切圖與腳底錨點正規化。來源保留於 `assets-source/role/main/marin/overworld_walk_simple_v2_{raw,alpha}.png`；每方向兩張步態皆為左右腳明確交替，再交替填入既有 8 格 runtime 動畫。提示詞作者 John／協作 Agent。
- 五主角 overworld 5-frame 舊產線高解析 seed（2026-08-13）：`assets-source/role/main/{ludo,marin,lily,jess,alan}/overworld_5frame/seed_down_{raw,alpha}.png`，路德、瑪琳、莉莉、潔絲、亞倫的 `Down Idle` 高解析 seed（1254×1254）。由 OpenAI 內建 imagegen 依各角色正式立繪生成；路德與莉莉採螢光綠鍵、瑪琳／潔絲／亞倫採螢光洋紅鍵去背。提示詞作者 John／協作 Agent。**未整合 runtime；依 2026-08-14 v3.0 規格，它們不是 1280 D1、D2 或 D3，只保留為歷史產線中素材。**
- 五主角舊 `native64` layout diagnostic（2026-08-14）：同目錄 `seed_down_native64_ref{,_preview}.png`，由上列高解析 seed 以 `tools/art/make_native64_ref.py` 自動縮圖產生（premultiply alpha ＋ `LANCZOS` ＋ `UnsharpMask 40`），五人曾共用 `--group-height 824`。未新增生成內容，授權同來源 seed；**v3.0 已停用此步驟，這些圖不是 Pixel Art Reference、Native Seed 或 strip source。**
- 路德／羅瑟爾 overworld 終版 style seed（2026-07-28）：OpenAI 內建 imagegen 依芳蕾鎮中央實機地圖風格生成，經螢光綠鍵去背、bottom-center 正規化並合成回場景驗收。John 核可兩者的角色比例、色調、光向與獨立接地陰影方向；raw／alpha／64px `Down Idle` seed 分別保存於 `assets-source/role/main/ludo/overworld_final/` 與 `assets-source/role/npc/rossel/overworld_final/`。路德四方向 `Idle / Step L / Step R` 已全部核可並整合為 runtime 簡易版；來源與 64px frame 同存於其 `overworld_final/`。提示詞作者 John／協作 Agent。
- 瑪琳 overworld 終版 style seed（2026-07-28）：OpenAI 內建 imagegen 沿用路德 64px 終版基準與芳蕾鎮中央實機地圖色盤生成；John 已核可螢光綠幕 `Down Idle`、四方向 Idle，以及 `Up`／`Left`／`Down` 的 `Step L / Step R`。`Up` 保留指定候選的色調與腿部步幅並補上反向手擺；`Left` 明確交換近／遠腿層級、亮暗及白袖／護具手擺動；`Down` 依正面解剖鎖定 `Step L＝畫面右腳向前`、`Step R＝畫面左腳向前` 並同步反向手擺。raw／alpha／bottom-center 正規化 64px source 保存於 `assets-source/role/main/marin/overworld_final/`，並通過方向、比例、逐 pixel 螢光鍵色與透明區 RGB residue 檢查。`Right` 尚待驗收。提示詞作者 John／協作 Agent。
- `assets/char/{mira,warden}_Down_0.png`（2026-08-13）：米拉與芳蕾鎮守衛的原生 64px overworld `Down Idle`。由 OpenAI 內建 imagegen 依兩人的核准立繪、路德終版世界 sprite 基準與芳蕾鎮實機地圖色盤生成，經 John 驗收縮小可讀性、人物一致性、去背與獨立接地影子後整合。raw／alpha／64px final 保存於 `assets-source/role/npc/<id>/overworld_final/`；影子由遊戲程式獨立生成，未烘進 PNG。提示詞作者 John／協作 Agent。其餘方向與 walk 尚待產出。
- `assets/char/{rossel,hank,martha}_Down_0..8.png`（2026-08-13）：羅瑟爾、漢克與瑪莎的原生 64px overworld Down 簡易版。由 OpenAI 內建 imagegen 依各角色核准立繪、羅瑟爾既有世界 style seed、芳蕾鎮實機地圖及首批 NPC 基準，一次生成每人的 `Idle / Step L / Step R` strip；經 John 驗收人物一致性、縮小可讀性、解剖左右腳交換、bottom-center、去背與獨立接地影子後整合。runtime `0=Idle`，`1..8` 依 `L/R` 交替；raw／alpha／64px 三幀及替換前素材保存於 `assets-source/role/npc/<id>/overworld_final/`。提示詞作者 John／協作 Agent；其餘方向尚待產出。

- ⚠️ **野狼（wolf）為佔位圖**：GDevelop 商店與 LPC 皆無四足野狼素材，`assets/battle/Wolf_Idle.png` 由 grafxkid 洞熊單幀（`Bear_Idle.png`，CC0）於 build 時去飽和＋冷灰調重生（衍生自 CC0，故無授權限制）。外形仍是熊剪影、僅以冷灰色與棕熊區隔——**待日後補上正式四足狼精靈再替換**（gen-art 不適用像素小圖）。

## 地形圖磚（LPC Terrain）
- 來源：OpenGameArt「LPC Tile Atlas」（terrain_atlas.png），已存於 `tools/lpc-terrain/`
- 作者群：Lanea Zimmerman (Sharm)、Daniel Armstrong (HughSpectrum)、Casper Nilsson 等 LPC 貢獻者
  （完整名單見 https://opengameart.org/content/lpc-tile-atlas ）
- 授權：CC-BY-SA 3.0 / GPL 3.0 雙授權——發佈時需標註作者，衍生美術需以相同授權分享
- 使用範圍：草地（含變體/花）、土路九宮格過渡與內角、素土、石板廣場、長草、大樹（橡樹/松樹）

## 森林地面與植被（anokolisa「Pixel Crawler - Free Pack」，2026-07-13 新增）
- 來源：itch.io 作者 **Anokolisa**「Pixel Crawler - Free Pack」（免費版），已存於 `tools/anokolisa/`
  （https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites ）
- 授權：見 `tools/anokolisa/LICENSE_Terms.txt`——可自由用於商業/非商業/學習專案、可任意改色改形；
  **署名非必要（但作者感謝）；唯一限制：不得將素材本身當「最終產品」販售**（只有原作者能販售素材）。
  crystal-quest 為把素材功能性用於遊戲、未販售素材，故可納入本（公開）repo。
- 使用範圍（**檔名前綴 `fst_` 一律為本包衍生**，與自製家具 `f_*` 區隔）：
  - `assets/map/atlas_forest.png`：森林專屬地面圖集（草/長草/花草/樹牆/土路），Forest/Forest2 場景 Map 專用；其他地圖仍用 LPC `atlas.png`。
  - `assets/props/fst_tree_1..6.png`：6 種樹（針葉/闊葉，統一 96×120 底對齊）。
  - `assets/props/fst_deco_{bush,fern,mush,flower,pebble}.png`：森林地面非阻擋裝飾。
  - 以上由 `scripts/art_v14_forest.py` 從 `tools/anokolisa/` 重生（部分經裁切/縮放/微合成，屬允許的改作）。

- `assets/props/world/nature/1x1/ground_decor_grass_pebble_{a,b,c}.png`（2026-07-29）：
  芳蕾鎮草地風格的 1×1 非碰撞草石地面點綴。OpenAI 內建 imagegen 依 John 提供的地圖風格圖生成，
  經 John 驗收後以色鍵去背並最近鄰正規化為 32×32；raw、alpha 與 final 保存於
  `assets-source/props/world/nature/1x1/ground_decor_grass_pebble_{a,b,c}/`。提示詞作者 John／協作 Agent。

## 建築與洞窟（LPC Tile Atlas 1/2，2026-07-11 新增）
- 來源：OpenGameArt「LPC Tile Atlas」（base_out_atlas.png，`tools/lpc-atlas1/`）與
  「LPC Tile Atlas2」（build_atlas.png，`tools/lpc-atlas2/`），彙整者 adrix89
- 作者群：LPC 參賽者（Lanea Zimmerman、Casper Nilsson、Barbara Rivera 等，
  完整名單見各 zip 內 Attribution.txt / Attribution2.txt）
- 授權：CC-BY-SA 3.0 / GPL 3.0 雙授權
- 使用範圍：鎮上六棟建築（公會/旅店/鎮長宅/道具店/鐵匠鋪/小神殿 由組件拼裝）、
  礦坑口、洞窟磚（岩壁/沙岩頂）、石筍、灌木、招牌、火炬、鍛爐、大門等

## 音效（Pixabay，2026-07-11 新增）
- 授權：Pixabay Content License（可免費商用、毋須標註；仍列出以示感謝）
- learn.mp3 — "Level Up, Skill Upgrade 4" by yodguard（…/film-special-effects-level-up-skill-upgrade-4-387909/，剪輯至 2.2s）
- menu.mp3 — "UI Open SFX" by litupsubway（…/technology-ui-open-sfx-513358/）
- cursor.mp3 — "Button Click" by freesoundeffects（…/film-special-effects-button-click-289742/）（鍵盤選單變換項目；2026-07-16 換入，原為 "UI Hologram Interface Blip" by soundshelfstudio）
- select.mp3 — "Click 2" by freesound_gamestudio（…/film-special-effects-click-2-384920/）（點選/確認；2026-07-16 換入，原為 Python 生成之 8-bit select.wav）
- return.mp3 — 返回/取消音效；Pixabay Music（Pixabay Content License，可商用毋須標註）。2026-07-16 換入取代 cancel.mp3（原為 "UI Swipe Cancel" by soundshelfstudio）。曲名/作者待補。
- 其餘 .wav 為 Python 生成之 8-bit 音效（自製，無授權限制）：atk / hurt / heal / win / lose / magic（select 已於 2026-07-16 改用 Pixabay，見上）
- **戰鬥攻擊音效（2026-07-18 新增，John 提供 mp3）**：`att_sword.mp3`(劍普攻)、`att_blade.mp3`(短劍/爪普攻)、`att_staff.mp3`(法杖普攻)、`att_sword_skill.mp3`(物理技能)、`att_magic.mp3`(魔法技能)、`att_miss.mp3`(閃避/揮空)、`att_monster_punch.mp3`(敵人普攻)、`enemy_down.mp3`(敵人死亡，2026-07-19 接線，John 提供)——由武器 `weapon_type`／技能 `sfx`／敵我方資料驅動（見 `battle_state_machine.gd` WTYPE_SFX）。另 `att_bow_arrow.mp3`／`sfx_monster-growl.mp3` 已備未接線，存 `assets-source/sound/`。**授權：Pixabay Content License**（下載自 Pixabay，可免費商用、毋須標註；仍列出以示感謝，同本檔既有 Pixabay 音效/音樂）。

## 背景音樂（Pixabay Music，2026-07-12 新增）
- 授權：Pixabay Content License（免費商用、毋須標註；仍列出以示感謝）。
- bgm_title.mp3 — "Calm Ambient Music – Wizard's Road (Fantasy Background)" by Clavier-Music（標題；1:58。2026-07-16 換入，原為 "Fantasy Adventure Quest" by alex-morgan）
- bgm_town.mp3 — "Fantasy RPG Exploration V2" by RubyZephyr（芳蕾鎮；3:23。2026-07-16 換入，原為 "Medieval Folk Music" by watermelon_beats。Pixabay 標記為 AI 生成，授權仍為 Pixabay Content License）
- bgm_forest.mp3 — "Adventure Forest Exploration" by nathan-180（東之森）
- bgm_dungeon.mp3 — "Dark Fantasy Ambient Dungeon Synth" by deuslower（原礦山/洞穴，2026-07-28 已被 bgm_nm.mp3 取代）
- bgm_battle.mp3 — 戰鬥循環 BGM（loop）。2026-07-27 換入 John 從 Pixabay 抓的新曲（原為 "Powerful Epic Orchestral History Loop" by sonican）。Pixabay Content License（可商用毋須標註）；曲名/作者待補。
- bgm_battle_opening.mp3 — 戰鬥開場層（**非 loop，與 bgm_battle 疊播**；見 `AudioManager.play_bgm_overlay`，battle `_ready` 起播）。2026-07-27 新增（Pixabay）。Pixabay Content License；曲名/作者待補。
- bgm_nm.mp3 — 北方礦山與洞窟 BGM。2026-07-27 新增（NMA–NMF）；**2026-07-28 依 John 指示擴用到 `Mine`（舊 tile 版礦坑）與 `Cave`**，這兩張原本掛 bgm_dungeon.mp3。Pixabay Content License；曲名/作者待補。
- bgm_ef.mp3 — 東之森林與森林深處 BGM（素材源 `assets-source/sound/bgm/ef_bgm.mp3`）。2026-07-28 新增，依 John 指示掛在 EFA–EFI（M3 東之森林）、EFDA–EFDN／EFDM2（M4 東之森深處）與舊 tile 版 EForest1–3 的 `bgm` export；長度 0:19（**刻意的短循環**，John 2026-07-28 確認）。Pixabay Content License；曲名/作者待補。
- bgm_nm_conversation.mp3 — 小節6 與死靈術士對話 BGM（`necro_intro`／`s6_curse` 過場的 `bgm` 欄位觸發，見 `dialogue_system._start_cutscene`）。2026-07-27 新增（Pixabay）。Pixabay Content License；曲名/作者待補。
- bgm_battle_win.mp3 — 戰鬥勝利短曲（一般）；Pixabay Music（Pixabay Content License，可商用毋須標註）。2026-07-16 新增，戰鬥結算時一次性播放不循環（見 battle_state_machine._settle_win）。曲名/作者待補。
- bgm_battle_level_up.mp3 — 戰鬥勝利短曲（有升級）；來源/授權/用法同上。曲名/作者待補。
- 處理：2026-07-12 首批曲目皆經響度正規化與 128kbps 壓製；2026-07-16 換入的 title/town 與勝利短曲已做響度正規化（線性增益對齊 ≈ -17.9 LUFS，同基準批次；128kbps 重壓）。sfx 的 select/cursor 同日以峰值對齊至 ≈ -1.5 dBTP。

## 對話立繪與戰鬥大圖
- `assets/ui/face_*.png`（全 13 位：三主角＋十位鎮民）：AI 生成立繪
  （Gemini gemini-2.5-flash-image，提示詞作者 John/協作 Agent，
  由 /gen-art skill 生成，原圖在 design/faces/、art_v7_faces.py 裁切縮圖）。
  ※ 2026-07-13：十位鎮民立繪全數改「細線稿＋水彩手繪」風重生，配色改由角色設計各自決定（見 DESIGN §3）；三主角待重生。
  程式繪備用版可由 art_v4_portraits.py 重生。
- `assets/ui/portrait_<id>.png`（室內立繪＋選單用的大型前景立繪）：由 design/faces 同一 AI 立繪，
  以 art_v13_title.py **flood-fill 去背**（只挖與邊界相連的背景、人物實心不透）＋裁至 bbox（衍生自上者，授權相同）。
  2026-07-13：全 13 位角色皆產 `portrait_<id>`（一般對話的大型去背立繪 DlgArt＋公會室內前景 IntArt 共用）；
  另 `menuart_<id>`（三主角全身，選單「故事」頁 MenuArt）同法產生（裁邊去浮水印→去背→正規化畫布）。
  ※ 2026-07-18：**路德 ludo** 的 face／portrait／menuart 三張改「日系動漫精緻」風重生＋乾淨去背——一張螢光綠底全身圖經
  `tools/role_slicer/`（瀏覽器 chroma-key 去螢光底＋框選）切出 a `face_ludo`(144²)／b `portrait_ludo`(768×1024)／c `menuart_ludo`(768×1024)；
  portrait 由舊 16:9 改為 **3:4 直幅**（依 角色立繪產圖規格 v1.1）。原圖保留於 `assets-source/role/main/ludo/`。AI 生成、提示詞作者 John。
  ※ 2026-07-18（全角色立繪換裝，15 位）：全部角色改「日系動漫精緻」風、`tools/role_slicer/` 螢光底去背，皆備 a `face_<id>`／b `portrait_<id>`(3:4)／c `menuart_<id>`(3:4)；含改名 `aaron→alan`／`sister→shea`／`guard→rossel`，新增鐵匠 `don`、反派 `necro`。原圖保留於 `assets-source/role/{main,npc,enemies}/<id>/`（2026-07-19 依角色分類歸位）。AI 生成（外部產圖工具）、提示詞作者 John。取代先前「13 位／menuart 僅三主角」狀態；同批 `assets/char` 走路圖（`aaron→alan`／`guard→rossel`／`sister→shea`）與 `assets/battle/hero_aaron_*→hero_alan_*` 一併改名。
  ※ 2026-08-03（潔絲 `jess`）：第二章入隊角色的 a `face_jess.png`／b `portrait_jess.png`／c `menuart_jess.png` 已整合至 `assets/ui/`。立繪由 OpenAI 內建 imagegen 生成，經 John 驗收後以螢光洋紅鍵去背，來源鍵圖、全解析透明版與三張切圖保存於 `assets-source/role/main/jess/`；提示詞作者 John／協作 Agent。
  ※ 2026-08-03（莉莉 `lily`）：第二章入隊角色的 a `face_lily.png`／b `portrait_lily.png`／c `menuart_lily.png` 已整合至 `assets/ui/`。立繪由 OpenAI 內建 imagegen 生成，經 John 驗收後以螢光綠鍵去背，來源鍵圖、全解析透明版與三張切圖保存於 `assets-source/role/main/lily/`；提示詞作者 John／協作 Agent。
  ※ 2026-08-04（三主角身高正規化／亞倫 `alan` 重製）：John 定案亞倫 178 cm、路德 165 cm、瑪琳 158 cm，三張 `menuart_` 依共同鞋底線與同一像素尺度等比正規化。亞倫的 a `face_alan.png`／b `portrait_alan.png`／c `menuart_alan.png` 另由 OpenAI 內建 imagegen 重製為與現有角色一致的現代日系 JRPG 精緻風，經 John 驗收後以螢光綠鍵去背並由同一張全身圖切出；路德與瑪琳只更新 `menuart_` 尺度。來源鍵圖、透明版、舊版備份與正式切圖保存於 `assets-source/role/main/{alan,ludo,marin}/`；提示詞作者 John／協作 Agent。
  ※ 2026-08-04（莉莉 `lily`／潔絲 `jess` 重製與身高正規化）：John 核可莉莉 162 cm、潔絲 167 cm，兩角依共同鞋底線與同一像素尺度重排，並由 OpenAI 內建 imagegen 參照三主角正式立繪重製為一致的現代日系 JRPG 精緻風。莉莉採螢光綠鍵、潔絲採螢光洋紅鍵去背，各自由同一張正規化全身圖切出 a `face_`／b `portrait_`／c `menuart_`；來源鍵圖、透明版、舊版備份與正式切圖保存於 `assets-source/role/main/{lily,jess}/`。提示詞作者 John／協作 Agent。
  ※ 2026-08-04（莉莉木質渦旋法杖定稿）：依 John 提供的杖頭手繪示意圖，以 OpenAI 內建 imagegen 將莉莉法杖改為深褐木質杖身、雙層厚木圓形渦旋與中央淡紫水晶；角色本人及 162 cm 比例維持不變。修正版經螢光綠鍵去背並重新切出 a `face_lily`／b `portrait_lily`／c `menuart_lily`；使用者示意圖、生成鍵圖、透明版與上一版正式素材保存於 `assets-source/role/main/lily/`。提示詞作者 John／協作 Agent。
  ※ 2026-08-04（五人身高比較板）：`assets-source/role/party_height_comparison.png` 由已核可的瑪琳、莉莉、路德、潔絲、亞倫正式 `menuart_` 組版而成，依共同鞋底線與同一像素比例顯示 158／162／165／167／178 cm，未新增生成內容；排版與標示由協作 Agent 製作，並供 HTML 設定集引用。
  ※ 2026-08-13（第二章八位 NPC）：`brock`／`vera`／`hoffman`／`bruno`／`meg`／`magda`／`otto`／`ron` 的 a `face_<id>.png`／b `portrait_<id>.png`／c `menuart_<id>.png` 已整合至 `assets/ui/`。立繪由 OpenAI 內建 imagegen 依第二章角色設定生成，經 John 驗收後以螢光綠／洋紅鍵去背，並依 148–184 cm 共同像素尺度與鞋底線正規化；來源鍵圖、透明母圖與三張切圖保存於 `assets-source/role/npc/<id>/`，身高比較板為 `assets-source/role/npc_ch2_height_comparison.png`。提示詞作者 John／協作 Agent。
  ※ 2026-08-13（老葛雷 `gray` 重製）：a `face_gray.png`／b `portrait_gray.png`／c `menuart_gray.png` 已重製為與正式 NPC 一致的現代日系 JRPG 精緻風，取代原本偏寫實厚塗版本。立繪由 OpenAI 內建 imagegen 生成，經 John 驗收後以螢光綠鍵去背；來源鍵圖、透明母圖與三張切圖保存於 `assets-source/role/npc/gray/`。提示詞作者 John／協作 Agent。
- `assets/battle/hero_*.png`：除下列明列的 AI idle 例外外，由 LPC 合成角色幀放大裁切（沿用 LPC CC-BY-SA/GPL 授權），
  武器圖層取自 LPC weapon walk（longsword/dagger/saber，CC-BY-SA/GPL）。
  - **戰鬥動畫命名改制（2026-07-27，作法B）**：runtime 改為每角一套 `hero_<id>_idle_0..3` ＋單一 `hero_<id>_attack_0..N`（不再分 slash/thrust/spellcast；見 `battle_state_machine.gd` `_load_frames`／`_load_anim_frames`）。舊 `hero_ludo_f/slash/thrust/spellcast`、`hero_marin_f0-3`、`hero_alan_f0-3` 已改名或移除。
  - `hero_marin_idle_0..3`（2026-08-11 更新）：Marin 3.5 頭身 `idle / calm_ready` 四幀循環，由 OpenAI 內建 imagegen 依已驗收 Seed 與短刀 reference 生成 Frame 0／2，Frame 1 以核可端點插值；正式循環為 `0 → 1 → 2 → 1`。John 手動完成三張 Alpha 邊緣微調後驗收，正式幀以 0.5× Nearest 正規化至 543×724、腳底 `y=628`。來源保存於 `assets-source/role/main/marin/battle_idle_0..3.png`、`battle_idle_strip_alpha.png` 與 `battle_idle_review.gif`；提示詞作者 John／協作 Agent。
  - `hero_marin_attack_0..4`（2026-08-13 更新）：Marin 3.5 頭身 `attack / dagger_thrust` 五幀，由 OpenAI 內建 imagegen 依已驗收 Seed、Idle 與短刀 reference 生成；John 驗收起手、下沉、深度蓄力、向畫面左側突刺與收招的動態效果。第 0／1／3／4 幀非持刀手另修正為拇指＋四指；去背採完全透明／完全不透明二值 Alpha，並清除洋紅背景孔洞及外緣污染。正式五幀不縮放、不重新取樣，統一置入 543×724 cell，以畫面右側左腳鞋底最下方三列的接地中心固定於 `(390,628)`，突刺刀尖保留完整。來源保存於 `assets-source/role/main/marin/battle_attack_0..4.png`、`battle_attack_strip_{raw,alpha}.png`、`battle_attack_review_montage.png` 與 `battle_attack_review.gif`；替換前 runtime 五幀封存於 `assets-source/role/main/marin/unofficial/attack/legacy_2026_07/runtime_before_3_5_head/`。提示詞作者 John／協作 Agent。
  - `hero_ludo_idle_0..3`（2026-08-12 更新）：Ludo 3.5 頭身雙手持劍 `idle / ready_guard` 四幀循環，由 OpenAI 內建 imagegen 依已驗收 Seed、長劍 reference 與 Idle 首幀生成 Frame 0／2；Frame 1 使用固定端點 motion-compensated midpoint，正式循環為 `0 → 1 → 2 → 1`。G3～G7 經 John 分階段驗收，正式幀以共用 0.5× Nearest 正規化至 543×724、角色可見中心約 `x=268`、可見框下界 `y=659`。來源保存於 `assets-source/role/main/ludo/battle_idle_0..3.png`、`battle_idle_strip_{raw,alpha}.png`、`battle_idle_review_montage.png` 與 `battle_idle_review.gif`；替換前 runtime 四幀封存於 `assets-source/role/main/ludo/unofficial/idle/runtime_before_3_5_head/`。提示詞作者 John／協作 Agent。`hero_ludo_attack_0-4` 仍為 2026-07-30 的舊二頭身素材，待 P2-1 重做。
  - `hero_ludo_hurt.png`（2026-08-13 更新）：Ludo 3.5 頭身雙手持劍 `hurt / recoil_guard` 單幀，由 OpenAI 內建 imagegen 依已驗收 Seed、長劍 reference 與 Idle 首幀生成；John 選定候選 A，並依標註局部重繪拉直劍身。受擊來自畫面左側，上身向右短促後仰，雙腳接地且雙手持續握住同一劍柄。G3／G5／G7 經 John 分階段驗收，來源保存於 `assets-source/role/main/ludo/battle_hurt_{raw,alpha}.png`；正式圖以 0.5× Nearest 正規化至 543×724、可見中心 `x=267`、腳底最後可見像素 `y=658`，對齊同角色 Idle。替換前 runtime 封存於 `assets-source/role/main/ludo/unofficial/hurt/runtime_before_3_5_head/`。提示詞作者 John／協作 Agent；依 John 指示，本次未執行 Godot import／測試。
  - `hero_ludo_cast.png`（2026-08-13 新增）：Ludo 3.5 頭身 `cast / two_hand_focus` 單幀，由 OpenAI 內建 imagegen 依已驗收 Seed、長劍 reference 與 Idle 首幀生成；John 驗收完整左側身、閉眼集中、雙手向敵方伸直的發射姿勢，以及完整收入右腰劍鞘並延伸至小腿肚的長劍。此動作不含任何魔法特效，且為雙手持劍常規的指定例外。G3／G5／G7 經 John 分階段驗收，來源保存於 `assets-source/role/main/ludo/battle_cast_{raw,alpha}.png`；正式圖以 0.5× Nearest 正規化至 543×724、可見中心 `x=267`、腳底最後可見像素 `y=658`，對齊同角色 Idle。此前 runtime 無同名 Cast；Cast 目前尚未接入戰鬥程式。提示詞作者 John／協作 Agent；Godot import／測試依 John 指示延後至路德剩餘動作整合後一併執行。
  - `hero_ludo_death.png`（2026-08-13 更新）：Ludo 3.5 頭身 `death / fall_forward` 單幀，由 OpenAI 內建 imagegen 依已驗收 Seed、長劍 reference 與 Idle 首幀生成；John 驗收五體投地趴伏、臉朝下、胸腹貼地、雙臂攤開、雙腿後伸、披風覆背鋪地與長劍掉落手邊的最終定格。G3／G5／G7 經分階段驗收，來源保存於 `assets-source/role/main/ludo/battle_death_{raw,alpha}.png`；正式圖以 0.5× Nearest 保持同角色尺度，置入 543×724 Runtime，橫向剪影中心約 `x=268`、最低可見像素 `y=658`，對齊同角色共同中心與地面線。替換前 runtime 封存於 `assets-source/role/main/ludo/unofficial/death/runtime_before_3_5_head/`。提示詞作者 John／協作 Agent；Godot import／測試依 John 指示延後至 Attack 整合後一併執行。
  - `hero_alan_idle_0-3` / `hero_alan_attack_0-4`（2026-07-30 更新）：Alan 重製的二頭身戰鬥圖，AI 生成（imagegen）＋去背，經 John 驗收。idle 為 `calm_ready` 四幀呼吸循環（來源 `assets-source/role/main/alan/battle_idle_strip_{raw,alpha}.png` 與 `battle_idle_0..3.png`，腳底與角色中心錨點已鎖定）；attack 五幀以共用 68% 等比縮放放入同一 543×724 畫布，雙腳錨點與腳底 y=605 鎖定，完整保留水平揮劍。取代先前暫用的舊 LPC idle 與 Alan 單張靜態 idle。提示詞作者 John／協作 Agent。
  - `hero_<id>_hurt` / `hero_<id>_death`（三主角，2026-07-27 整合並接線）：受傷時 sprite 換 hurt 圖＋震動、HP 歸零換 death 圖（見 `battle_state_machine.gd` 我方 sprite 貼圖優先序）。來源：marin/alan＝`battle_{hurt,death}_alpha.png`；ludo 的 hurt／death 已由上方 2026-08-13 新版取代。**cast 暫不整合**（尚無元素魔法技能）。AI 生成、提示詞作者 John／協作 Agent。
  - Marin 短刀戰鬥外觀 seed（2026-07-23）：OpenAI 內建 imagegen 依正式 `battle_role_hd_pixel_v2` prompt、既有 Marin seed 參考生成，經 John 驗收。洋紅鍵原圖與 RGBA 版保存於 `assets-source/role/main/marin/battle_seed_raw.png`、`battle_seed_alpha.png`。此 seed 僅作後續動作產圖的固定外觀 reference，不屬於 runtime 動畫幀。提示詞作者 John／協作 Agent。
  - Marin 短刀與 Ludo 單手劍 weapon reference（2026-07-23）：OpenAI 內建 imagegen 依各自的武器部件說明圖萃取，經 John 驗收並以螢光綠鍵去背為 `assets-source/role/main/marin/battle_weapon_marin_alpha.png` 與 `assets-source/role/main/ludo/battle_weapon_ludo_alpha.png`。兩圖僅作後續 seed／動作產圖的武器外觀 reference，不屬於 runtime 素材；提示詞作者 John／協作 Agent。
  - Alan 單手劍 weapon reference（2026-07-27）：OpenAI 內建 imagegen 依 `menuart_alan.png` 腰佩劍外觀萃取，經 John 驗收並以洋紅鍵去背為 `assets-source/role/main/alan/battle_weapon_alan_alpha.png`（鍵圖保留為 `battle_weapon_alan_raw.png`）。此圖僅作後續 seed／動作產圖的武器外觀 reference，不屬於 runtime 素材；提示詞作者 John／協作 Agent。
  - Lily 木質渦旋長法杖 weapon reference（2026-08-08）：OpenAI 內建 imagegen 依 `menuart_lily.png` 與已定稿的杖頭幾何生成，經 John 驗收後以螢光綠鍵去背為 `assets-source/role/main/lily/battle_weapon_lily_alpha.png`（鍵圖保留為 `battle_weapon_lily_raw.png`）。此圖鎖定深褐木質長杖、上下厚木開口雙層渦旋、中央小型淡紫水晶與少量銀箍，僅作後續 seed／動作產圖的武器外觀 reference，不屬於 runtime 素材；提示詞作者 John／協作 Agent。
  - Lily 戰鬥 seed（2026-08-08，John 指定 `exec-07d08a14`）：OpenAI 內建 imagegen 依莉莉正式全身設定圖與已驗收木質渦旋長法杖 weapon reference 生成，經 John 驗收並以螢光綠鍵去背為 `assets-source/role/main/lily/battle_seed_alpha.png`（鍵圖保留為 `battle_seed_raw.png`）。此圖鎖定莉莉的戰鬥外觀、持握、面向與比例，僅作後續動作首幀及 strip 的固定 reference，不屬於 runtime 動畫幀；提示詞作者 John／協作 Agent。
  - Lily 戰鬥 `idle / calm_ready` 首幀（2026-08-08，候選 C 修正版）：OpenAI 內建 imagegen 依已驗收 Lily seed 與木質渦旋長法杖 weapon reference 生成，經 John 指定將法杖連同持杖手向敵方前移一步、補齊左手五指並加入克制怒意後驗收；螢光綠鍵原圖與透明版保存於 `assets-source/role/main/lily/battle_idle_raw.png`、`battle_idle_alpha.png`。此圖作為後續四幀 idle strip 的首幀造型錨點，本身不直接作為 runtime 動畫；正式 runtime 見下一條四幀 strip；提示詞作者 John／協作 Agent。
  - `hero_lily_idle_0..3`（2026-08-08）：Lily 的 `idle / calm_ready` 四幀循環，由 OpenAI 內建 imagegen 依已驗收 Lily seed、idle 首幀與木質渦旋長法杖 weapon reference 一次生成完整 strip。John 核可呼吸動作後，追加杖頭淡紫水晶的「中央 0° → 上浮 45° → 中央 90° → 下沉 135°」旋轉循環；正式幀以雙鞋接地點中點與鞋底線 root-lock，小腿及鞋部在四幀間逐像素一致，並以共用 1.0 scale 正規化至 543×724 透明畫布、腳底 `y=680`。來源保存於 `assets-source/role/main/lily/battle_idle_strip_{raw,alpha}.png`、`battle_idle_0..3.png`、`battle_idle_review_montage.png` 與 `battle_idle_review.gif`；runtime 為 `godot-project/assets/battle/hero_lily_idle_0..3.png`。提示詞作者 John／協作 Agent。
  - `hero_lily_hurt.png`（2026-08-09，候選 B／`stagger`）：OpenAI 內建 imagegen 依已驗收 Lily seed、idle 成品與木質渦旋長法杖 weapon reference 生成，John 從 `recoil_guard`／`stagger` 兩種受擊反應中核可候選 B。畫面呈現受擊後向右短暫失衡、雙腳仍接地、左手五指張開維持平衡、右手完整握杖，未混入受擊特效；鍵圖與全解析透明版保存於 `assets-source/role/main/lily/battle_hurt_{raw,alpha}.png`，runtime 以兩鞋接地中心與最低鞋底正規化至 543×724 透明畫布、腳底 `y=680`，保存於 `godot-project/assets/battle/hero_lily_hurt.png`。提示詞作者 John／協作 Agent。
  - `hero_lily_cast.png`（2026-08-09，`weapon_channel` 雙手持杖吟唱）：OpenAI 內建 imagegen 依已驗收 Lily seed、idle 外觀與木質渦旋長法杖 weapon reference 生成，John 核可法杖直立、雙手上下錯開完整握杖、閉眼低頭且嘴唇微啟的凝神吟唱姿勢；未加入光球、符文、粒子或其他魔法特效。鍵圖與全解析透明版保存於 `assets-source/role/main/lily/battle_cast_{raw,alpha}.png`，runtime 以 0.5× Nearest 正規化至 543×724 透明畫布、最低鞋底 `y=680`，保存於 `godot-project/assets/battle/hero_lily_cast.png`。提示詞作者 John／協作 Agent。
  - Jess 六翼釘頭錘 weapon reference（2026-08-08）：OpenAI 內建 imagegen 依 `assets-source/role/main/jess/unofficial/portrait/archive/menuart_jess_pre_redesign_2026-08-04.png`、路德單手劍 weapon reference 的 Pixel Art 品質，以及 `docs/design/武器/錘/` 的六翼幾何生成，經 John 驗收後以螢光洋紅鍵去背為 `assets-source/role/main/jess/battle_weapon_jess_alpha.png`（鍵圖保留為 `battle_weapon_jess_raw.png`）。此圖鎖定銀白六翼錘頭、粗實短柄、淺藍握把、小型護手圓盤與金色環座／柄尾，僅作後續 seed／動作產圖的武器外觀 reference，不屬於 runtime 素材；提示詞作者 John／協作 Agent。
  - Jess 戰鬥 seed（2026-08-08，John 指定修正版 `exec-2c70387f`）：OpenAI 內建 imagegen 依潔絲正式角色設定、路德／瑪琳既有戰鬥 seed 的 3.5 頭身比例與品質，以及已驗收六翼釘頭錘 weapon reference 生成；修正版依 Lily 手型補齊左手五指，並將錘頭縮為初版 seed 的 75%。經 John 驗收後以螢光洋紅鍵去背為 `assets-source/role/main/jess/battle_seed_alpha.png`（鍵圖保留為 `battle_seed_raw.png`）。此圖鎖定潔絲的戰鬥外觀、3.5 頭身比例、手型、持握與基準面向，僅作後續動作首幀及 strip 的固定 reference，不屬於 runtime 動畫幀；提示詞作者 John／協作 Agent。
  - Jess 戰鬥 `idle / ready_guard` 首幀（2026-08-08，候選 B／`exec-69088624`）：OpenAI 內建 imagegen 依已驗收 Jess seed、六翼釘頭錘 weapon reference 與 `ready_guard` 動作模板生成，經 John 驗收並以螢光洋紅鍵去背，來源保存於 `assets-source/role/main/jess/battle_idle_raw.png`、`battle_idle_alpha.png`。此圖鎖定中段防守姿勢、錘柄斜向左上收近胸前與左掌護於胸腹前，作為後續四幀 idle strip 的首幀造型錨點，尚未整合為 runtime 動畫；提示詞作者 John／協作 Agent。
  - `hero_jess_idle_0..3`（2026-08-09）：Jess 的 `idle / ready_guard` 四幀呼吸循環，由 OpenAI 內建 imagegen 依已驗收 Jess seed、idle 首幀、六翼釘頭錘 weapon reference 與 `battle_role_hd_pixel_v4` 規格一次生成完整 strip。John 逐幀比較後核可來源幀 `0 → 2 → 3 → 2` 的循環順序；正式幀以雙鞋實際接觸輪廓與鞋底線 root-lock，小腿以下接地區在四幀間逐像素一致，經洋紅鍵 soft matte＋despill 去背後，以共用 1.0 scale 正規化至 `543×724` 透明畫布、腳底 `y=655`。來源保存於 `assets-source/role/main/jess/battle_idle_strip_{raw,alpha}.png`、`battle_idle_0..3.png`、`battle_idle_review_montage.png` 與 `battle_idle_review.gif`；runtime 為 `godot-project/assets/battle/hero_jess_idle_0..3.png`。提示詞作者 John／協作 Agent。
  - Alan 戰鬥 seed（2026-07-27，候選 1）：OpenAI 內建 imagegen 依 `menuart_alan.png` 與已驗收單手劍 weapon reference 生成，經 John 驗收並以洋紅鍵去背為 `assets-source/role/main/alan/battle_seed_alpha.png`（鍵圖保留為 `battle_seed_raw.png`）。此圖為後續動作首幀與 strip 的固定角色外觀、持握與比例 reference，不屬於 runtime 動畫幀；提示詞作者 John／協作 Agent。
  - Alan 戰鬥 `idle / calm_ready` 四幀 strip（2026-07-30）：OpenAI 內建 imagegen 依已驗收 Alan seed、單手劍 weapon reference 與既有 calm_ready 姿勢生成，經 John 驗收，以洋紅鍵去背、soft matte＋despill 清邊後，依腳底與角色中心錨點正規化。來源保存於 `assets-source/role/main/alan/battle_idle_strip_{raw,alpha}.png`、`battle_idle_0..3.png`、`battle_idle_review_montage.png`；runtime 為 `hero_alan_idle_0..3.png`。舊 `battle_idle_{raw,alpha}.png` 已移至 `assets-source/role/main/alan/unofficial/idle/archive/`，保留為初始姿勢歷史參考。提示詞作者 John／協作 Agent。
  - Alan 戰鬥 `hurt / recoil_guard` 首幀（2026-07-27，候選 2）：OpenAI 內建 imagegen 依已驗收 Alan seed 與單手劍 weapon reference 生成，經 John 選定並以洋紅鍵去背為 `assets-source/role/main/alan/battle_hurt_alpha.png`（鍵圖保留為 `battle_hurt_raw.png`）。此圖為 hurt 單幀動作來源，尚未整合為 runtime 素材；提示詞作者 John／協作 Agent。
  - Alan 戰鬥 `cast / forward_palm` 首幀（2026-07-27，修正版）：OpenAI 內建 imagegen 依已驗收 Alan seed 與單手劍 weapon reference 生成，經 John 驗收並以洋紅鍵去背為 `assets-source/role/main/alan/battle_cast_alpha.png`（鍵圖保留為 `battle_cast_raw.png`）。此圖為 cast 單幀動作來源，尚未整合為 runtime 素材；提示詞作者 John／協作 Agent。
  - Alan 戰鬥 `death / kneel_collapse` 首幀（2026-07-27，候選 2）：OpenAI 內建 imagegen 依已驗收 Alan seed 與單手劍 weapon reference 生成，經 John 選定並以洋紅鍵去背為 `assets-source/role/main/alan/battle_death_alpha.png`（鍵圖保留為 `battle_death_raw.png`）。此圖為 death 單幀動作來源，尚未整合為 runtime 素材；提示詞作者 John／協作 Agent。
  - Alan 戰鬥 `attack / sword_horizontal_slash` 首幀（2026-07-27，修正版第 0 幀）：OpenAI 內建 imagegen 依已驗收 Alan seed 與單手劍 weapon reference 生成，經 John 驗收並以洋紅鍵去背為 `assets-source/role/main/alan/battle_attack_alpha.png`（鍵圖保留為 `battle_attack_raw.png`）。此圖為 attack strip 的動作錨點，右手單手持劍、左手不接觸武器；提示詞作者 John／協作 Agent。
  - Ludo 戰鬥 `attack / sword_diagonal_slash` 首幀（2026-07-27，候選 2）：OpenAI 內建 imagegen 依目前已驗收 Ludo seed 與單手劍 weapon reference 重產，經 John 驗收並以螢光綠鍵去背為 `assets-source/role/main/ludo/battle_attack_alpha.png`（鍵圖保留為 `battle_attack_raw.png`）。此圖為 attack strip 的動作錨點，右手單手持劍、左手不接觸武器；提示詞作者 John／協作 Agent。
  - Ludo 戰鬥 `attack / sword_diagonal_slash` 五幀 strip（2026-07-27；2026-07-30 正規化更新）：OpenAI 內建 imagegen 依已驗收 Ludo seed、單手劍 weapon reference 與 attack 首幀生成；John 驗收靜態逐幀與 GIF 後，以螢光綠鍵去背、soft matte＋despill 清邊。2026-07-30 依 John 核可將逐幀統一為 543×724 透明畫布、可見中心與腳底 y=610，消除 idle→attack 位移；來源保存於 `assets-source/role/main/ludo/battle_attack_strip_{raw,alpha}.png`、`battle_attack_0..4.png`、`battle_attack_review_montage.png`，runtime 為 `hero_ludo_attack_0..4.png`；提示詞作者 John／協作 Agent。
  - `hero_alan_attack_0-4`（2026-07-27 整合；2026-07-30 正規化更新）：Alan 的 `sword_horizontal_slash` 五幀動畫，由 John 選定並指定幀序，OpenAI 內建 imagegen 生成後以洋紅鍵去背。2026-07-30 依 John 核可，為完整保留最寬的水平揮劍，五幀採共用 68% 等比縮放、統一至 543×724 透明畫布，以雙腳錨點與腳底 y=605 鎖定；來源保留於 `assets-source/role/main/alan/battle_attack_strip_{raw,alpha}.png`、`battle_attack_0..4.png`、`battle_attack_review_montage.png`，runtime 為 `hero_alan_attack_0..4.png`；提示詞作者 John／協作 Agent。
  - Marin 3.5 頭身戰鬥 `idle / calm_ready` 首幀（2026-08-11）：OpenAI 內建 imagegen 依已驗收的 Marin 3.5 頭身 Seed 與短刀 reference 生成，John 核可候選 3。原始鍵圖保存於 `assets-source/role/main/marin/battle_idle_raw.png`；正式首幀 Alpha 採 John 手動微調版並納入 `hero_marin_idle_0..3`。提示詞作者 John／協作 Agent。
  - Marin 戰鬥 `hurt / recoil_guard` 首幀（2026-07-23）：OpenAI 內建 imagegen 依已驗收的 Marin 短刀 seed 與 weapon reference 生成，經 John 驗收後以洋紅鍵去背。原始鍵圖與 RGBA 版保存於 `assets-source/role/main/marin/battle_hurt_raw.png`、`battle_hurt_alpha.png`；尚未整合為 runtime 素材。提示詞作者 John／協作 Agent。
  - Marin 戰鬥 `cast / forward_palm` 首幀（2026-07-23）：OpenAI 內建 imagegen 依已驗收的 Marin 短刀 seed 與 weapon reference 生成，經 John 驗收後以洋紅鍵去背。原始鍵圖與 RGBA 版保存於 `assets-source/role/main/marin/battle_cast_raw.png`、`battle_cast_alpha.png`；尚未整合為 runtime 素材。提示詞作者 John／協作 Agent。
  - Marin 戰鬥 `death / fall_forward` 首幀（2026-07-23）：OpenAI 內建 imagegen 依已驗收的 Marin 短刀 seed 與 weapon reference 生成，經 John 驗收後以洋紅鍵去背。原始鍵圖與 RGBA 版保存於 `assets-source/role/main/marin/battle_death_raw.png`、`battle_death_alpha.png`；尚未整合為 runtime 素材。提示詞作者 John／協作 Agent。
  - Marin 戰鬥 `attack / dagger_thrust` 起手首幀（2026-07-23）：OpenAI 內建 imagegen 依已驗收的 Marin 短刀 seed 與 weapon reference 生成，經 John 驗收後以洋紅鍵去背。原始鍵圖與 RGBA 版保存於 `assets-source/role/main/marin/battle_attack_raw.png`、`battle_attack_alpha.png`；尚未整合為 runtime 素材。提示詞作者 John／協作 Agent。
  - Marin 戰鬥 `idle / calm_ready` 四幀 strip（2026-07-23）：OpenAI 內建 imagegen 依已驗收的 Marin seed、短刀 weapon reference 與 idle 首幀生成；經 John 驗收後以洋紅鍵去背，並依四格腳底 bottom-center 錨點校正水平位移。原始 strip、RGBA strip、逐幀來源與 Review montage 保存於 `assets-source/role/main/marin/battle_idle_strip_{raw,alpha}.png`、`battle_idle_0..3.png`、`battle_idle_review_montage.png`；尚未整合為 runtime 動畫。提示詞作者 John／協作 Agent。
  - Marin 戰鬥 `attack / dagger_thrust` 五幀 strip（2026-07-23；2026-07-30 正規化更新）：OpenAI 內建 imagegen 依已驗收的 Marin seed 與短刀 weapon reference 生成，經 John 驗收後以洋紅鍵去背、重排為「預備 → 回復預備 → 蓄力 → 左手突刺 → 收刀」。2026-07-30 依 John 核可，逐幀統一為 543×724 透明畫布，以雙腳區域錨點與腳底 y=659 鎖定，消除個別動作幀的水平／垂直漂移。原始 strip、RGBA strip、逐幀來源與 Review montage 保存於 `assets-source/role/main/marin/battle_attack_strip_{raw,alpha}.png`、`battle_attack_0..4.png`、`battle_attack_review_montage.png`；runtime 為 `hero_marin_attack_0..4.png`。提示詞作者 John／協作 Agent。
  - Ludo 戰鬥 `idle` seed／四幀 strip／`hurt`／`cast`／`death`／`attack` 首幀（2026-07-22）：OpenAI 內建 imagegen 依正式 `battle_role_hd_pixel_v2` prompt 與 `menuart_ludo.png` 參考生成，John 驗收 idle、閉眼難過表情 hurt、背負劍鞘 cast、完全趴地 death 與指定劍長 attack seed；`assets/battle/hero_ludo_f0..3.png`、`hero_ludo_hurt.png`、`hero_ludo_cast.png`、`hero_ludo_death.png` 已整合。當時的 attack 首幀僅保留為歷史候選，已由 2026-07-27 的正式五幀斜劈 strip 取代。原始圖、RGBA 版與 idle 預覽包已封存於 `assets-source/role/main/ludo/unofficial/battle/legacy_2026_07/source_bundle/`，提示詞作者 John／協作 Agent。
- `assets/ui/battlebg_*.png`：程序化生成（自製）。2026-07-15：`battlebg_forest.png` 換成 John 提供的「東之森戰鬥背景」圖（取代原程序化版）。2026-07-20：`battlebg_mine.png` 換成 OpenAI 內建 imagegen 生成、經 John 驗收的手繪礦山戰鬥背景；2026-07-30 再依 [`docs/design/戰鬥背景規格.md`](docs/design/戰鬥背景規格.md) v1.0 重製，將畫面下方至少 2/3 改為連續可站立地面，避免角色腳底視覺懸空，經 John 驗收後取代 7/20 版。兩版礦山原圖分別保留於 `assets-source/battle/battlebg_mine_2026-07-20.png` 與 `assets-source/battle/battlebg_mine_2026-07-30.png`。`battlebg_forest_depths.png` 為 2026-07-20 經 John 驗收的深林遺跡戰鬥背景，供 `eforest1`～`eforest3`（含 boss）使用，原圖保留於 `assets-source/battle/battlebg_forest_depths_2026-07-20.png`。上述 AI 圖均為 OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent）。
- `assets/battle/fx_{slash_0..3,blunt_0,burst_0,magic_0}.png`（2026-07-28 整合）：戰鬥受擊特效。**AI 生成**（John 提供 1024×1024 透明底特效幀表，提示詞作者 John）；原圖本身已是透明底、未做去背，以暫存腳本按「每排指定格數＋最細頸部下刀」自動切格（斬光在 x 方向互相重疊，投影法切不開），統一輸出 256×256 置中 RGBA。用途：斬光 4 幀＝有刃武器普攻（素材原方向＝我方打敵人，敵方打我方時 runtime 水平翻轉）、`blunt_0` 白火花＝杖／鈍器／徒手與敵人普攻、`burst_0` 紅橙爆＝物理系技能、`magic_0` 藍星＝魔法系技能。素材源與 17 格完整切圖（含 `_contact.png` 對照表）保留於 `assets-source/battle/fx/slash_sheet_raw.png`、`assets-source/battle/fx/preview/`；未採用的斬光變體 `fx_r1_*`／`fx_r2_*` 與金星芒／橘火星亦在該目錄備用。**授權：AI 生成，John 確認可商用。**（2026-07-30 更正：原記為不得商用，實際與 `fx_stab` 同批同性質，皆可商用。） 取代 `build_cq2.py` 程序產生的 64×64 佔位幀（同批移除不再使用的 `fx_spark_0..3`、`fx_burst_1..3`；治療用 `fx_heal_0..3` 仍為舊佔位圖，待換）。
- `assets/map/north_mine/nm_{a,b,c,d,e,f}.png`（素材源＝`assets-source/map/north_mine/nm_*.png`，2026-07-21 統一為專案命名；總覽圖移至 `north_mine/_overview/`）：
  AI 生成素材（ChatGPT 內建圖片生成功能，提示詞作者 John/協作 Agent，2026-07-16）；北方礦山 a～f 手繪畫面地圖，f 為 boss 房。
  2026-07-17 依地圖連線調整 a、b、c、e 出入口構圖與路徑。
- `assets/map/floret/floret_town.png`（素材源＝`assets-source/map/floret/floret_town.png`）：
  AI 生成素材；M1 芳蕾鎮手繪畫面地圖。2026-07-20 已由 Godot runtime 的無箭頭版本回存為原圖；舊的含箭頭錯誤版本（1254）於 2026-07-21 統一命名時移至 `assets-source/map/floret/_backup/floret-town-1254-old.png`，不作為來源圖使用。2026-07-29 依 `map-def.json` 的 `M1/floret_v2` 40×40 地形藍圖重製，以 John 驗收的明亮像素手繪風格整合北側柱狀岩壁、正式礦山入口與已核可橡樹／松樹物件的森林外觀；OpenAI 內建 imagegen 生成，提示詞作者 John／協作 Agent。
- `assets/map/new_floret_road/nfr_a.png`（素材源＝`assets-source/map/new_floret_road/nfr_a.png`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-24）；M5「通往大都市的路」a 的草原手繪背景。已依 John 確認的 M1 北口、NFR-b 東口、NFR-d 南口 Y 字路徑配置繪製；同日將不可通行河流固定於左側邊界，未加橋或可涉水處。替換前版本保留於 `assets-source/map/new_floret_road/_backup/nfr_a_before_river-2026-07-24.png`；正式圖已機械縮放為 1280×1280，以對齊 32px 格。
- `assets/map/calib/calib_a.png`：
  **非美術素材**——由 `tools/`(PIL) 程式生成的 32px 棋盤底圖（每 5 格粗線＋座標刻度），供 MZ 碰撞校正場實機判讀格線用，無第三方素材、無授權問題。
- `assets/props/m5_tree.png`（素材源＝`assets-source/props/m5_tree/m5_tree_{raw,alpha}.png`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-24）；M5-a 用的俯視手繪闊葉樹。John 驗收後以洋紅鍵去背，原始鍵圖與 alpha 版皆保留於素材源。**2026-08-19 已由素材庫項目 `tree_m5_road_a` 取代，專案端的 `assets/props/m5_tree.png` 同日刪除**（素材源保留）。
- `assets/props/world/nature/1x1/tree_m5_road_a.png`（素材源＝`assets-source/props/world/nature/1x1/tree_m5_road_a/`）：
  同上 `m5_tree` 的 alpha 版整理入庫（2026-08-19，John 驗收）；裁到 alpha 內容框讓樹幹底貼齊圖底（比照其他高物件的 bottom-center anchor 慣例），縮為 201×230（0.21 倍，落在原本六個手工實例的 0.20~0.22 之間）。1×1 footprint＝只擋樹幹腳點；原始 1024×1536 raw/alpha 保留為 `design_anchor_{raw,alpha}.png`。M5-a 六棵樹自此改由 `map-def.json` 的 `props` 驅動，位置與碰撞單一真相，不再是手工節點。
- `assets/props/world/architecture/6x2/building_inn_floret_a.png`（素材源＝`assets-source/props/world/architecture/6x2/building_inn_floret_a/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮可重用旅店高物件。經 John 驗收後以洋紅鍵去背、正規化為 336×224 RGBA PNG；6×2 footprint（2026-07-28 由 6×4 縮為只擋建築底部），正面平行地圖底邊、入口貼齊底邊，並以 bottom-center anchor 在 `YSort` 處理角色遮擋。
- `assets/props/world/architecture/{6x2/building_guild_floret_a,3x2/building_shrine_floret_a,5x2/building_mayor_floret_a,5x2/building_shop_floret_a,5x2/building_smithy_floret_a}.png`（素材源＝對應 `assets-source/props/world/architecture/<footprint>/<id>/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮可重用公會、神殿、鎮長宅、道具店與鐵匠鋪。經 John 批次驗收後以洋紅／淺色棋盤鍵去背，正規化為透明 RGBA PNG；全部正面平行地圖底邊、入口貼齊底邊，並以 bottom-center anchor 在 `YSort` 處理角色遮擋。**2026-08-19：guild、smithy、mayor、shop 四張以既有影像重建二值 alpha，移除錯誤去背留下的半透明背景；同時將既有窗框內的玻璃恢復為不透明、加上低調淡灰反光。畫布尺寸與其餘建築像素內容不變。**
- `assets/props/world/architecture/2x1/house_cottage_floret_a.png`、`assets/props/world/landmark/4x3/landmark_mine_entrance_floret_a.png`（素材源＝對應 `assets-source/props/world/<type>/<footprint>/<id>/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮可重用民宅與北方礦坑入口。經 John 驗收後以洋紅鍵去背並收邊 1px，正規化為透明 RGBA PNG；入口貼齊底邊並以 bottom-center anchor 在 `YSort` 處理角色遮擋。
- `assets/props/world/structure/4x3/stairs_stone_wide_a.png`、`assets/props/world/street/1x1/{street_well_stone_a,street_lamp_iron_a}.png`、`assets/props/world/structure/{1x1/fence_wood_corner_a,1x2/fence_wood_straight_v_a,2x1/fence_wood_straight_a,2x1/fence_wood_gate_a}.png`（素材源＝對應 `assets-source/props/world/<type>/<footprint>/<id>/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮與後續城市可重用的石階、井、路燈與木柵欄系列。經 John 驗收後以洋紅鍵去背並收邊 1px，正規化為透明 RGBA PNG；其中垂直直段由已驗收的水平直段旋轉產生，其餘為原始候選；全部以 bottom-center anchor 在 `YSort` 處理角色遮擋。**2026-07-28：`street_lamp_iron_a` 素材源已由 `design_anchor_alpha.png` 等比重算為 22×101（原 96×192 的正規化把圖垂直拉長 1.39 倍，燈體從 1:4.6 變成 1:6.4；先縮到 3/5 高度、再修正比例），footprint 仍 1×1；專案端 PNG 已於 2026-07-29 隨芳蕾鎮 v2 場景整合同步並 reimport。**
- `assets/props/world/structure/1x1/fence_wood_tile_{corner_tl,corner_tr,corner_bl,corner_br,straight_h,straight_v,gate_h_closed,gate_v_open}_a.png`（素材源＝`assets-source/props/world/structure/1x1/fence_wood_tile_set_a/` 與各對應素材目錄）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-27）；由 John 驗收的 3×3 木柵欄母圖精準切出八個可重用 1×1 自動拼接素材。以洋紅鍵轉為透明 RGBA PNG，並以 bottom-center anchor 在 `YSort` 處理角色遮擋。**2026-07-28：素材源已等比縮為 32×32（原 96×96 在地圖上等於 3×3 格、與 1×1 footprint 不符），拼接對位不變；專案端 PNG 已於 2026-07-29 隨芳蕾鎮 v2 場景整合同步並 reimport。**
- `assets/props/world/structure/1x1/fence_wood_tile_{straight_h_bottom,straight_v_right,gate_h_closed_top,gate_v_open_left}_a.png`（素材源＝對應 `assets-source/props/world/structure/1x1/<id>/`）：
  同一組 3×3 母圖的衍生成員（2026-07-28）。母圖畫的是「右邊開門、下邊關門」的封閉矩形，只提供上邊橫桿、左邊縱桿、下邊關門與右邊開門，其餘邊差 15px／7px 對不上，故由已驗收成員純平移產生：`straight_v_a` 右移 15px、`straight_h_a` 下移 7px、`gate_h_closed_a` 上移 7px、`gate_v_open_a` 左移 15px（不旋轉不鏡像，像素內容與原圖完全相同）；外觀錨點沿用來源素材目錄，`meta.json` 以 `derived_from`／`transform` 記錄。素材源已建立，專案端 PNG 已於 2026-07-29 隨芳蕾鎮 v2 場景整合同步並 reimport。
- `assets/props/world/nature/1x1/{tree_oak_round_a,tree_pine_tall_a}.png`（素材源＝對應 `assets-source/props/world/nature/1x1/<id>/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮與後續城市可重用的闊葉樹與松樹。經 John 驗收後以洋紅鍵去背並收邊 1px，正規化為透明 RGBA PNG；皆以底部樹幹為 bottom-center anchor，在 `YSort` 處理角色遮擋。**2026-07-28：`tree_pine_tall_a` 素材源已由錨點等比重算為 93×169（原正規化垂直拉長 1.39 倍，樹形從 1:1.8 變成 1:2.5）；`tree_oak_round_a` 比例正常未動。專案端 PNG 已於 2026-07-29 隨芳蕾鎮 v2 場景整合同步並 reimport。**
- `assets/props/world/nature/4x4/crop_field_rows_a.png`（素材源＝`assets-source/props/world/nature/4x4/crop_field_rows_a/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮與後續城市可重用的低矮農作列地面。經 John 驗收後正規化為 256×256 PNG；放在 `Ground`，不產生角色遮擋或高物件碰撞。**2026-07-28：素材源已等比縮為 128×128（原 256×256 在地圖上等於 8×8 格、與 4×4 footprint 不符），可拼接特性不變；專案端 PNG 已於 2026-07-29 隨芳蕾鎮 v2 場景整合同步並 reimport。**
- `assets/props/world/nature/1x1/{haystack_small_a,scarecrow_field_a}.png`（素材源＝對應 `assets-source/props/world/nature/1x1/<id>/`）：
  OpenAI 內建 imagegen 生成（提示詞作者 John／協作 Agent，2026-07-26）；芳蕾鎮與後續城市可重用的稻草堆與稻草人。經 John 驗收後以洋紅鍵去背並收邊 1px，正規化為透明 RGBA PNG；皆以 bottom-center anchor 在 `YSort` 處理角色遮擋。**2026-07-28：`scarecrow_field_a` 素材源已由錨點等比重算為 65×96（原正規化垂直拉長 1.63 倍，先修正比例為 87×128、再依 John 指示等比縮到 3 格高）；`haystack_small_a` 比例正常未動。專案端 PNG 已於 2026-07-29 隨芳蕾鎮 v2 場景整合同步並 reimport。**
- `assets/map/east_forest/ef_a.png`（素材源＝`assets-source/map/east_forest/ef_a.png`，2026-07-21 統一命名）：
  AI 生成素材（OpenAI 內建 imagegen，提示詞作者 John／協作 Agent，2026-07-20）；M3 東之森 a 畫面。已依地圖產圖規格移除箭頭、寶箱、告示牌、木箱與木桶等互動物件，保留原有地形與出入口。
- `assets/map/east_forest/ef_{b,c,d}.png`（素材源＝`assets-source/map/east_forest/ef_{b,c,d}.png`，2026-07-21 統一命名；清理前版本存於 `east_forest/_backup/east-forest-{b,c,d-boss-room}-before-cleanup-2026-07-20.png`）：
  AI 生成素材（OpenAI 內建 imagegen，提示詞作者 John／協作 Agent，2026-07-20）；M3 東之森 b、c、d 畫面。已依地圖產圖規格移除箭頭與烘入的互動物件；d 的中央狼型敵人亦已移除，保留原有地形與出入口。
- `assets/map/east_forest_depths/efd_{a…n}.png`（素材源＝`assets-source/map/east_forest_depths/efd_*.png`，2026-07-21 統一命名；**a～f 早已在專案；g～n 於 2026-07-21 整合進專案**，供塊 C `build_scenes.gd` 生成 M4 場景骨架；source 端另存 `efd_m_boss.png` 變體）：
  AI 生成素材（OpenAI Imagen，提示詞作者 John/協作 Agent，2026-07-17）；東之森深處 M4 手繪畫面地圖（a～n）。a 以 M3 `east-forest-g.png` 作視覺延續參考，b～f 再以 a 鎖定同區域的森林低霧、像素尺度與視覺語彙；全部正規化為 1280×1280。
  （原 `east-forest-depths-map.png` 總覽衍生圖依已退休的 `map-def.xlsx` 拼合、現已不在素材庫；總覽改用 map_editor 的連通視圖，`compose_map_overviews.py` 已標為過時。）
- `assets/map/east_forest_depths/efd_m2.png`（素材源＝`assets-source/map/east_forest_depths/efd_m2.png`；**2026-07-21 已整合進專案**）：
  AI 生成素材（ChatGPT 內建圖片生成，提示詞作者 John／協作 Agent，2026-07-20）；M4 東之森深處 m2 畫面——`j` 的 boss（`m`）擊破後開放的分支路線、通往 M7。2026-07-25 經 John 驗收後，以 terrain 藍圖重繪為全幅苔蘚森林與東西向泥路，替換前版本保留於 `east_forest_depths/_backup/efd_m2_before_blueprint_repaint-2026-07-25.png`。
- **[2026-07-21 尺寸統一]** `ef_a–i`、`efd_g–n`＋`efd_m2` 共 18 張原 1254 地圖圖批次縮放（sips）至 1280×1280，讓碰撞格 32／16 整除、消除遷就 1254 的 38；原 1254 版備份於各 dir 的 `_backup/orig_1254/`。屬機械縮放、無新授權變動。
- `assets/ui/face_default.png`（戰鬥面板無行動者時的預設頭像）：AI 生成素材——蓋婭女神石雕（Gemini gemini-2.5-flash-image，提示詞作者 John/協作 Agent，2026-07-15 由 /gen-art skill raw type 生成）。
- `assets/battle/fx_stab_skill_0..4.png`（瑪琳技能命中的斜向刺擊）與 `assets/battle/fx_magic_0..4.png`
  （魔法系技能命中的藍色爆散，**由原本的單幀 `fx_magic_0` 升級為 5 幀**）；**2026-07-30 整合**：
  同一張 `stab_sheet_raw.png` 的第 3 排與第 4 排，處理法同下（亮度轉 alpha＋共用視窗＋對齊亮核），
  地板逐排調（斜向 40／爆散 56——爆散外圈的暈更亮，34 擋不掉會露出方框霧）。
  斜向那排**水平鏡射**後才符合「素材原方向＝我方打敵人」（原圖光條指向右上＝從左邊打過來）。
  切好的幀另存 `assets-source/battle/fx/preview/stab_skill_row3_0..4.png`、`magic_row4_0..4.png`。
  **授權同下：AI 生成，John 確認可商用。**
- `assets/battle/fx_stab_0..3.png`（瑪琳普攻的刺擊特效，256×256 RGBA 四幀；**2026-07-30 整合**）：
  **AI 生成**（John 提供 1254×1254 特效幀表 `assets-source/battle/fx/stab_sheet_raw.png`，提示詞作者 John）。
  **授權：AI 生成，John 確認可商用。**
  原圖是**黑底 RGB、無 alpha**（與 slash 幀表不同），以亮度轉 alpha＋亮度地板 34（smoothstep 到 72）去除
  每格外圈的微亮暈，否則會出現淡淡的方框霧；四幀用**同一個 496×496 視窗＋對齊亮核**裁切，保住幀間相對
  大小與命中點位置（各幀各自縮放會讓小火花被放大成滿框、命中點在動畫中漂移）。
  取用第 2 排（向左的直線刺擊，對上「素材原方向＝我方打敵人」慣例）；未採用的第 1 排（向右）、第 3 排
  （斜向）、第 4／5 排（藍色爆散與碎屑，可作 `fx_magic` 多幀升級的備料）留在幀表內，切好的四幀另存
  `assets-source/battle/fx/preview/stab_row2_0..3.png`。
- `assets/ui/dmg_digits.png`（戰鬥傷害數字圖片字，950×120＝10 格 95×120 的 0–9 透明底；**2026-07-30 經 John 驗收整合**）：
  AI 生成素材（Gemini gemini-2.5-flash-image，提示詞作者 John／協作 Agent，由 /gen-art skill raw type 生成）。
  厚實浮雕金色數字（乳白→暖金漸層＋深棕黑粗描邊＋淡金高光）。**產法**：先產一張風格參考圖定調，再以它當
  image-to-image 風格錨**逐字各產一張**（產圖模型一次畫十個字必有缺字／重複，逐字產才能逐張核對字形），
  然後泛洪去黑底、統一字高 96px 與基線、重排成 10 格等寬。素材源與字形核對圖保存於
  `assets-source/ui/dmg_digits/`（`style_anchor.png` 風格參考、`glyph_check_montage.png` 十字核對、
  `dmg_digits_sheet.png` 成品）。
- `assets-source/props/building_ext/ext_*.png`（六棟建築外觀，洋紅底原圖；**2026-08-19 由 `godot-project/assets/props/` 移到素材源**——它是去背前的原圖，不該留在專案產物裡；專案實際使用的是去背版 `extc_*.png`）：AI 生成素材（Gemini gemini-2.5-flash-image，
  提示詞作者 John/協作 Agent，由 /gen-art skill 的 building type 生成）。2026-07-15 重生成為**正面平視、門在正面下緣**的日系像素風（取代原 2026-07-12 的 45° isometric 版，便於在正交地圖擺進入點）。
  2026-07-16 再把公會/旅店/鎮長宅/鐵匠鋪四棟重繪成**「正面朝前＋屋頂從上方可見」的俯視 45° 感**（比照原本就是此風的神殿/道具店，用 gen-art raw type＋以 extc_shrine/extc_shop 當風格參考圖 image-to-image 生成；門仍在正面下緣，不是舊的 isometric 側視）。
  Godot 端去洋紅底（洋紅特徵 key，非 GDevelop 的 `_clean_ext` 石造重上色）＋裁透明邊產去背版 `extc_*.png`（舊 tile 版 town.tscn 使用；**維持暖色 JRPG 原色**，未套舊灰石調）。**2026-08-19 隨舊 tile 場景一併刪除**——手繪版芳蕾鎮改用素材庫的 `building_*_floret_a`；原圖仍在素材源可隨時重出去背版。
- ~~`assets/props/f_*.png`（室內家具）與 `assets/props/int_room_{wood,stone}.png`（室內房間外殼）~~：程序化像素繪製（自製，`art_v12_furniture.py` 以 PIL 繪，無授權限制）。**2026-08-19 已刪除**——室內改成整張手繪大圖 `intc_<key>` 後，這批家具拼貼素材全無引用。
- `assets/props/int_<key>.png`（六棟室內大圖：公會/旅店/神殿/鎮長宅/道具店/鐵匠鋪）：AI 生成素材
  （Gemini gemini-2.5-flash-image，提示詞作者 John/協作 Agent，2026-07-13，由 /gen-art skill 的 interior type
  「細線稿＋水彩手繪」風生成、色調隨房間氛圍決定）。現行室內為「立繪＋選單式」，build 去底產衍生版 `intc_<key>.png` 當手繪背景註冊進 game.json。
- `assets/char/rossel_*.png`（羅素隊長既有四向走路圖）：
  LPC 角色產生器圖層合成（`art_v10_npcwalk.py`；body＋頭＋鬍/帽/鎖甲染色），授權同主角 **CC-BY-SA 3.0 / GPL 3.0**。
- `assets/char/gray_Down_0..8.png`（老葛雷地圖向下待機／左右踏步，2026-08-13 更新）：
  OpenAI 內建 imagegen 依 John 核可的葛雷 64×64 `Down Idle` 母幀延伸；正式 `Down_0` 鎖定原核可像素不重畫，`Down_1..8` 僅以左右踏步交替。以螢光綠鍵去背、母幀 21 色盤與 bottom-center 錨點正規化；來源保存在 `assets-source/role/npc/gray/overworld_final/`。提示詞作者 John／協作 Agent。
- `assets/char/necro_Field_0..2.png`、`assets/char/bear_Field_0..2.png`（第一章事件地圖角色，2026-08-13）：
  OpenAI 內建 imagegen 依核可角色／魔物立繪生成三幀地圖動作。死靈術士為 64×64 正面 `Idle / Step L / Step R`；凶暴熊為 96×64 右向 `Idle / Step A / Step B`，只在橫向增加 32px。兩者以螢光綠鍵去背、共用 bottom-center 錨點正規化，場景腳下影子為 runtime 程序生成；來源保存在 `assets-source/role/enemies/{necro,bear}/overworld_final/`。提示詞作者 John／協作 Agent。
- `assets/char/bear_Upright_0..2.png`（第一章 EF-I 採蜜複戰直立熊，2026-08-13）：
  OpenAI 內建 imagegen 依核可凶暴熊地圖 sprite、狂暴洞熊立繪與 64px 主角比例生成三幀正面直立威嚇呼吸動作，正規化為原生 64×96、bottom-center 共用錨點。EF-G 初遇仍使用四足 `bear_Field_0..2`；EF-I 複戰使用本組直立圖。來源保存於 `assets-source/role/enemies/bear/overworld_upright_final/`。提示詞作者 John／協作 Agent。
- 路德舊 LPC 走路圖（2026-07-18，已於 2026-07-28 退出 runtime）：由 **Universal LPC Spritesheet Generator**（sanderfrenken）組裝 LPC 圖層（teen body＋messy2 髮＋leather 皮甲＋紅 cape＋cuffed pants＋leather boots＋bracers）。逐層作者、授權與配方仍完整保留於 `assets-source/role/main/ludo/ludo_lpc_credits.txt`、`ludo_lpc_recipe.json` 與 `ludo_lpc/`，供歷史追溯；授權為 **OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0**（shadow 層 CC0）。同套 LPC 有劍版產出的舊戰鬥素材授權不變。
- `assets/props/chest_closed.png`／`chest_opened.png`（地圖寶箱兩態）：程序化像素繪製（自製，build_cq2.py 內以 PIL 繪，無授權限制；同 barrel/crate/lamp 等程序繪 props）。
- `assets/props/herb.png`（第一章委託鏡草）／`helmet.png`（第一章礦山遺物「阿吉的礦工頭盔」）：OpenAI 內建 imagegen 生成，經 John 驗收後以洋紅鍵去背、最近鄰縮放為 32×32px 透明 PNG（2026-07-23）；原圖與 alpha 版分別保存於 `assets-source/props/mirror_grass/`、`assets-source/props/miner_helmet/`，提示詞作者 John／協作 Agent。
- `assets/props/wolf_fang.png`／`assets/icons/wolf_fang.png`（第一章「討伐取證」狼牙證物）：OpenAI 內建 imagegen 生成，經 John 驗收 design anchor 候選 3、地圖拾取物候選 2 與背包圖示候選 3 後，以洋紅鍵去背、等比正規化為 32×32px bottom-center 與 64×64px 置中 RGBA PNG（2026-07-30）；原圖、alpha 版與成品保存於 `assets-source/props/wolf_fang/`，提示詞作者 John／協作 Agent。
- `assets/ui/joybase/joyknob/btn_a/btn_menu/btn_back/pad_*/btn_s*`（觸控虛擬搖桿與按鈕）：
  程序化繪製（自製，build_cq2.py 內以 PIL 繪；力/敏/智 字用系統字體 STHeiti 烘入）。
- 地牢地板圖磚（gravel 遇敵/cavedark，art_v2.py toroidal wrap_dither 無縫重繪）：自製像素，無授權限制。
- **地牢主地板（rockfloor/cavefloor）與氛圍裝飾**（骷髏/顱堆/骨散/蜘蛛網/裂縫 `assets/props/dun_*.png`；**2026-08-19 隨舊 tile 場景 cave/mine 刪除，連同 `cavemouth`／`rubble`／`stal_*`**）：[**[LPC] Dungeon Elements**](https://opengameart.org/content/lpc-dungeon-elements)（`dungeonex.png` 的 cobblestone 與道具）—— CC-BY 4.0/3.0 / GPL / OGA-BY 3.0 —— Sharm（graphic artist）＋貢獻者。cobblestone 經 art_v2.py 去飽和套礦坑/洞穴灰階；原表存 `tools/lpc-dungeon/`。
## 敵人戰鬥圖（全部 LPC 重製，2026-07-12；取代原 16px 商店圖，來源 `assets/battle/lpc_src/`）

**人形怪**（哥布林/獸人/哥布林頭目/骷髏/死靈術士/食人魔）：LPC 角色產生器圖層合成（`art_v8_foes.py`：body＋怪物頭＋衣物染色）。授權 **CC-BY-SA 3.0 / GPL 3.0**（同主角，LPC 貢獻者群）。
- **死靈術士二頭身戰鬥動畫（2026-07-22）**：`assets/battle/foe_necro_0..3.png` 為 4 幀 `idle`，`foe_necro_attack_0..4.png` 為 5 幀 `attack`；`foe_necro_hurt.png`、`foe_necro_cast.png`、`foe_necro_death.png` 為單幀動作。素材由 OpenAI 內建 `imagegen` 依 `menuart_necro.png` 與已驗收 seed 參考生成，經 John 驗收後以螢光綠鍵去背、等格切圖輸出透明 PNG；原始 strip、alpha strip 與切格原檔保存於 `assets-source/role/enemies/necro/`，提示詞作者 John／協作 Agent。strip 採固定幀間距與四周安全留邊，未加入格線或分隔框。舊 LPC `foe_necro_0..3.png` 已移至 `godot-project/assets/battle/legacy_lpc_necro/` 備份。

**非人形怪**（OpenGameArt LPC 相容生物包，`art_v9_creatures.py` 裁切；原表存 `tools/lpc-creatures/`）：
- 綠黏史萊姆 / 巨牙蟲 / 礦坑飛魔 / 異變的魔影：[**[LPC] Monsters**](https://opengameart.org/content/lpc-monsters)（slime / big_worm / bat / ghost）—— **CC-BY-SA 3.0 / GPL 3.0** —— Charles Sanchez (CharlesGabriel)、bagzie、bluecarrot16。
- 暗影小魔：[**[LPC] Imp 2**](https://opengameart.org/content/lpc-imp-2) —— CC-BY 4.0/3.0 / GPL / OGA-BY 3.0 —— Stephen "Redshrike" Challener（graphic artist）＋ William.Thompsonj（contributor）。
- 洞熊／狂暴洞熊：[**[LPC] bears, deer, lions and more**](https://opengameart.org/content/lpc-bears-deer-lions-and-more)（grizzly bear）—— **CC-BY 4.0** —— tapatilorenzo（部分衍生自 Sevarihk）。
- 野狼（取代先前的熊 recolor 佔位）：[**[LPC] Wolf Animation**](https://opengameart.org/content/lpc-wolf-animation) —— CC-BY 4.0/3.0 / GPL / OGA-BY 3.0 —— Stephen "Redshrike" Challener ＋ William.Thompsonj。
- 掠翅鳥：[**[LPC] Birds**](https://opengameart.org/content/lpc-birds)（eagle）—— CC-BY 4.0/3.0 / CC-BY-SA / GPL / OGA-BY —— bluecarrot16（castelonia 委製）。
- **礦山兩幀戰鬥圖（2026-07-19）**：`foe_wogol_*` 由既有 LPC 素材裁切後製成兩幀呼吸，原授權沿用本節對應條目；`foe_skeleton_*`、`foe_orc_*`、`foe_bear_*` 為 OpenAI 圖片生成候選經 John 驗收後，以洋紅鍵去背、最近鄰縮放為右向戰鬥圖（提示詞作者 John／協作 Agent）。原始兩幀皆保存於 `assets-source/role/enemies/<enemy_id>/`。
- **東之森兩幀戰鬥圖（2026-07-19）**：`foe_bird_*`、`foe_gslime_*`、`foe_goblin_*`、`foe_worm_*`、`foe_wolf_*`、`foe_maskedorc_*` 為 OpenAI 圖片生成候選經 John 驗收後，以洋紅鍵去背、最近鄰縮放產出；各自採對應的拍翅、壓縮、重心、身節或待機動作（提示詞作者 John／協作 Agent）。原始兩幀保存於 `assets-source/role/enemies/<enemy_id>/`。
- **東之森深處兩幀戰鬥圖（2026-07-19）**：`foe_goblin_shaman_*`、`foe_goblin_tamer_*`、`foe_wild_hare_*`、`foe_horn_hare_*`、`foe_thorn_boar_*`、`foe_fungus_owl_*`、`foe_rotwood_beetle_*` 為 OpenAI 圖片生成候選經 John 驗收後，以洋紅鍵去背、共用錨點正規化為兩幀右向戰鬥圖（提示詞作者 John／協作 Agent）。`wild_hare` 為 `horn_hare` 的共用基底，後者僅增加一支短角；原始兩幀保存於 `assets-source/role/enemies/<enemy_id>/`。
- **狂暴洞熊兩幀戰鬥圖（2026-07-21，首張 Gemini 產戰鬥圖）**：`bear_dire` 的 `combat_0/1.png`（101×72 透明兩幀呼吸）為 **Gemini（gemini-2.5-flash-image）** image-to-image 生成候選（以 `portrait_bear_dire` 保黑晶／暗紫眼特徵、`bear/portrait` 錨定右向側身姿勢），經 John 驗收後以玫紅色距鍵去背＋despill、最近鄰縮小產出。呼吸第二幀採頭／口鼻、肩背、單前掌、胸腔 4 處局部位移（非整體縮放、非重繪，輪廓不變）。原始兩幀保存於 `assets-source/role/enemies/bear_dire/`；尚未接入 Godot runtime（無敵人資料／遭遇表）。提示詞作者 John／協作 Agent。
- **獸人挖掘者 HD 戰鬥圖重製（2026-08-17，TASKS/20 P1 首隻）**：`assets/battle/foe_orc_0..3.png`（272×396 透明四幀 idle 呼吸循環）為 **Gemini（gemini-2.5-flash-image）** image-to-image 生成（seed 以 `portrait_orc.png` 保礦燈頭巾／獠牙／鐵鎬特徵、`battle_enemy_v2` preset），經 John G1~G7 分階段驗收。呼吸四幀採單一核可基準幀＋逐列平滑垂直 warp（腰下 0 位移腳釘死、頂部 2.5/5/2.5px 相位），幀 3＝幀 1 保證循環無縫。以洋紅色距鍵去背＋despill；seed／原始 strip／逐幀／montage 保存於 `assets-source/role/enemies/orc/battle_*`。取代 2026-07-19 的 OpenAI 兩幀舊圖（44×56）。提示詞作者 John／協作 Agent。
- **礦坑飛魔 HD 戰鬥圖重製（2026-08-17，TASKS/20 P1）**：`assets/battle/foe_wogol_0/1.png`（866×717 透明兩幀撲翼）為 **Gemini（gemini-2.5-flash-image）** image-to-image 生成（seed 以 `portrait_wogol.png` 保雙角／尖耳／發光眼／水晶碎片特徵；幀 1＝翼小幅下壓 15~20° 的獨立重繪，John 退回全幅下拍與 warp 版後定案），經 G1~G7 分階段驗收。去背採**邊界連通法**（綠底撞灰綠毛皮的破圖修正）；兩幀以腿部區互相對位、最低爪尖同列。來源保存於 `assets-source/role/enemies/wogol/battle_*`。取代 2026-07-19 的 LPC 裁切兩幀（36×20），該條 LPC 授權標註對 `foe_wogol_*` 不再適用。提示詞作者 John／協作 Agent。
- **礦山魔物設定集圖（2026-07-19）**：`wogol`、`skeleton`、`orc`、`wolf`、`bear` 各有 `portrait_<enemy_id>.png`（透明背景設定集全身立繪），均由 OpenAI 內建 imagegen 生成、經 John 驗收後存於 `assets-source/role/enemies/<enemy_id>/`（提示詞作者 John／協作 Agent）。
- **魔物設定集圖（第二批，2026-07-21）**：`bird`、`gslime`、`goblin`、`worm`、`bear_dire`、`ogre`、`shadow_demon` 各有 `portrait_<enemy_id>.png`（透明背景設定集全身立繪），均由 ChatGPT 內建圖片生成、經 John 驗收（提示詞作者 John／協作 Agent）。原圖帶對比螢光底（洋紅／紅／黃），以色距鍵去背（chroma-key＋alpha 反解去溢色）；`shadow_demon` 為煙霧體、刻意保留半透明穿透。帶底原圖保存於同目錄 `tmp_portrait_<enemy_id>.png`。
- **東之森深處魔物設定集圖（2026-07-21）**：`goblin_shaman`、`goblin_tamer`、`wild_hare`、`horn_hare`、`thorn_boar`、`fungus_owl`、`rotwood_beetle` 各有 `portrait_<enemy_id>.png`（透明背景設定集全身立繪），均由 ChatGPT 內建圖片生成、經 John 驗收後存於 `assets-source/role/enemies/<enemy_id>/`（提示詞作者 John／協作 Agent）。
- **全敵人公會懸賞黑墨圖（2026-07-19）**：`goblin_shaman`、`goblin_tamer`、`goblin`、`goblin_chief`、`wild_hare`、`horn_hare`、`thorn_boar`、`fungus_owl`、`rotwood_beetle`、`bird`、`gslime`、`worm`、`wolf`、`bear`、`bear_dire`、`wogol`、`skeleton`、`orc`、`chort`、`necro`、`ogre`、`shadow_demon` 各有 `bounty_<enemy_id>.png`（透明背景、簡易單色黑墨圖案）。均由 OpenAI 內建 imagegen 生成、經 John 批次驗收後存於 `assets-source/role/enemies/<enemy_id>/`（提示詞作者 John／協作 Agent）；羊皮紙僅為驗收預覽底，不包含在正式 `bounty_*` 圖檔；目前尚未被 Godot runtime 引用。
- **LPC 怪物試作（尚未納入正式遭遇表）**：`foe_briar_bloom_*`（荊棘食人花）與 `foe_crystal_bee_*`（晶蜂）裁自 [**[LPC] Monsters**](https://opengameart.org/content/lpc-monsters)—— **CC-BY-SA 3.0 / GPL 3.0**，Charles Sanchez（CharlesGabriel）、bagzie、bluecarrot16；`foe_giant_rat_*`（礦坑巨鼠）裁自 [**[LPC] bears, deer, lions and more**](https://opengameart.org/content/lpc-bears-deer-lions-and-more)—— **CC-BY 4.0**，tapatilorenzo／Sevarihk。原始 spritesheet 備份於 `assets/battle/lpc_preview_source/`。
- `assets/ui/title_layers/title_bg.png`、`title_heroes.png`（模組化標題畫面既有圖層）：AI 生成（OpenAI Imagen，提示詞作者 John/協作 Agent，
  2026-07-17，依 /gen-art 的 title 構圖規格生成）。背景與男女主角剪影皆為獨立 PNG；透明圖層由洋紅色鍵去背。
- `assets/ui/title_layers/title_crystal.png`、`title_backplate.png`（新版水晶徽記／半透明符文背板）：OpenAI 內建 imagegen 生成，
  經 John 於 2026-07-20 驗收；提示詞作者 John／協作 Agent，洋紅色鍵去背。title_crystal 另存一份
  `assets-source/ui/title_crystal.png`（同圖同授權）供設定集 codex 背景飾紋引用。`title_zh.png` 與
  `title_en.png` 為協作 Agent 以系統字體合成的透明文字圖層，內容為「水晶傳說：路德篇」與
  「Tale of Crystal: The Legend of Ludo」，無外部素材授權需求。
  標題選單描邊字 `t_start/t_cont/t_restart.png` 亦為 PIL 系統字體烘製（自製）。
  ※ 遊戲定名：水晶傳說：路德篇 Tale of Crystal: The Legend of Ludo（主標 水晶傳說／Tale of Crystal ＋ 副標 路德篇／The Legend of Ludo）；曾誤植「水晶奇譚」「水晶戰記」，已更正。
  專案資料夾 crystal-quest 維持為代號。

## 第一章事件 CG（2026-08-16）

- `assets/cg/cg_s1_bear.png`（亞倫救場）、`cg_s3_alan_fall.png`（亞倫斷後）、`cg_s6_curse.png`（黑水晶爆發／瑪琳中咒）、`cg_s6_report.png`（章末床邊）：**Gemini（gemini-2.5-flash-image）** 以 `menuart_alan/ludo/marin.png` 立繪為 `--ref-image` 參考生成，與角色立繪同款動漫賽璐璐風；經 John 驗收（2026-08-16）後去邊裁切 16:9 整合。原圖保存於 `assets-source/cg/`；提示詞作者 John／協作 Agent。規格見 `docs/design/事件演出規格.md`，由過場 `.tres` 的 `image` 欄位載入（dialogue_box 事件 CG 圖層顯示）。

- **異變的魔影戰鬥圖重製（2026-08-16）**：`assets/battle/foe_demon_0..3.png`（91×128 透明四幀 idle 呼吸）為 **Gemini（gemini-2.5-flash-image）** image-to-image 生成（以 `portrait_shadow_demon.png` 為本體參考、依 `docs/pipeline/battle_art/prompts/descriptions/shadow_demon.md` v2 描述），經 John 驗收（seed D 案）後以色距鍵去背＋背景反混＋despill 產出；呼吸幀＝上身羽化位移＋煙尾底邊釘死＋胸口光核強弱（非整體縮放）。seed 原檔與四幀保存於 `assets-source/role/enemies/shadow_demon/`（`battle_seed_raw/alpha.png`、`combat_0..3.png`）；**匯入日起即錯置的舊 `foe_demon_*`（62×82 ＋ 36×40 兩套混用）備份於同目錄 `legacy/`**。提示詞作者 John／協作 Agent。

- `assets/props/world/street/1x1/street_lamp_iron_a.png`、`assets/props/world/nature/1x1/scarecrow_field_a.png` **2026-08-19 微調**：John 實機校正後，於圖底各補 2px 透明容錯（僅加透明邊，未改繪製內容），畫布分別成為 22×103、65×98。
