# LPC 角色行走圖／戰鬥圖製作流程（可復用）

- 最後更新: 2026-07-18
- 狀態: 定案（路德 `ludo` ＝首個完整案例，可當範本）
- 適用: 主角／隊友的 **overworld 走路圖** ＋ **戰鬥身體圖**（idle／揮劍／突刺／詠唱）。
  角色**立繪**（a 頭像／b 半身／c 全身）是另一條線，見 [角色立繪產圖規格.md](角色立繪產圖規格.md)。
- 工具: **Universal LPC Spritesheet Generator**（`sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator`）
  ——它是**圖層組裝器，不是把立繪轉成像素的轉換器**：只能挑現成 LPC 圖層拼出「接近」角色（LPC 像素風、非立繪還原）。
  這正是走路圖該用的工具（穩、四方向一致、能動）；AI 目前產不出穩定的四方向 walk cycle。

> Claude 端內建瀏覽器會擋這個 host，所以**產生器由 John 操作**、Claude 負責配方＋切圖接線。
> 授權：LPC 圖層＝**CC-BY-SA 3.0／GPL 3.0**（必須署名，產生器的 Credits(TXT) 會列全部作者）。

---

## 四步流程

### 1️⃣ Claude 依立繪給「LPC 配方」（設定建議）
Claude 讀該角色立繪／`docs/story/角色設定.md` 外觀 → 給對應的 LPC 圖層清單與顏色。以路德為例：
- Body: teen／膚色 light｜Hair: Messy2 (chestnut)｜Eyes: brown
- Torso: Cardigan(white) ＋ Leather 皮甲｜Legs: Cuffed Pants(leather)｜Feet: Leather boots｜Arms: Bracers
- Cape: Solid **red**（強特徵，一定加）｜Weapon: Arming Sword
- 同時決定該角色武器的 `weapon_type`（sword／dagger／claw／staff）→ 決定普攻的動畫＋音效。

**產出方式（2026-07-18 起改用網址，取代文字清單）**：直接組**產生器網址**，John 貼上瀏覽器即載入＋視覺檢查、免手動勾選。用 `liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/`，格式 `#類別=選項_顏色&…`（值＝顯示名空白換 `_`、`(顏色)`→`_顏色`；例 `Messy2 (chestnut)`→`Messy2_chestnut`、`Solid (red)`→`Solid_red`）。類別：`sex/head/expression/shadow/eyebrows/body/hair/shoulders/armour/legs/shoes/clothes/bracers/cape/weapon…`。**ludo 範本網址**：
`…/#sex=teen&head=Human_Male_light&expression=Neutral_light&shadow=Shadow_brown&eyebrows=Thick_Eyebrows_orange&body=Body_Color_light&hair=Messy2_chestnut&shoulders=Pauldrons_walnut&armour=Leather_leather&legs=Cuffed_Pants_leather&shoes=Basic_Boots_leather&clothes=Cardigan_white&bracers=Bracers_bronze&cape=Solid_red&weapon=Arming_Sword_steel`
⚠️ 猜錯/不存在的 option 名或顏色會被**忽略**（那層不載入）→ John 貼上一眼看出缺哪層、回報後修（正好配合「貼上再檢查」的迭代）。

> 誠實預期：拼出來「認得出是誰」，但披風金滾邊／精緻臉／琥珀眼 LPC 沒有 → 像素近似，非立繪還原。

### 2️⃣ John 匯出下載（**有武器＋無武器兩版**）

**⚠️ 先勾對「動畫集」再挑圖層**（重要，避免缺衣服）：不是每個圖層都支援每個動畫，缺支援的動畫會掉那層（皮甲/披風）。遊戲**實際用到的 5 個動畫**：**Walk**（走路）／**Idle**（戰鬥待機）／**Slash**（劍普攻·str技）／**Thrust**（dagger普攻·agi技）／**Spellcast**（staff普攻·int/補血技）。用產生器的 **Animation Filter** 只挑「同時支援這 5 個」的圖層來組角色，就不會再發生某動作缺衣服（2026-07-18 踩過：`Combat Idle` 缺皮甲/披風→戰鬥待機改用 `Idle`）。
- `Combat Idle`：可選（更好的持劍待機姿，但多一個支援限制）；要用再另外勾。
- `Run`／`Hurt`：目前沒用到，日後加 overworld 衝刺/戰鬥受擊再勾。勾越多＝可選圖層越少。

在產生器照配方＋上述動畫集勾好，下載：
- **「ZIP: Split by animation」**（要 `standard/` 的 `walk`、`combat`，以及 `custom/` 的 `slash_128`）
- **「Credits (TXT)」**（LPC 署名，必留）
- **「Export to Clipboard (JSON)」**（配方存檔，可 Import 回產生器微調/重出）
- **兩版**：**無拔劍版**（overworld 走路，走鎮上不舉劍）＋**有劍版**（戰鬥用，含拔劍/劍弧）。

> ⚠️ 雷：產生器的資料夾名可能**標反**（路德 `without_sword` 其實含劍、`with_sword` 反而無劍）——
> **以各自 `character.json` 有無 `Arming Sword` 為準**，別信資料夾名。檔案放 `assets-source/role/<id>/`。

**精簡交付（其實不用整包 ZIP）**：切圖只需**這 5 張透明動畫整張圖**（原始匯出、frame 網格、勿裁改）：
無劍版 `walk.png`；有劍版 `idle.png`、`custom/slash_128.png`（oversized，揮劍靠它）、`thrust.png`、`spellcast.png`。4 張戰鬥圖要一起給（要一起算腳底對齊框）。`credits.txt`（更新授權）／`character.json`（存配方）選給、切圖用不到。

### 3️⃣ Claude 接進專案＋驗證移動/戰鬥

**走路圖**（無劍版 `walk.png`）：832×256 ＝ 13欄×4列、cell 64；只前 **9 欄**有內容（後 4 欄空白 padding）。
列序 **row0=Up／1=Left／2=Down／3=Right**；**col0＝站立(=Idle 用)、col1–8＝走路**。切前 9 欄 →
`godot-project/assets/char/<id>_<Dir>_0..8.png`（覆蓋）→ `--import` → **進 Town/world 場景走一走驗證**
（painted `ef_*` 場景玩家用靜態圖、看不到走路動畫）。對映剛好吻合 `world_scene._build_char_frames`（frame0=Idle、1-8=Walk）。

**戰鬥圖**（有劍版）：
- idle ＝ **`idle.png`** 左列(row1) 2 幀 → `hero_<id>_f0..3`（2 幀對映成 4）。**⚠️ 不要用 `combat.png`**——LPC 的 `combat` 動畫**缺皮甲/披風等圖層的對應幀**，切出來角色會只剩內衣（2026-07-18 踩過：ludo idle 一度沒披風沒皮甲）。要換其他動畫當來源前，先用紅披風/服裝像素檢查該動畫圖層是否完整。**例外：ludo、marin 自 2026-07-20 起改用經驗收的 AI 兩格 idle**（分別見 `assets-source/role/main/ludo/battle_idle/`、`assets-source/role/main/marin/battle_idle/`）並維持相同 `f0/f2`、`f1/f3` 對映；攻擊幀仍沿用 LPC。
- 揮劍 slash ＝ **oversized `custom/slash_128.png`**（**標準 64px slash 看不到劍**、劍弧在格外；oversized 才有完整弧）
- 突刺 thrust ＝ `standard/thrust.png` 左列｜詠唱 spellcast ＝ `standard/spellcast.png` 左列
- 全部用「**偵測腳底 → 放同一畫布腳底對齊 → 裁切框以身體置中、含劍弧 → 放大 ×4**」，輸出
  `hero_<id>_{f,slash,thrust,spellcast}_*`；更新 `battle_state_machine.gd` 的 `HERO_RATIO`/`hero_dims`
  （路德＝1.77，含劍弧的寬幅、角色高度不變）→ `--import` → **進戰鬥用該角色普攻/技能驗證**。
- 動畫由資料決定：普攻依 **weapon_type**（sword→slash、dagger→thrust、claw→slash、staff→spellcast）；
  技能依 **sk.attr**（int→spellcast、agi→thrust、str→slash）。攻擊時角色移到 `ATTACK_POS` 出場位、
  命中瞬間（`IMPACT_FRAC`）播音效。
- 驗證：`--import`（exit 0，**別中途 timeout 砍**）＋ smoke（`-s res://tests/smoke_test.gd`，印 `SMOKE PASS`）。
  單檔 `--check-only --script` 會**假報 `AudioManager not found`**（autoload 標準陷阱），以 smoke 為準。

### 4️⃣ 更新文件
- `CREDITS_素材授權.md`：該角色 LPC 圖層作者/授權寫進去（依 Credits.txt；完整逐層另存 `assets-source/role/<id>/<id>_lpc_credits.txt`）；配方存 `<id>_lpc_recipe.json`。
- `docs/story/角色設定.md`：該角色美術狀態。
- 本檔／memory `lpc-walk-generator` 若流程有變一起改。
- 設定集 codex：push 後由 GitHub Actions 自動重建發佈到 GitHub Pages（不需手動重發）。

---

## 範本：路德 ludo（首例，2026-07-18）
- 來源：`assets-source/role/main/ludo/ludo_lpc/`（`with_sword`＝無劍乾淨、`without_sword`＝含劍，**名字反**）＋
  `ludo_lpc_recipe.json`／`ludo_lpc_credits.txt`。
- 走路圖：`assets/char/ludo_<Dir>_0..8.png`（無劍乾淨版）。
- 戰鬥圖：`assets/battle/hero_ludo_f0..3`（AI 兩格 idle，f0/f2、f1/f3 交替）＋ `hero_ludo_{slash,thrust,spellcast}_*`（LPC 有劍版；slash 用 oversized）。

## 現況／待辦
- **只有 ludo 有完整 LPC 攻擊幀**；marin/alan 要有攻擊動畫，得比照本流程各出一份 LPC 匯出包
  （在那之前戰鬥沿用「踏步滑步」fallback、音效照常同步）。
- **爪(claw)** 目前無專屬動畫幀（fallback slash）也無專屬音效（共用 `att_blade`）；要獨立再補。
- **攻擊音效資料化**：武器 `weapon_type`／技能 `sfx`／敵我方決定音效（Pixabay 音效，見 `CREDITS_素材授權.md`
  與 `battle_state_machine.gd` 的 `WTYPE_SFX`）。
