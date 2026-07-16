# 水晶戰記 開發指南（給協作 Agent）

> 環境與建置命令見根目錄 `CLAUDE.md`；本文件講專案內部架構。
> 玩家視角說明見 `README_遊戲說明.md`；劇情設定見 `DESIGN_設計文件.md`。

## 檔案結構

```
crystal-quest/
├── game.json            # 產物：不要手改，一律由 build_cq2.py 生成
├── CONTENT.json         # ★ 資料層：隊伍/衍生公式參數/裝備/技能/道具/敵人/遭遇/節奏(pacing)/角色故事
├── DESIGN_設計文件.md    # John 的敘事設計輸入（世界觀/章節/角色/NPC 台詞）
├── ART_PROMPTS.md       # 立繪等生成提示詞紀錄
├── CREDITS_素材授權.md   # 素材授權標註（動素材必更新）
├── design/faces/        # John/Gemini 產的立繪橫幅原圖（2816×1536 或 1344×768，人物偏左）
├── assets/
│   ├── map/             # atlas.png + 各場景 .tmj（build 生成）
│   ├── char/            # LPC 合成行走圖 36幀/人 + face_*.png 頭像
│   ├── battle/          # 戰鬥素材：hero_*_f0-3（含武器）、foe_<id>_<i>（多幀+描邊）、fx_*、src_foes/（商店原幀）
│   ├── props/ ui/ sfx/ bgm/
└── scripts/             # 全部建置腳本與 E2E（見下表）
```

## 腳本矩陣（誰產生什麼、何時要跑）

| 腳本 | 產出 | 何時跑 |
|------|------|--------|
| `build_cq2.py` | game.json、atlas、地圖 tmj、程序化 props/UI/FX/戰鬥背景、敵人描邊幀 | **每次改動後必跑**（也是唯一讀 CONTENT.json 的地方） |
| `art_v2.py` | 補繪圖磚（水/沙/岩地/碎石…）、bush/rock/well、佔位建築精修 | build 之後必跑（build 會重置 atlas） |
| `art_v3_lpc.py` | LPC 六棟建築、礦坑口、石筍 | art_v2 之後必跑 |
| `art_v6_chars.py` | 路德/瑪琳行走圖（LPC 圖層+染色） | 角色外觀變動時 |
| `art_v10_npcwalk.py` | 戶外遊走 NPC 完整走路圖（gray/guard 36 幀，LPC 圖層合成） | NPC 走動外觀變動時，**須在 build_cq2 之前跑**（持久化，平時免跑） |
| `art_v12_furniture.py` | 室內家具（f_*.png）＋房間外殼（int_room_wood/stone），程序繪 | 室內家具/房間變動時，**須在 build_cq2 之前跑**（持久化，平時免跑） |
| `art_v8_foes.py` | **人形**敵人戰鬥圖（LPC 產生器合成→`lpc_src/`） | 人形怪外觀變動時，**須在 build_cq2 之前跑**（lpc_src 持久化，平時免跑） |
| `art_v9_creatures.py` | **非人形**敵人戰鬥圖（OGA LPC 生物包裁切→`lpc_src/`；原表在 `tools/lpc-creatures/`） | 生物怪外觀變動時，同樣須在 build_cq2 之前跑 |
| `art_v5_battle.py` | 戰鬥大圖 hero_*_f0-3（**含武器圖層**）+ hero_dims.json | 角色或武器外觀變動時，跑完要**再跑一次 build_cq2.py**（讀 dims） |
| `art_v4_portraits.py` / `art_v7_faces.py` | 頭像：程序繪 / 從 design/faces 橫幅自動裁 144px | 立繪變動時 |
| `cq3_e2e.mjs` | 全流程 E2E（舊版鍵位，部份選單流程已過時） | 參考用 |

標準重建：`build_cq2.py → art_v2.py → art_v3_lpc.py`。內建連通性 assert 擋壞地圖。

## 引擎架構（三大塊 JsCode，全在 build_cq2.py 內嵌）

每個場景只有一個 JsCode 事件、**每幀重跑**；狀態必須掛在 `runtimeScene`（`rs.__v` 世界 / `rs.__b` 戰鬥），不能用閉包。

- **WORLD_JS**（Town/Forest/Forest2/Mine/Cave 共用，吃 `__CFG__` 場景參數）：
  對話/劇情佇列（DLG/CUTS 資料表，`when` 旗標分派如 `"ch1>=1"`、`gotRing==0`；
  共用比對器 `matchWhen(f,w)`＝`always`/`旗標==N`/`旗標>=N`，DLG/trigger/pickup 皆用它）、
  **triggers 支援 `when` 閘門**（如 `mine_truth` 綁 `ch2>=1`，序章 step0 不誤觸；msg 型 trigger 顯示後 break，可用優先序做互斥訊息如 Cave 落石）、
  **`CFG.pickups` 通用撿取原語**（走過矩形→設/加旗標（op set/inc＋val）＋選配加道具（item→invAdd）＋隱藏 prop，`showWhen` 閘門控可見與可撿；鏡草×3、阿吉頭盔即用此）、
  **地圖 boss/精英標記**（BossMark=ch1_boss/ch1==1、BearMark=ch2_bear/ch2==1；碰觸<80px 開戰、戰勝後旗標推進自動隱藏、戰敗/逃走可重試）、
  **存檔（Track G）**：`saveGame()`＝把 g_flags/party/eqInv/itemInv/gold/chests＋場景/座標寫 `localStorage["cq_save"]`；**自動存檔**呼叫點＝場景進場(init 末)/對話帶動作/pickup/寶箱/商店買賣（室內時存門口外座標避免卡牆）。Title「繼續冒險」讀檔→設 `g_result="resume"`＋g_returnX/Y→`replaceScene(存檔場景)`（進場出生點分支認得 "resume" 用 returnX/Y 定位）；「重新開始」清存檔。
  **觸控（Track B，虛擬搖桿）**：每幀先蒐集觸控→`st.tk`（touch-key 集合）；`keyHit()` 與 `hit` 都吃 `st.tk`，故**觸控＝合成鍵餵給既有鍵盤流程**（選單/商店/配點零改動）。UI 物件在 **"UI" 圖層**（螢幕座標、`im.getTouchX`+`insideObject` 直接命中）：JoyBase/JoyKnob(浮動搖桿)、BtnA(空白/OK)、BtnMenu(M)、PadU/D/L/R、BtnBack(Esc)、BtnS1/2/3(力/敏/智=Num1/2/3，僅角色能力頁顯示)。搖桿用 `b.simulateControl("Right"/…)` 驅動 TopDown。
  六分頁選單（角色/裝備/道具/地圖/稱號/系統；MRow 20 列支援自訂 x/y、血條 BarBg/BarFill、RowHi 高亮）、
  碰撞（BLK 字串）、高草遇敵（ENC 字串+**走行距離累積**：踩 tgrass/gravel 時累積移動距離，達 `encNext=600+rand*800`px 觸發、每場戰後重抽；grace 1.2s；rs.__v init 那行調頻率）、隊伍跟隨（trail）、出口/觸發區。
- **BATTLE_JS**：**ATB 制**（`u.atb` 蓄力 `(10+spd)*1.05/s`，只在 `state==="run"` 蓄=等待模式）。
  指令：攻/技/道/**防禦**(減半)/逃。陣型 frontRow/backRow（big 後排）+Boss 頂部血條。
  **自動戰鬥**：`g_autoBattle`(0/1，A 鍵或 BtnAuto 切換、win/lose 時鎖定)＝開啟後 `openCmd` 走 `autoAttack()`（對第一個存活敵人普攻、不開選單）；想用技能/道具/治療就切回手動。
  **敵人技能**：enemy 加 `foeSkills:[{name,target:"one"|"all",mult}]`→ foeAct 40% 機率使出（傷害＝phys×mult；single 可被閃避）；與 `healer`/`allAttack` 並存。Boss 名條只顯示「☠ 名稱」不露數字（血條仍在）。
  傷害公式：普攻 `patk*1.8-def`（防禦中×0.5、閃避=雙方敏捷差、會心×1.5）；
  技能 `(skBase*mult+flat)*技能等級倍率-防×0.6`，skBase=物攻（int 系=魔攻）。
  EXP=原始值×EXPSCALE（build 從 CONTENT.pacing 換算——`battles`=農怪場數係數）。
- **衍生屬性 derive()**：WORLD 與 BATTLE **各有一份，改公式要同步兩處**。參數集中 `CONTENT.derived`。

## 跨場景狀態（全域變數，全部 JSON 字串）

`g_party`（成員含 hp/mp/lv/exp/pts/spts/sk/eq）、`g_flags`（劇情旗標：序章 step、reg、第一章 ch1、
**第二章 ch2**(0未接/1調查中/2已敗洞熊/3已回報)、支線 relic/herb/mira2、gotXxx、c_* 過場一次性旗標）、
`g_eqInv`（裝備袋 id 陣列）、`g_itemInv`（背包 {id:數量}，用 invAll/invGet/invAdd/invUse 存取）、`g_gold`、
`g_encounter`/`g_returnScene`/`g_returnX/Y`/`g_result`(win/lose/flee/story/resume)/`g_spawn`/`g_chests`/`g_autoBattle`(自動戰鬥 0/1，存檔內)。
進度不持久化：Title 開新局會全部重設。

## 測試（puppeteer E2E）

1. `preview_scene`（**不帶 sceneName**）+ `keepExport:true` 拿匯出目錄。
2. Node22 跑腳本（範本：session scratchpad 的 `battle_smoke2.mjs`/`menu_smoke.mjs` 模式）：本地 http server + puppeteer，按鍵帶 `delay:70+`。
3. **除錯掛勾**：`window.__W`（世界：scene/座標/旗標/選單狀態/隊伍摘要）、`window.__B`（戰鬥：state/foes/heroes/sel）、
   **`window.__forceEnc="ch1_boss"`**（在任一世界場景 evaluate 後直接開該遭遇戰——測戰鬥不用跑圖）。
4. 戰鬥自動打法：等 `__B.state==="menu"` → Enter（攻擊）→ `state==="target"` → Enter；技能=Right+Enter；卡 skill/item 態就 Escape。

## 常見改動的入口

| 想改什麼 | 改哪裡 |
|----------|--------|
| 數值/裝備/技能/敵人/遭遇/難度節奏 | `CONTENT.json`（pacing.battles=練級所需場數）→ 重跑 build |
| NPC 台詞/劇情 | build_cq2.py 的 `DLG`/`CUTS` 資料表 |
| 地圖佈局 | build_cq2.py 第 4 節（MapB/carve_maze/make_forest）；**裝飾 prop 不要傳 foot**——`foot=(0,0,0,0)` 會把該格變牆，樹狀迷宮會斷路。城鎮建築尺寸/位置＝`BLDG_LAYOUT`；樹一律避開 `_bld_clear`（各建築精靈實際覆蓋範圍）不會被遮成一角/擋門口 |
| 室內 | 手繪大圖 `intc_<key>` 當背景（John 定案不用物件式；`_clean_ext` 去洋紅）。每棟設定在 `INT_DRAWN`＋`INT_DRAWN_DEFAULT`（座標皆為背景圖 W/H 比例）。**兩種模式**：① `mode:"menu"`（★公會，立繪＋選單）＝手繪背景＋`IntArt` 大型立繪前景（`portrait_<id>.png`，art_v13 由 design/faces 亮度鍵+羽化裁出）＋指令選單（IntCmd0/1＝交談/離開），不走動、直接互動；② 預設 walk（`room`/`furn` 隱形碰撞矩形、可走動）。切模式改 `INT_DRAWN[key].mode`。舊物件式（int_room+FURN_*）已停用。可用離線疊圖預覽快速調 fraction。|
| 選單/戰鬥 UI | WORLD_JS 選單段 / BATTLE_JS refresh()；UI tokens：選單 accent 青 #AADCEB、戰鬥 accent 金（Design 定案） |
| 新立繪/背景圖 | `/gen-art` skill（根目錄 `.claude/skills/gen-art/`） |
| 新場景 | build_world_scene + cfg + `layouts` 清單 + **resources 的 tmj 註冊清單**（漏了會 Tilemap 載入錯誤） |

## 設計端（claude.ai/design「Crystal Quest UI」）

`水晶戰記選單原型.html`／`水晶戰記戰鬥原型.html` 是 John 的規格來源；其 Tweaks JSON（EDITMODE 區塊）= 定案參數。
原型中**尚未實作**的系統：商店、技能樹（前置/被動）、守護/降攻等技能機制——列為第二章開發項。
