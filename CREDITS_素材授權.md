> **[Godot 遷移副本說明]** 本檔案於 **2026-07-14** 隨 `godot-project/assets/` 的資產一併從
> `gd-crystal-tales/projects/crystal-quest/CREDITS_素材授權.md` 複製而來（MOD-I 任務）。
> 自複製日起，GDevelop 版與 Godot 版的資產各自演進時，兩邊的授權文件需**分別維護**——
> Godot 端動任何素材，改的是本檔案；GDevelop 端的更新不會自動同步過來。
> 文中提及的 `tools/`、`design/`、`art_v*.py`、`build_cq2.py` 等路徑為 GDevelop 端工作區路徑，
> 生成腳本依 TASKS/09 決議留在 GDevelop 端，Godot 專案只消費產出的 PNG/音檔。

# 素材授權標註（水晶傳說）

## 角色
LPC 角色產生器圖層合成（CC-BY-SA/GPL），圖層配方參考 overworld-demo/CREDITS_素材授權.md；戰鬥怪物與道具為 GDevelop 商店 CC0（16x16 dungeon tileset、grafxkid、western fps 2d 等包）。

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
- bgm_dungeon.mp3 — "Dark Fantasy Ambient Dungeon Synth" by deuslower（礦山/洞穴）
- bgm_battle.mp3 — "Powerful Epic Orchestral History Loop" by sonican（戰鬥）
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
- `assets/battle/hero_*.png`：除下列明列的 AI idle 例外外，由 LPC 合成角色幀放大裁切（沿用 LPC CC-BY-SA/GPL 授權），
  武器圖層取自 LPC weapon walk（longsword/dagger/saber，CC-BY-SA/GPL）。
  - `assets/battle/hero_marin_f0-3.png`：2026-07-20 改為 OpenAI 內建 imagegen 生成、經 John 驗收的兩格睜眼待機動作（f0/f2、f1/f3 各對應一格），以螢光綠鍵去背後輸出透明 PNG；原始鍵圖與 alpha 版保存於 `assets-source/role/main/marin/battle_idle/`，提示詞作者 John／協作 Agent。
- `assets/ui/battlebg_*.png`：程序化生成（自製）。2026-07-15：`battlebg_forest.png` 換成 John 提供的「東之森戰鬥背景」圖（取代原程序化版）。2026-07-20：`battlebg_mine.png` 換成 OpenAI 內建 imagegen 生成、經 John 驗收的手繪礦山戰鬥背景；`battlebg_forest_depths.png` 為同日經 John 驗收的深林遺跡戰鬥背景，供 `eforest1`～`eforest3`（含 boss）使用。原圖分別保留於 `assets-source/battle/battlebg_mine_2026-07-20.png` 與 `assets-source/battle/battlebg_forest_depths_2026-07-20.png`（提示詞作者 John／協作 Agent）。
- `assets/map/north_mine/nm_{a,b,c,d,e,f}.png`（素材源＝`assets-source/map/north_mine/nm_*.png`，2026-07-21 統一為專案命名；總覽圖移至 `north_mine/_overview/`）：
  AI 生成素材（ChatGPT 內建圖片生成功能，提示詞作者 John/協作 Agent，2026-07-16）；北方礦山 a～f 手繪畫面地圖，f 為 boss 房。
  2026-07-17 依地圖連線調整 a、b、c、e 出入口構圖與路徑。
- `assets/map/floret/floret_town.png`（素材源＝`assets-source/map/floret/floret_town.png`）：
  AI 生成素材；M1 芳蕾鎮手繪畫面地圖。2026-07-20 已由 Godot runtime 的無箭頭版本回存為原圖；舊的含箭頭錯誤版本（1254）於 2026-07-21 統一命名時移至 `assets-source/map/floret/_backup/floret-town-1254-old.png`，不作為來源圖使用。
- `assets/map/east_forest/ef_a.png`（素材源＝`assets-source/map/east_forest/ef_a.png`，2026-07-21 統一命名）：
  AI 生成素材（OpenAI 內建 imagegen，提示詞作者 John／協作 Agent，2026-07-20）；M3 東之森 a 畫面。已依地圖產圖規格移除箭頭、寶箱、告示牌、木箱與木桶等互動物件，保留原有地形與出入口。
- `assets/map/east_forest/ef_{b,c,d}.png`（素材源＝`assets-source/map/east_forest/ef_{b,c,d}.png`，2026-07-21 統一命名；清理前版本存於 `east_forest/_backup/east-forest-{b,c,d-boss-room}-before-cleanup-2026-07-20.png`）：
  AI 生成素材（OpenAI 內建 imagegen，提示詞作者 John／協作 Agent，2026-07-20）；M3 東之森 b、c、d 畫面。已依地圖產圖規格移除箭頭與烘入的互動物件；d 的中央狼型敵人亦已移除，保留原有地形與出入口。
- `assets/map/east_forest_depths/efd_{a,b,c,d,e,f}.png`（素材源＝`assets-source/map/east_forest_depths/efd_*.png`，2026-07-21 統一命名；source 端另有 g～n 全 14 張＋`efd_m_boss.png`，專案端 g～n 待整合）：
  AI 生成素材（OpenAI Imagen，提示詞作者 John/協作 Agent，2026-07-17）；東之森深處 M4-a～f 手繪畫面地圖。a 以 M3 `east-forest-g.png` 作視覺延續參考，b～f 再以 a 鎖定同區域的森林低霧、像素尺度與視覺語彙；全部正規化為 1280×1280。
  （原 `east-forest-depths-map.png` 總覽衍生圖依已退休的 `map-def.xlsx` 拼合、現已不在素材庫；總覽改用 map_editor 的連通視圖，`compose_map_overviews.py` 已標為過時。）
- `assets-source/map/east_forest_depths/efd_m2.png`（素材源；專案端待整合）：
  AI 生成素材（ChatGPT 內建圖片生成，提示詞作者 John／協作 Agent，2026-07-20）；M4 東之森深處 m2 畫面——`j` 的 boss（`m`）擊破後開放的分支路線、通往 M7。
- `assets/ui/face_default.png`（戰鬥面板無行動者時的預設頭像）：AI 生成素材——蓋婭女神石雕（Gemini gemini-2.5-flash-image，提示詞作者 John/協作 Agent，2026-07-15 由 /gen-art skill raw type 生成）。
- `assets/props/ext_*.png`（六棟建築外觀，洋紅底原圖）：AI 生成素材（Gemini gemini-2.5-flash-image，
  提示詞作者 John/協作 Agent，由 /gen-art skill 的 building type 生成）。2026-07-15 重生成為**正面平視、門在正面下緣**的日系像素風（取代原 2026-07-12 的 45° isometric 版，便於在正交地圖擺進入點）。
  2026-07-16 再把公會/旅店/鎮長宅/鐵匠鋪四棟重繪成**「正面朝前＋屋頂從上方可見」的俯視 45° 感**（比照原本就是此風的神殿/道具店，用 gen-art raw type＋以 extc_shrine/extc_shop 當風格參考圖 image-to-image 生成；門仍在正面下緣，不是舊的 isometric 側視）。
  Godot 端去洋紅底（洋紅特徵 key，非 GDevelop 的 `_clean_ext` 石造重上色）＋裁透明邊產去背版 `extc_*.png`（town.tscn 實際使用；**維持暖色 JRPG 原色**，未套舊灰石調）。
- `assets/props/f_*.png`（室內家具：床/桌椅/櫃架/櫃檯/壁爐/祭壇/鐵砧/武具架…）與
  `assets/props/int_room_wood/stone.png`（室內房間外殼）：**程序化像素繪製（自製，`art_v12_furniture.py` 以 PIL 繪，無授權限制）**。
- `assets/props/int_<key>.png`（六棟室內大圖：公會/旅店/神殿/鎮長宅/道具店/鐵匠鋪）：AI 生成素材
  （Gemini gemini-2.5-flash-image，提示詞作者 John/協作 Agent，2026-07-13，由 /gen-art skill 的 interior type
  「細線稿＋水彩手繪」風生成、色調隨房間氛圍決定）。現行室內為「立繪＋選單式」，build 去底產衍生版 `intc_<key>.png` 當手繪背景註冊進 game.json。
- `assets/char/gray_*/rossel_*.png`（老葛雷/羅素隊長 36 幀走路圖，戶外遊走 NPC）：
  LPC 角色產生器圖層合成（`art_v10_npcwalk.py`；body＋頭＋鬍/帽/鎖甲染色），授權同主角 **CC-BY-SA 3.0 / GPL 3.0**。
- `assets/char/ludo_*.png`（路德 36 幀走路圖，**2026-07-18 重製**）：由 **Universal LPC Spritesheet Generator**（sanderfrenken）組裝 LPC 圖層（teen body＋messy2 髮＋leather 皮甲＋紅 cape＋cuffed pants＋leather boots＋bracers），採**乾淨無拔劍**版當 overworld 走路圖。授權 **OGA-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0**（shadow 層 CC0）。**逐層完整作者／授權／連結見 `assets-source/role/main/ludo/ludo_lpc_credits.txt`**；配方存 `assets-source/role/main/ludo/ludo_lpc_recipe.json`（可 Import 回產生器重出/微調）。主要貢獻者：bluecarrot16、Stephen Challener (Redshrike)、Benjamin K. Smith (BenCreating)、JaidynReiman、ElizaWy、Johannes Sjölund (wulax)、Matthew Krohn (makrohn)、Pierre Vigier (pvigier)、Evert、TheraHedwig、MuffinElZangano、Durrani、Manuel Riecke (MrBeast)、Nila122、drjamgo 等 LPC 貢獻者。**戰鬥攻擊圖** `assets/battle/hero_ludo_{slash,thrust,spellcast}_*`（揮劍／突刺／詠唱；slash＝oversized `custom/slash_128`、thrust/spellcast＝standard）取自同一 LPC **有劍版**（`ludo_lpc/without_sword`，含紅 cape＋Arming Sword），授權／作者同上。**戰鬥 idle 圖** `assets/battle/hero_ludo_f0-3` 於 2026-07-20 改為 OpenAI 內建 imagegen 生成、經 John 驗收的兩格待機動作（f0/f2、f1/f3 各對應一格），以螢光綠鍵去背後輸出透明 PNG；原始鍵圖與 alpha 版保存於 `assets-source/role/main/ludo/battle_idle/`，提示詞作者 John／協作 Agent。
- `assets/props/chest_closed.png`／`chest_opened.png`（地圖寶箱兩態）、`herb.png`（支線鏡草）、
  `helmet.png`（支線阿吉的頭盔）：程序化像素繪製（自製，build_cq2.py 內以 PIL 繪，無授權限制；
  同 barrel/crate/lamp 等程序繪 props）。
- `assets/ui/joybase/joyknob/btn_a/btn_menu/btn_back/pad_*/btn_s*`（觸控虛擬搖桿與按鈕）：
  程序化繪製（自製，build_cq2.py 內以 PIL 繪；力/敏/智 字用系統字體 STHeiti 烘入）。
- 地牢地板圖磚（gravel 遇敵/cavedark，art_v2.py toroidal wrap_dither 無縫重繪）：自製像素，無授權限制。
- **地牢主地板（rockfloor/cavefloor）與氛圍裝飾**（骷髏/顱堆/骨散/蜘蛛網/裂縫 `assets/props/dun_*.png`）：[**[LPC] Dungeon Elements**](https://opengameart.org/content/lpc-dungeon-elements)（`dungeonex.png` 的 cobblestone 與道具）—— CC-BY 4.0/3.0 / GPL / OGA-BY 3.0 —— Sharm（graphic artist）＋貢獻者。cobblestone 經 art_v2.py 去飽和套礦坑/洞穴灰階；原表存 `tools/lpc-dungeon/`。
## 敵人戰鬥圖（全部 LPC 重製，2026-07-12；取代原 16px 商店圖，來源 `assets/battle/lpc_src/`）

**人形怪**（哥布林/獸人/哥布林頭目/骷髏/死靈術士/食人魔）：LPC 角色產生器圖層合成（`art_v8_foes.py`：body＋怪物頭＋衣物染色）。授權 **CC-BY-SA 3.0 / GPL 3.0**（同主角，LPC 貢獻者群）。

**非人形怪**（OpenGameArt LPC 相容生物包，`art_v9_creatures.py` 裁切；原表存 `tools/lpc-creatures/`）：
- 綠黏史萊姆 / 巨牙蟲 / 礦坑飛魔 / 異變的魔影：[**[LPC] Monsters**](https://opengameart.org/content/lpc-monsters)（slime / big_worm / bat / ghost）—— **CC-BY-SA 3.0 / GPL 3.0** —— Charles Sanchez (CharlesGabriel)、bagzie、bluecarrot16。
- 暗影小魔：[**[LPC] Imp 2**](https://opengameart.org/content/lpc-imp-2) —— CC-BY 4.0/3.0 / GPL / OGA-BY 3.0 —— Stephen "Redshrike" Challener（graphic artist）＋ William.Thompsonj（contributor）。
- 洞熊／狂暴洞熊：[**[LPC] bears, deer, lions and more**](https://opengameart.org/content/lpc-bears-deer-lions-and-more)（grizzly bear）—— **CC-BY 4.0** —— tapatilorenzo（部分衍生自 Sevarihk）。
- 野狼（取代先前的熊 recolor 佔位）：[**[LPC] Wolf Animation**](https://opengameart.org/content/lpc-wolf-animation) —— CC-BY 4.0/3.0 / GPL / OGA-BY 3.0 —— Stephen "Redshrike" Challener ＋ William.Thompsonj。
- 掠翅鳥：[**[LPC] Birds**](https://opengameart.org/content/lpc-birds)（eagle）—— CC-BY 4.0/3.0 / CC-BY-SA / GPL / OGA-BY —— bluecarrot16（castelonia 委製）。
- **礦山兩幀戰鬥圖（2026-07-19）**：`foe_wogol_*` 由既有 LPC 素材裁切後製成兩幀呼吸，原授權沿用本節對應條目；`foe_skeleton_*`、`foe_orc_*`、`foe_bear_*` 為 OpenAI 圖片生成候選經 John 驗收後，以洋紅鍵去背、最近鄰縮放為右向戰鬥圖（提示詞作者 John／協作 Agent）。原始兩幀皆保存於 `assets-source/role/enemies/<enemy_id>/`。
- **東之森兩幀戰鬥圖（2026-07-19）**：`foe_bird_*`、`foe_gslime_*`、`foe_goblin_*`、`foe_worm_*`、`foe_wolf_*`、`foe_maskedorc_*` 為 OpenAI 圖片生成候選經 John 驗收後，以洋紅鍵去背、最近鄰縮放產出；各自採對應的拍翅、壓縮、重心、身節或待機動作（提示詞作者 John／協作 Agent）。原始兩幀保存於 `assets-source/role/enemies/<enemy_id>/`。
- **東之森深處兩幀戰鬥圖（2026-07-19）**：`foe_goblin_shaman_*`、`foe_goblin_tamer_*`、`foe_wild_hare_*`、`foe_horn_hare_*`、`foe_thorn_boar_*`、`foe_fungus_owl_*`、`foe_rotwood_beetle_*` 為 OpenAI 圖片生成候選經 John 驗收後，以洋紅鍵去背、共用錨點正規化為兩幀右向戰鬥圖（提示詞作者 John／協作 Agent）。`wild_hare` 為 `horn_hare` 的共用基底，後者僅增加一支短角；原始兩幀保存於 `assets-source/role/enemies/<enemy_id>/`。
- **礦山魔物設定集圖（2026-07-19）**：`wogol`、`skeleton`、`orc`、`wolf`、`bear` 各有 `portrait_<enemy_id>.png`（透明背景設定集全身立繪），均由 OpenAI 內建 imagegen 生成、經 John 驗收後存於 `assets-source/role/enemies/<enemy_id>/`（提示詞作者 John／協作 Agent）。
- **全敵人公會懸賞黑墨圖（2026-07-19）**：`goblin_shaman`、`goblin_tamer`、`goblin`、`goblin_chief`、`wild_hare`、`horn_hare`、`thorn_boar`、`fungus_owl`、`rotwood_beetle`、`bird`、`gslime`、`worm`、`wolf`、`bear`、`bear_dire`、`wogol`、`skeleton`、`orc`、`chort`、`necro`、`ogre`、`shadow_demon` 各有 `bounty_<enemy_id>.png`（透明背景、簡易單色黑墨圖案）。均由 OpenAI 內建 imagegen 生成、經 John 批次驗收後存於 `assets-source/role/enemies/<enemy_id>/`（提示詞作者 John／協作 Agent）；羊皮紙僅為驗收預覽底，不包含在正式 `bounty_*` 圖檔；目前尚未被 Godot runtime 引用。
- **LPC 怪物試作（尚未納入正式遭遇表）**：`foe_briar_bloom_*`（荊棘食人花）與 `foe_crystal_bee_*`（晶蜂）裁自 [**[LPC] Monsters**](https://opengameart.org/content/lpc-monsters)—— **CC-BY-SA 3.0 / GPL 3.0**，Charles Sanchez（CharlesGabriel）、bagzie、bluecarrot16；`foe_giant_rat_*`（礦坑巨鼠）裁自 [**[LPC] bears, deer, lions and more**](https://opengameart.org/content/lpc-bears-deer-lions-and-more)—— **CC-BY 4.0**，tapatilorenzo／Sevarihk。原始 spritesheet 備份於 `assets/battle/lpc_preview_source/`。
- `assets/ui/title_layers/title_bg.png`、`title_heroes.png`（模組化標題畫面既有圖層）：AI 生成（OpenAI Imagen，提示詞作者 John/協作 Agent，
  2026-07-17，依 /gen-art 的 title 構圖規格生成）。背景與男女主角剪影皆為獨立 PNG；透明圖層由洋紅色鍵去背。
- `assets/ui/title_layers/title_crystal.png`、`title_backplate.png`（新版水晶徽記／半透明符文背板）：OpenAI 內建 imagegen 生成，
  經 John 於 2026-07-20 驗收；提示詞作者 John／協作 Agent，洋紅色鍵去背。`title_zh.png` 與
  `title_en.png` 為協作 Agent 以系統字體合成的透明文字圖層，內容為「水晶傳說：路德篇」與
  「Tale of Crystal: The Legend of Ludo」，無外部素材授權需求。
  標題選單描邊字 `t_start/t_cont/t_restart.png` 亦為 PIL 系統字體烘製（自製）。
  ※ 遊戲定名：水晶傳說：路德篇 Tale of Crystal: The Legend of Ludo（主標 水晶傳說／Tale of Crystal ＋ 副標 路德篇／The Legend of Ludo）；曾誤植「水晶奇譚」「水晶戰記」，已更正。
  專案資料夾 crystal-quest 維持為代號。
