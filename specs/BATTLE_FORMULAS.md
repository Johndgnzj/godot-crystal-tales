# 規格：衍生屬性與戰鬥公式

- Spec 版本: v1.0
- 對應 GDevelop 原始碼快照: `scripts/build_cq2.py`（WORLD 版 `derive()` L1326-1345；BATTLE 版 `derive()`
  L2641-2661 為同一份公式的重複實作——**已知技術債，DEV_開發指南.md L63 有提及「改公式要同步兩處」**）
- 狀態: 定案（抄錄自現行程式碼，行為以此為準；若與 DEV_開發指南.md 文字敘述衝突，以本文件的原始碼行號為準）
- 用途: MOD-F（衍生屬性/戰鬥公式）、MOD-E（ATB 戰鬥系統）實作依據

> Godot 端**只需要實作一份** `derive()` 等價物（不要複製 GDevelop 的兩份技術債），這是 MOD-F 相對於原始碼的
> 唯一刻意偏離之處，其餘公式原樣照搬。

## F-1　衍生屬性 `derive(m)`（L1326 / L2641，兩處邏輯相同）

輸入 `m`：`{id, lv, attrs:{str,agi,int}, mainAttr, eq?, hp?, mp?, sk?, spts?}`，`CONTENT.derived` 提供係數
表 `d`。

```
maxhp   = d.hpBase + attrs.str * d.hpPerStr + eqStat(m,"hp")
maxmp   = d.mpBase + attrs.int * d.mpPerInt + eqStat(m,"mp")
patk    = d.weaponAtk + attrs[mainAttr] * 2 + eqStat(m,"patk")
matk    = round(attrs.int * d.matkPerInt) + eqStat(m,"matk")
pdef    = attrs.str + eqStat(m,"pdef")
mdef    = round(attrs.int * d.mdefPerInt) + eqStat(m,"mdef")
dodgeV  = round(attrs.agi * d.dodgePerAgi) + eqStat(m,"dodge")
critV   = d.critBase + attrs.agi * d.critPerAgi + eqStat(m,"crit")   # WORLD 版額外做 round(...*10)/10，取一位小數；BATTLE 版沒 round——不一致，Godot 版統一採 WORLD 版的取一位小數寫法
spd     = attrs.agi
```

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

## F-3　普攻傷害 `phys(att, defn)`（L2945-2953）

```
atk = att.attrs ? att.patk : att.atk      # 我方走 patk，敵方走敵人資料表的 atk
df  = defn.attrs ? defn.pdef : defn.def
base = atk*1.8 - df; base = max(1, base)
if defn.defending: base *= 0.5             # 防禦指令減傷 50%
critCh = att.attrs ? att.critV/100 : d.critBase/100    # 敵方一律用基礎會心率，沒有個別敵人會心加成
crit = random() < critCh
final = max(1, round(base * (0.85~1.00 隨機, 均勻分布) * (crit ? 1.5 : 1)))
```

## F-4　閃避判定 `dodge(att, defn)`（L2938-2944）

```
dv = defn.attrs ? defn.dodgeV : defn.spd * d.dodgePerAgi
av = att.attrs  ? att.attrs.agi * d.dodgePerAgi : att.spd * d.dodgePerAgi
chance% = clamp(dv - av, 0, d.dodgeCap)
是否閃避 = random()*100 < chance%
```

閃避判定在**普攻**才會呼叫（`applyOne` 的 `pd.t==="atk"` 分支）；技能傷害不判定閃避（`sk.kind==="damage"`
分支沒有呼叫 `dodge`），全體技能 `applyAll` 同樣不判閃避——這是刻意設計，Godot 端不要「順手」補上。

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
初始 ATB：敵人初始化時 `m.atb = random()*40`（L2852），英雄未特別提及初值（預設 0，第一輪需要蓄滿）
```

- 只有 `state === "run"` 時才蓄力，任何選單/演出（`menu`/`target`/`anim`/…）都暫停 ATB，等同「等待模式」，
  DEV 指南提到的「waitMode=true 由狀態機天然實現」在這裡對應：Godot 版狀態機只要複製「非 run 狀態不蓄力」
  這條規則即可，不需要額外維護一個 waitMode 旗標。

## F-8　敵人技能（`foeAct`，DEV 指南 L59 摘要，實作以 build_cq2.py `foeAct` 函式為準）

- 敵人資料可帶 `foeSkills: [{name, target: "one"|"all", mult}]`，40% 機率使出技能而非普攻。
- 技能傷害＝`phys 公式的 atk` 改乘 `mult`（即 `atk * mult` 進入等同 F-3 的傷害流程，實作時回 build_cq2.py
  `foeAct` 精確行號核對，本文件先記錄行為輪廓，MOD-E 實作時需補齊精確算式後更新本節版本號至 v1.1）。
- `healer`/`allAttack` 旗標可與 `foeSkills` 並存。
- Boss 血條只顯示「☠ 名稱」不露數字，血條本身仍會畫（UI 規則，不是戰鬥公式，歸 MOD-D）。

## F-9　EXP 縮放

```
EXP 實際獲得 = 敵人資料表原始值 × EXPSCALE
EXPSCALE 由 build_cq2.py 從 CONTENT.pacing.battles（練級所需場數係數）換算產生，是「建置期」常數，
不是執行期公式——Godot 端等同做法：在 CORE-2 轉存 CONTENT.json 時，把 EXPSCALE 一併算出存進轉存結果，
不要在戰鬥程式碼裡重複這段換算邏輯。
```

## 待確認事項

- F-8 敵人技能傷害公式需要在實作 MOD-E 時回 `foeAct` 函式精確核對（目前只抄了行為輪廓）。
- WORLD/BATTLE 兩份 `derive()` 在 `critV` 是否取一位小數上不一致（見 F-1 註記），Godot 版統一用 WORLD
  版寫法（取一位小數），此為刻意修正技術債，不是誤譯——MOD-F 實作時若發現任何實測數值跟 GDevelop 版對不上，
  優先檢查是不是踩到這個已知差異點。
