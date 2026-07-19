# 規格：衍生屬性與戰鬥公式

- Spec 版本: v4.0
- 對應 GDevelop 原始碼快照: `scripts/build_cq2.py`（WORLD 版 `derive()` L1326-1345；BATTLE 版 `derive()`
  L2641-2661 為同一份公式的重複實作——**已知技術債，DEV_開發指南.md L63 有提及「改公式要同步兩處」**）
- 狀態: 定案（F-1~F-9 原始抄錄自現行程式碼；**F-10/F-11 為 Godot 端刻意新增；v4.0 屬性系統擴充進一步刻意偏離 GDevelop，見版本紀錄**）
- 用途: MOD-F（衍生屬性/戰鬥公式）、MOD-E（ATB 戰鬥系統）實作依據；屬性系統擴充見 [TASKS/14](../TASKS/14_屬性系統擴充.md)、`docs/design/屬性戰鬥設計.md`

## 版本紀錄

- **v4.0（2026-07-19，屬性系統擴充；John 指示，see TASKS/14）**：**破壞性變動——新增第四主屬性 `luck`(幸運)、
  裝備可加主屬性、戰鬥拆「命中/爆擊/傷害」三段、新增命中/抗爆/爆傷三個戰鬥數值**。
  1. **F-1 改寫**：裝備 `stats` 的 `str/agi/int/luck/spd` 先疊進「有效屬性」再算衍生（舊版裝備加主屬性不生效）；
     `attrs` 由 `{str,agi,int}` 擴為 `{str,agi,int,luck}`；新增衍生輸出 `accV`(命中)/`critresV`(抗爆)/`critdmg`(爆傷)/`luckV`；
     `critV` 納入 luck、`dodgeV` 納入 luck。新增係數 `critPerLuck=0.1`、`dodgePerLuck=0.05`、`accPerAgi=1.5`、
     `critresPerLuck=0.1`、`critDmgBase=1.4`、`critCap=100`、`dropPerLuck=0.1`；`critPerAgi` 0.15→**0.2**。
  2. **F-3 改寫（爆擊＋抗爆＋爆傷）**：會心改「有效會心率 = clamp(會心攻 − 抗爆守, 0, critCap)」；爆擊傷害倍率由
     寫死的 **1.5** 改為攻方 `critdmg`（基礎 `critDmgBase=1.4` + 裝備 `critdmg`）——**全域爆傷小幅下修、改由裝備養成**。
     敵方會心 = `critBase + luck×critPerLuck`（一般怪 luck=0＝沿用基礎 6.25%）。
  3. **F-4 改寫（命中/閃避成對）**：命中值 `acc` 改用獨立係數 `accPerAgi`（與 `dodgePerAgi` 同值 1.5，
     **agi 相等時淨閃避與 v3.0 完全相同、零重平衡震盪**）；`dodge` 納入 luck；新增命中率 `hit% = 100 − 淨閃避`。
  4. **F-10 掉寶納入 luck**：最終掉率 `+= 全隊最高 luckV × dropPerLuck / 100`（含裝備幸運）。
  5. **平衡影響**：agi 會心 0.15→0.2（agi 每點多 +0.05% 會心，全體會心微升，低敏角色 <0.5%、alan 約 +1.2%）；
     爆傷 1.5→1.4（爆擊傷害 −約 6.7%，可用裝備 critdmg 補回）；luck 起始值低（隊員 2/3/8、四 boss 3~5），
     其餘敵人 luck=0 行為不變。**閃避手感未變**（見 F-4）。伴隨資料在 `.tres`（3 隊員 base 加 luck、
     4 boss 加 luck、3 件劇情裝備轉正 str/agi/luck）。
- **v3.0（2026-07-19，遭遇系統重製；John 指示）**：**破壞性變動——`EncounterDef.formations` 資料結構改變**。
  1. **新增 F-11 遭遇編組與抽選**：`formations` 由 `Array[Array[String]]`（固定編成）改為 `Array[Dictionary]`
     （帶 `weight` 權重與 `members` 數量範圍），支援同種怪複數、boss+隨從同組、加權抽組；新增戰場敵人上限
     `MAX_FOES = 5`（`battle_state_machine.FOE_SLOTS` 同步擴到 5 槽）。
  2. **F-9 EXP 平均改為加權期望**（隨 F-11，見 F-9 v3.0 註記）；member 全 `min=max` 且省略 weight 時與 v2.0 等價。
  3. **伴隨資料重排（值在 `.tres`）**：12 張 `encounters/*.tres` 重編權重/數量/隨從；15 隻 `enemies/*.tres`
     新增 `description` 圖鑑欄位（彙整見 `docs/design/魔物圖鑑.md`）。
- **v2.0（2026-07-15，遊玩回饋平衡調整；John 指示）**：**破壞性變動——非抄錄自 GDevelop，而是 Godot 端刻意偏離**。
  1. **新增 F-10 掉落公式**：`ItemDef` 新增 `rarity` 與 `base_drop_rate` 兩欄；`EnemyDef.drops[].rate` 語意由
     「絕對掉落機率」改為「加成倍率」，最終掉率 = `clamp(item.base_drop_rate × rate, 0, 1)`。
  2. **伴隨資料再平衡（值在 `.tres`，非本文件）**：一般怪 hp ×約1.7、Boss ×約1.3（`enemies/*.tres`）；
     `pacing.tres` 各地圖 entry/target 級距收斂（森林 1→2、森林2 2→3、礦坑 3→5、洞窟 5→7），透過 F-9
     EXPSCALE 自動使升級變緩；掉落率經 F-10 重算，一般素材淨掉率由 0.4~0.6 降到 0.20~0.30。
- **v1.1（2026-07-14，MOD-E 實作時發現並修正）**：
  1. **F-8 敵人技能**：v1.0 只有行為輪廓，本版回 `build_cq2.py foeAct()`（L3019-3068）逐行核對，補齊
     healer / foeSkills(40%) / allAttack(30%) / 一般攻擊的完整優先序與精確算式（見下方 F-8）。
  2. **F-7 修正一處抄錄錯誤**：v1.0 原文寫「敵人初始化時 `m.atb = random()*40`（L2852），英雄未特別提及
     初值」，經回原始碼核對**寫反了**——L2852 `m.atb=Math.random()*40` 實際是在**英雄**建構迴圈內
     （L2850-2854），敵人的初始 ATB 是 L2862（`b.foes.push({...atb:Math.random()*30})`）**單獨一個
     inline 物件欄位**，即敵人是 `random()*30`。已更正，見下方 F-7。

> Godot 端**只需要實作一份** `derive()` 等價物（不要複製 GDevelop 的兩份技術債），這是 MOD-F 相對於原始碼的
> 唯一刻意偏離之處，其餘公式原樣照搬。

## F-1　衍生屬性 `derive(m)`（L1326 / L2641，兩處邏輯相同；v4.0 屬性系統擴充改寫）

輸入 `m`：`{id, lv, attrs:{str,agi,int,luck}, mainAttr, eq?, hp?, mp?, sk?, spts?}`，`CONTENT.derived` 提供係數
表 `d`。**v4.0：主屬性先疊裝備加成成「有效屬性」再算衍生**（舊版只讀角色 base，裝備放 `str/agi/int/luck`
不生效——本次修正的核心落差）：

```
# 有效主屬性 = 角色 base + 裝備（eqStat 加總）
STR = attrs.str + eqStat(m,"str")
AGI = attrs.agi + eqStat(m,"agi")
INT = attrs.int + eqStat(m,"int")
LUK = attrs.luck + eqStat(m,"luck")
MAIN = attrs[mainAttr] + eqStat(m,mainAttr)

maxhp    = d.hpBase + STR * d.hpPerStr + eqStat(m,"hp")
maxmp    = d.mpBase + INT * d.mpPerInt + eqStat(m,"mp")
patk     = d.weaponAtk + MAIN * 2 + eqStat(m,"patk")
matk     = round(INT * d.matkPerInt) + eqStat(m,"matk")
pdef     = STR + eqStat(m,"pdef")
mdef     = round(INT * d.mdefPerInt) + eqStat(m,"mdef")
dodgeV   = round(AGI * d.dodgePerAgi + LUK * d.dodgePerLuck) + eqStat(m,"dodge")   # v4.0 納入 luck
critV    = round((d.critBase + AGI * d.critPerAgi + LUK * d.critPerLuck + eqStat(m,"crit")) * 10)/10   # 取一位小數（WORLD 版）；v4.0 納入 luck
accV     = round(AGI * d.accPerAgi) + eqStat(m,"acc")           # v4.0 命中值（F-4）
critresV = round(LUK * d.critresPerLuck * 10)/10 + eqStat(m,"critres")   # v4.0 抗爆（F-3）
critdmg  = d.critDmgBase + eqStat(m,"critdmg")                  # v4.0 爆擊傷害倍率（F-3），取代寫死的 1.5
luckV    = LUK                                                  # 有效幸運（供 F-10 掉寶、UI 顯示）
spd      = AGI + eqStat(m,"spd")                                # v4.0：裝備也能直接加行動力
```

- **係數表 `d`（`CONTENT.derived` / `derived.tres`）v4.0 值**：`critPerAgi=0.2`、`critPerLuck=0.1`、
  `dodgePerAgi=1.5`、`dodgePerLuck=0.05`、`accPerAgi=1.5`、`critresPerLuck=0.1`、`critDmgBase=1.4`、
  `critCap=100`、`dropPerLuck=0.1`、`dodgeCap=30`、`critBase=6.25`（其餘 hp/mp/exp 等見 `derived.tres`）。
- `eqStat(m,k)`：把 `m.eq` 裡每個部位對應的 `CONTENT.equipment[eqId][k]` 加總（沒有該屬性視為 0）。
- 若 `m.eq === undefined`：從 `CONTENT.party` 找同 id 的模板套用 `startEq`（初始裝備），之後才進入上面公式。
- `hp`/`mp` 初值：未定義或超過上限時 clamp 到 `maxhp`/`maxmp`（不會因裝備變動被治療到滿血以外）。
- `sk`（已學技能表）：若未定義，依 `CONTENT.skills` 篩出 `class===m.cls && lv>=unlockLv` 的技能，初值皆為
  Lv1（`sk[id]=1`）。
- `spts`（技能點）：未定義則設 0。

## F-2　升級所需經驗 `expNeed(lv)`（L1325 / L2662）

```
expNeed(lv) = d.expBase + round(d.expCoef * lv^d.expPow)
```

## F-3　普攻傷害 `phys(att, defn)`（L2945-2953；v4.0 加入抗爆與可變爆傷）

```
atk = att.attrs ? att.patk : att.atk      # 我方走 patk，敵方走敵人資料表的 atk
df  = defn.attrs ? defn.pdef : defn.def
base = atk*1.8 - df; base = max(1, base)
if defn.defending: base *= 0.5             # 防禦指令減傷 50%
critCh% = critChance(att, defn)            # v4.0：有效會心率（含抗爆），見下
crit = random()*100 < critCh%
cdm = critMult(att)                         # v4.0：爆擊傷害倍率（角色 critdmg=1.4+裝備；敵人 critDmgBase=1.4）
final = max(1, round(base * (0.85~1.00 隨機, 均勻分布) * (crit ? cdm : 1)))
```

**有效會心率 `critChance(att, defn)`（%，0~critCap）＝ 會心攻 − 抗爆守（v4.0 新增抗爆）：**
```
critAtt = att.attrs  ? att.critV     : d.critBase + att.luck * d.critPerLuck    # 敵人無 critV，用 base+luck（luck=0＝基礎 6.25%）
critRes = defn.attrs ? defn.critresV : defn.luck * d.critresPerLuck             # 敵人抗爆由 luck 現算
critCh% = clamp(critAtt - critRes, 0, d.critCap)
```
**爆擊傷害倍率 `critMult(att)`：** 角色＝`att.critdmg`（derive 算好＝`critDmgBase + eqStat("critdmg")`）；敵人＝`d.critDmgBase`。
取代 v3.0 以前寫死的 `1.5`——爆傷改成可由裝備養成的維度。

## F-4　命中/閃避判定 `dodge(att, defn)`（L2938-2944；v4.0 命中值改用獨立係數、閃避納 luck）

```
dv = defn.attrs ? defn.dodgeV : defn.spd * d.dodgePerAgi + defn.luck * d.dodgePerLuck   # v4.0 敵人閃避納 luck
av = att.attrs  ? att.accV    : att.spd * d.accPerAgi                                    # v4.0 命中值 acc（角色用 derive 的 accV）
淨閃避% = clamp(dv - av, 0, d.dodgeCap)
命中率 hit% = 100 - 淨閃避%
是否閃避 = random()*100 < 淨閃避%     （＝ 是否命中 = random()*100 < hit%）
```

- **v4.0 關鍵：`accPerAgi = dodgePerAgi`（皆 1.5）**，所以雙方 agi 相等、無裝備 acc/luck 時，淨閃避 =
  `1.5 × (defn.agi − att.agi)`，**與 v3.0 完全相同**——閃避手感不變，只是把「命中值」明式化成可被裝備
  `acc` 撐高的獨立維度、並讓 luck 微幅加閃避。要弱化/強化敏捷閃避，改 `dodgePerAgi`（連動）即可。
- 命中/閃避判定在**普攻**（`applyOne` 的 `pd.t==="atk"`）與**敵人具名單體技能**（F-8）才會呼叫；玩家技能傷害
  （`sk.kind==="damage"`）與全體技能 `applyAll` 刻意不判——Godot 端不要「順手」補上。`DamageCalc` 提供
  `hit_chance()`/`is_hit()`（命中視角）與 `dodge_chance()`/`is_dodge()`（閃避視角，互為補數），呼叫端沿用 `is_dodge`。

## F-5　技能傷害/治療

**技能威力倍率** `skPow(a, sk)`（L2669）：
```
slv = a.sk[sk.id] 或 1（技能等級）
skPow = 1 + d.skillPowerPerLv * (slv - 1)
```

**技能基礎值** `skBase(a, sk)`（L2670-2673）：
```
若 sk.attr === "int":
    a 是角色（有 attrs） → matk；a 是敵人 → round(a.atk * 0.8)
否則:
    a 是角色 → patk；a 是敵人 → a.atk
```

**技能防禦值** `skDef(t, sk)`（L2954-2957）：
```
若 sk.attr === "int":
    t 是角色 → mdef；t 是敵人 → round(t.def * 0.5)
否則:
    t 是角色 → pdef；t 是敵人 → t.def
```

**單體技能傷害**（`applyOne` L2975-2981，`applyAll` 對全體敵人邏輯相同 L3002-3017）：
```
dmg = max(1, round( ((skBase(a,sk)*sk.mult + sk.flat) * skPow(a,sk) - skDef(t,sk)*0.6)
                     * (0.85~1.00 隨機) ))
```
注意係數是 `skDef * 0.6`（普攻是全額 `df`，技能只吃六成防禦），這是刻意設計差異，不是筆誤。

**治療技能**（`sk.kind !== "damage"` 分支，L2982-2987）：
```
heal = round((skBase(a,sk)*sk.mult + sk.flat) * skPow(a,sk))
t.hp = min(t.maxhp, t.hp + heal)
```
治療同樣吃 `skBase`（int 系技能治療量跟 matk 掛鉤），沒有防禦修正。

## F-6　道具使用（`applyOne` 的 `pd.t==="item"` 分支，L2988-2997）

```
道具 meta 來自 CONTENT.items[id]，預設 {name:"藥水", kind:"heal", power:60}（找不到 id 時的 fallback，理論上不該發生）
kind === "mp"：mp = min(maxmp, mp + power)
其他（含 "heal"）：hp = min(maxhp, hp + power)
```
使用後扣庫存 `invUse(id)`（即 `invAdd(id, -1)`）。戰鬥可用道具僅限
`itemUsableInBattle` 判斷為真者：`meta.kind === "heal" || meta.kind === "mp"`（L2632）。

## F-7　ATB（Active Time Battle）蓄力（L2675, L2708-2721）

```
ATB_K = 1.05   # 全域速度倍率，Design Tweaks 定案值，不要當成可調參數隨意改
每幀（僅 b.state === "run" 時蓄力）：
    對存活單位 u： u.atb = min(100, (u.atb||0) + (10 + (u.attrs ? attrs.agi : u.spd)) * ATB_K * dt)
我方優先權：任一 hero.atb >= 100 → 開指令選單（openCmd），且同一幀只處理第一個達標的英雄
敵方：沒有英雄就緒時，任一 foe.atb >= 100 → 觸發 foeAct，同一幀只處理第一個
行動後：actor.atb = 0（L2838, L3020）
初始 ATB（`initB()`，L2842-2882）：**英雄** `m.atb = random()*40`（L2852，在英雄建構迴圈
`for(i<ps.length&&i<4)` 內，逐一設定）；**敵人** `atb: random()*30`（L2862，`b.foes.push({...})` 物件
字面量裡的一個欄位，逐一設定）。v1.0 這裡曾經寫反（敵人抄成 40、英雄抄成「無初值」），已於 v1.1 更正——
兩邊都有非零初值，不是「英雄預設 0 要等第一輪蓄滿」。
```

- 只有 `state === "run"` 時才蓄力，任何選單/演出（`menu`/`target`/`anim`/…）都暫停 ATB，等同「等待模式」，
  DEV 指南提到的「waitMode=true 由狀態機天然實現」在這裡對應：Godot 版狀態機只要複製「非 run 狀態不蓄力」
  這條規則即可，不需要額外維護一個 waitMode 旗標。

## F-8　敵人技能（`foeAct(a)`，build_cq2.py L3019-3068，MOD-E 逐行核對後補齊，v1.1）

`foeAct(a)` 在敵方單位 `a` 的 ATB 蓄滿時觸發（見 F-7）。整體流程是**依序 4 段機率/條件檢查，第一個
成立的分支執行後直接結束本回合**（不是把 healer/foeSkills/allAttack/一般攻擊揉成一次加權抽獎；是連續
的「若條件成立就做這個然後 return，否則往下一段檢查」）：

```
a.atb = 0   # 無條件，回合一開始就重置（L3020）
若 b.scripted：b.acted++

【第 1 段：healer（若 a.healer 為真）】
  low = b.foes 中「還活著 且 hp < maxhp*0.55 且 不是 a 自己」的敵方單位，依 b.foes 陣列原始順序（不是
        依血量排序，也不是隨機）
  若 low 非空：
      t = low[0]                       # 固定取第一個符合者
      heal = 20 + round(random()*10)   # 20~30（含端點，連續均勻分布後取整）
      t.hp = min(t.maxhp, t.hp + heal)
      結束本回合（finishFoe()）；不再往下檢查
  若 low 為空：不 return，繼續往下（healer 旗標這回合沒有可治的對象，退化成普通攻擊者）

【檢查存活英雄】
  alive = b.heroes 中還活著的
  若 alive 為空：呼叫 checkEnd() 後直接結束（不經過 finishFoe()/anim 演出）

【第 2 段：具名技能（若 a.foeSkills 非空陣列）】
  40% 機率（Math.random()<0.4）觸發：
      fsk = a.foeSkills 中隨機一個 {name, target: "all" | 其他（實務上是 "one"）, mult}
      若 fsk.target === "all"：
          對 alive 內「每一位」英雄，各自：
              r = phys(a, hero)                    # F-3 完整流程（含隨機 0.85~1.00、會心 1.5 倍）
              d = max(1, round(r.d * fsk.mult))
              hero.hp -= d
          不做 dodge 判定（跟 F-4 提到的 applyAll 同一原則：全體技能不判閃避）
          結束本回合
      否則（target 不是 "all"，實務上資料只會是 "one"）：
          t = alive 中隨機一位
          若 dodge(a, t) 成立（F-4 標準公式）：不造成傷害，顯示 MISS，結束本回合
          否則：
              r = phys(a, t)
              d = max(1, round(r.d * fsk.mult))    # 同一個 phys() 結果先乘 fsk.mult 再取整、下限 1
              t.hp -= d
          結束本回合
  40% 沒中：不 return，繼續往下

【第 3 段：allAttack（若 a.allAttack 為真）】
  30% 機率（Math.random()<0.3，只在第 2 段沒有觸發時才會檢查到這裡，兩段機率不是同時擲）觸發：
      對 alive 內每一位英雄，各自：r = phys(a, hero)；hero.hp -= r.d   # 注意：不乘任何 mult，就是原始
                                                                         # phys() 傷害，也不判 dodge
      結束本回合
  30% 沒中：不 return，繼續往下

【第 4 段：一般單體攻擊（fallback，前三段都沒有觸發或都不適用時）】
  t = alive 中隨機一位
  若 dodge(a, t) 成立：不造成傷害，顯示 MISS，結束本回合
  否則：r = phys(a, t)；t.hp -= r.d   # 不乘 mult，就是標準 F-3 phys() 結果
  結束本回合
```

重點澄清（避免實作時抄錯）：

- **healer / foeSkills / allAttack 三個旗標可以同時出現在同一隻敵人身上**（例如 `bear_dire` 同時有
  `allAttack:true` 且 `foeSkills` 非空——CONTENT.json 實際資料如此）。三段機率各自獨立判定、依序短路，
  不是「三選一」的單次加權抽獎。以 `bear_dire`（無 healer）為例：本回合触發具名技能機率＝40%；觸發
  allAttack 機率＝60%（第2段沒中）×30%＝18%；剩下的 42% 落回一般攻擊。
- **具名技能單體目標（"one"）會判定 dodge，具名技能全體目標（"all"）與 allAttack 都不判 dodge**——這跟
  F-4 記載的「技能傷害一律不判閃避」不完全一樣：具名技能的單體分支底層直接複用 `phys()`/`dodge()`
  （物理攻擊那一套），不是 F-5 的技能傷害流程，所以它**會**判 dodge；F-4 的「技能不判閃避」規則只適用於
  F-5（`skPow`/`skBase`/`skDef` 那條路徑，即玩家角色的技能與 `applyAll`）。
- **具名技能的傷害＝`phys(a, target)` 的結果（已含隨機 0.85~1.00、會心 1.5 倍）再乘 `fsk.mult`、四捨五入、
  下限 1**——不是拿 `atk*mult` 重新走一次獨立的傷害公式；`mult` 是套在 `phys()` 的最終輸出上，會心與
  隨機浮動已經算過一次，`mult` 純粹是二次縮放。
- **allAttack 沒有自己的倍率**：純粹是「對全體英雄各打一次標準 `phys()` 攻擊」，跟一般單體攻擊的傷害公式
  完全相同，只是目標從一位變全體，也不判 dodge。
- **healer 治療量 `20 + round(random()*10)` 與角色/敵人的任何屬性無關**（不是照 F-5 的 `skBase`/
  `skPow` 算，是寫死的常數公式），目標永遠是「陣列中第一個血量低於 55% 上限的隊友」，不是隨機也不是
  血量最低者優先。
- Boss（`big:true`）血條規則：頂部固定顯示「☠ 名稱」且不顯示數字（`FoeName`/`HpV` 一類的血量文字全都
  沒有搭配敵人血條），血條本身仍依 `hp/maxhp` 比例畫出（`refresh()` L3221-3229）；非 boss 的一般敵人也
  同樣沒有血量數字，只有名字（受擊或被選取時短暫顯示）＋小血條（L3211-3219）——這是 UI 呈現規則，數值
  歸屬 MOD-D，MOD-E 只需要保證 `hp`/`maxhp` 是正確算好的即可。

## F-9　EXP 縮放

```
EXP 實際獲得 = 敵人資料表原始值總和 × EXPSCALE[b.enc]（若 b.enc 不在 EXPSCALE 表內則不縮放，即係數視同 1）
最終取整：exp = Math.max(1, Math.round(rawExpSum * scale))   # L3092
```

`EXPSCALE` 的精確計算（`build_cq2.py` L3304-3317，Python 端 build-time 計算後用字串替換內嵌進 JS，
**不是** CONTENT.json 的欄位，也不是執行期公式）：

```python
for map_id, cfg in CONTENT.pacing.maps.items():
    groups = CONTENT.encounters[map_id]                      # 若沒有這個 key 直接跳過（不進表）
    avg = mean( sum(enemy.exp for enemy in group) for group in groups )   # 每個 formation 總 exp 的平均
    need = sum( expNeed(lv) for lv in range(cfg.entryLv, cfg.targetLv) ) # Python range，不含 targetLv
    party = cfg.get("party", pacing.partySize)
    EXPSCALE[map_id] = round(party * need / (cfg.battles * avg), 3)  if avg > 0 else 1
# 查表用 b.enc（GameState.encounter）當 key；ch1_boss/ch2_bear/prologue_demon 這類不在
# CONTENT.pacing.maps 裡的特殊戰鬥，EXPSCALE 沒有對應項，效果等同係數 1（不縮放，用原始 exp 總和）。
```

**MOD-E 實作現況（記錄於此，供之後 CORE-2 若要補齊轉存欄位時參考）**：檢查過
`godot-project/resources/content/content.json`（CORE-2 轉存結果）與 `sync_content.py`，**目前沒有
任何欄位存放 EXPSCALE**——這張表在 GDevelop 端是 build_cq2.py 自己用 Python 算出來、字串替換進 JS 常數，
從未進過 `CONTENT.json` 本體，所以 CORE-2 轉存時自然也沒有轉存到。本規格原文（v1.0）「Godot 端等同做法：
在 CORE-2 轉存 CONTENT.json 時，把 EXPSCALE 一併算出存進轉存結果」這句話目前尚未成立。MOD-E 的變通做法：
在自己擁有的 `godot-project/scripts/battle/exp_scale.gd` 內用上面的公式，**唯讀**呼叫
`ContentDB.get_pacing()`/`get_encounter()`/`get_enemy()`/`ExpNeed.exp_need()` 現場算出等價值（純函式，
不寫回任何 ContentDB 內部狀態，不算「MOD 任務自己重算 derive()」那類被禁止的行為，只是把 build-time 常數
表換成 run-time 等價計算）。若之後 CORE-2 任務負責者想把這個表移到轉存階段預先算好（跟原始碼設計更一致、
啟動時省一點計算），`exp_scale.gd` 的公式可以直接搬過去，`ContentDB` 加一個 `get_exp_scale(map_id)`
查詢介面，MOD-E 這邊改成呼叫該介面即可，不影響呼叫端（`battle_state_machine.gd`）簽名。

**Godot v3.0 演進（隨 F-11 遭遇結構升級）**：`formations` 改為帶數量範圍/權重的編組後，上式的 `avg`
（每組總 exp 的平均）在 `exp_scale.gd` 改算為——每組期望 EXP =`Σ member(期望隻數 × 單隻 exp)`（期望隻數
=`(min+max)/2`），各組再依 `weight` 加權平均。當 member 全填 `min=max`、`weight` 省略時，與上式算術平均
完全等價（向下相容）；其餘 need/party/battles 部分不變。

## F-10　掉落機率（Godot 端設計，非 GDevelop 抄錄）

戰鬥勝利結算時，對每個敵人的每筆 `drops` 元素獨立擲骰（`battle_state_machine.gd` 勝利結算段）：

```
mult      = enemy.drops[i].rate           # 怪物端「加成倍率」，不再是絕對機率
baseRate  = ContentDB.get_item(id).base_drop_rate   # 物品自身基礎掉落率；查不到物品則視同 1.0
luckBonus = maxPartyLuckV * d.dropPerLuck / 100     # v4.0：全隊最高 luckV（含裝備）× 0.1%/luck
chance    = clamp(baseRate * mult + luckBonus, 0, 1)
掉落 = randf() < chance
```

- **v4.0 幸運加成（`dropPerLuck=0.1`）**：`luckBonus` 取全隊存活/陣亡英雄中最高的 `luckV`（`derive` 算好、含
  裝備幸運），加算進最終掉率。例：全隊最高 luckV=8（如戴瑪莎護身戒）→ 每筆掉落 +0.8%。設計為「加法微幅
  提升」，避免與怪物倍率相乘造成失控。

- **物品端**（`ItemDef`）：`rarity`（common/uncommon/rare/key）為分級標籤；`base_drop_rate` 是該物品的基礎掉率。
  現行分級：普通素材 0.20、優良素材 0.12、稀有素材（水晶碎片）0.05；消耗品/關鍵物品 `base_drop_rate = 0`
  （不從戰鬥掉落，只走商店/寶箱/劇情）。
- **怪物端**（`EnemyDef.drops[].rate`）：作為倍率去「加成或抑制」該物品的基礎掉率。一般怪主素材倍率約 1.0~2.5；
  Boss 對稀有素材給高倍率（例：食人魔水晶碎片 ×16 → clamp 到 0.8）以維持「Boss 幾乎必掉」的手感。
- 設計理由：同一素材由不同怪掉落時，稀有度由**物品**統一定義，怪物只調整權重，避免每隻怪各自寫死絕對機率造成
  同物品掉率四散、難以維護。
- 與 GDevelop 差異：GDevelop 端 `drops[].rate` 是絕對機率、且物品無 rarity 概念；此為遷移期刻意重構，回頭若要
  從 GDevelop 重新拉資料，`sync_content.py`/種子 JSON 不含這兩欄，需由設計員在 Godot Inspector 補回。

## F-11　遭遇編組與抽選（Godot 端設計，非 GDevelop 抄錄；v3.0）

`EncounterDef.formations` 由 v2.0 的「固定敵人 id 陣列清單」(`Array[Array[String]]`) 升級為「帶權重與數量
範圍的編組清單」(`Array[Dictionary]`)。真相源＝`resources/content/encounters/*.tres`。

**單一 formation 結構：**

```
{
  "weight": 3.0,                                          # 選填，加權抽組用，預設 1.0
  "members": [{"id": "goblin", "min": 1, "max": 3}, ...] # 每種怪的數量範圍（同隻可複數）
}
```

- boss/精英與其隨從放進**同一組** members 即可（例：`ch1_boss` = 頭目 ×1 + 哥布林 ×2~3 + 野狼 ×0~1）。
- `min = 0` 代表「該成員有時不出現」。

**遇敵抽選 `EncounterDef.roll()`（`scripts/content/encounter_def.gd`，`battle_state_machine._init_battle` 呼叫）：**

1. 依各 formation 的 `weight` 加權隨機挑一組（權重總和 ≤ 0 時退化為均勻隨機）。
2. 對該組每個 member，在 `[min, max]` 間均勻隨機決定隻數，展開成敵人 id 陣列。
3. `shuffle()` 洗牌（讓混編排列多樣）。
4. **保底**：若展開後為空（所有 member 都抽到 0），補該組第一個有效成員 1 隻——不會有 0 隻空戰鬥。
5. **上限**：截斷到 `EncounterDef.MAX_FOES = 5`。此值＝`battle_state_machine.FOE_SLOTS` 的槽位數（戰場座標
   槽）；要放更多敵人必須先擴 `FOE_SLOTS` 佈局，屬另一項工作，故目前 boss 亦受此硬上限約束。

**下限**：無全域硬性下限，最少 1 隻（保底）。「一般遭遇 2+ 隻、單隻留給精英/boss/劇情戰」是**編排慣例**
（由各表 `min` 值落實），非程式強制。

**與 GDevelop 差異**：GDevelop 端 encounter 是固定編成、均勻隨機、無數量範圍與權重；此為遷移期刻意重構。
種子 JSON（`sync_content.py`）不含新結構，`region_generator._make_formations()` 已同步產出 v2 格式。

## 待確認事項

- ~~F-8 敵人技能傷害公式需要在實作 MOD-E 時回 `foeAct` 函式精確核對~~——**已於 v1.1 補齊**，見上方 F-8。
- WORLD/BATTLE 兩份 `derive()` 在 `critV` 是否取一位小數上不一致（見 F-1 註記），Godot 版統一用 WORLD
  版寫法（取一位小數），此為刻意修正技術債，不是誤譯——MOD-F 實作時若發現任何實測數值跟 GDevelop 版對不上，
  優先檢查是不是踩到這個已知差異點。
- F-9 EXPSCALE 目前由 MOD-E 在 `exp_scale.gd` 現場計算（見上方 F-9「MOD-E 實作現況」），還沒有搬進
  CORE-2 的轉存階段；若之後要移過去，介面收斂方式已經在該節記錄。
