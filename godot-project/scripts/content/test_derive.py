#!/usr/bin/env python3
"""MOD-F 驗收腳本：derive.gd / exp_need.gd 的純 Python 單元測試，不依賴 Godot 執行檔。

⚠️ v4.0 屬性系統擴充（2026-07-19，see specs/BATTLE_FORMULAS.md v4.0 / TASKS/14）後，本檔尚未重寫：
   derive() 已改為「主屬性先疊裝備再算衍生」、attrs 增 luck、新增 accV/critresV/critdmg/luckV、critPerAgi
   0.15→0.2、critV/dodgeV 納入 luck。本檔以「與 GDevelop build_cq2.py WORLD/BATTLE 版逐字 parity」為前提，
   而 v4.0 刻意偏離 GDevelop（GDevelop 無 luck 等），EXPECTED_WORLD/BATTLE 對改動欄位不再等值。重寫為
   「無 GDevelop 參照的 v4.0 新測試」屬獨立後續工作，未納入本次屬性系統擴充。


跟 validate_content.py（CORE-2）同樣的環境限制：這個環境拿不到 Godot 執行檔（見 CORE-1 驗收現況），
沒辦法真的執行 derive.gd。這支腳本改用兩層交叉驗證逼近「跑過 derive.gd 再核對」的效果：

  1. `py_derive()` / `py_exp_need()`：derive.gd / exp_need.gd 的逐行 Python 翻譯（不是重新設計一份邏輯，
     是同一份公式在兩種語言各寫一次，方便肉眼逐行比對兩邊是否一致——見函式旁的 .gd 行號註解）。

  2. `EXPECTED_WORLD` / `EXPECTED_BATTLE`：凍結的實測 fixture，來源是**直接從
     reference/gdevelop/build_cq2.py 逐字抄出**的 WORLD 版
     （L1326-1345）與 BATTLE 版（L2641-2661）`derive()`／`expNeed()`（L1325/L2662）字面 JS 原始碼，用
     Node.js 對同一批測試用 member 字典跑一次算出來的（見本檔案 `_REGEN_NOTE`）。這是 TASKS/06 驗收標準
     要求的「跟 GDevelop 版 debug hook 讀出的實測值比對」在沒有瀏覽器/GDevelop 執行環境時最接近的替代方案
     ——直接執行同一段 JS 公式原始碼，而不是憑印象手刻期望值。
     若這台機器上有 Node.js，`--regen` 模式會現場重新執行 build_cq2.py 的字面 derive()/expNeed()
     （用一份最小 harness，literal 複製自 build_cq2.py，不 import 整支腳本，因為那支腳本有大量 GDevelop
     runtime 依賴），核對凍結 fixture 沒有因為 build_cq2.py 之後被改動而過期漂移。

  3. 驗證重點：
     a) `py_derive()` 的每一個輸出欄位都跟 EXPECTED_WORLD（已修正版：critV 取一位小數）逐位元完全相等
        （0 誤差，不接受「差不多」——TASKS/06 驗收標準明講）。
     b) 抽樣幾筆刻意選在 WORLD 版跟 BATTLE 版 critV 算出來不一樣的案例（浮點誤差讓「取一位小數」實際
        改變了數值，不是紙上談兵），斷言 `py_derive()` 的 critV 對齊 WORLD、**不對齊** BATTLE——證明
        derive.gd 確實套用了 F-1 記載的刻意修正，而不是巧合碰對。

測試涵蓋（對應 TASKS/06「至少 3 名不同 mainAttr 隊伍成員」）：
  - ludo（str，CONTENT.json 真實角色）：無裝備 / 滿裝備+多次升級點
  - marin（agi，CONTENT.json 真實角色）：m.eq undefined -> 套用 startEq 模板分支
  - alan（str，CONTENT.json 真實 guest 角色，startLevel=20）：guest 高等級邊界
  - synthetic_mage（int，**CONTENT.json 目前沒有 int 主屬性角色**，見下方 _SYNTHETIC_NOTE）：滿裝備
  - 技能解鎖等級邊界（whirl unlockLv=5，Lv4 vs Lv5 各測一次）
  - hp/mp clamp（超過上限的舊存檔數值、hp 完全未定義兩種情境）
  - sk 已存在但是空 dict {} 時不可重新計算（JS `if(!m.sk)` 的 truthy 語意差異，見 derive.gd 內註解）

用法：
    python3 test_derive.py            # 只用凍結 fixture 比對（預設，不需要 Node.js）
    python3 test_derive.py --regen    # 額外用 Node.js 現場重跑 build_cq2.py 字面 derive()，核對 fixture 沒過期
"""

from __future__ import annotations

import json
import math
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent                 # .../godot-project/scripts/content
GODOT_ROOT = SCRIPT_DIR.parents[1]                            # .../godot-project
REPO_ROOT = GODOT_ROOT.parent                                 # .../godot-crystal-tales
CONTENT_PATH = REPO_ROOT / "reference" / "gdevelop" / "CONTENT.json"
BUILD_CQ2_PATH = REPO_ROOT / "reference" / "gdevelop" / "build_cq2.py"

FAILURES: list[str] = []


def fail(msg: str) -> None:
    FAILURES.append(msg)
    print(f"[FAIL] {msg}")


def ok(msg: str) -> None:
    print(f"[OK] {msg}")


# =========================================================================
# py_derive() / py_exp_need()：derive.gd / exp_need.gd 的逐行 Python 翻譯
# 對照 godot-project/scripts/content/derive.gd 與 exp_need.gd（本次 MOD-F 產出）
# =========================================================================

def js_round(x: float) -> float:
    """比照 JS `Math.round()` / GDScript `roundf()` 對非負數的語意：四捨五入，.5 進位（不是 Python
    內建 round() 的銀行家捨入）。本檔案所有屬性值恆為非負，不處理負數語意差異。"""
    return math.floor(x + 0.5)


def eq_stat(member: dict, key: str, equipment: dict) -> float:
    """derive.gd `_eq_stat()`，對應 build_cq2.py `eqStat(m,k)`（L1324/L2640）。"""
    total = 0.0
    for eq_id in member.get("eq", {}).values():
        e = equipment.get(eq_id)
        if e is not None:
            total += float(e.get(key, 0) or 0)
    return total


def py_derive(member: dict, content: dict) -> dict:
    """derive.gd `Derive.derive()` 的逐行翻譯。原地修改並回傳同一個 dict（跟 .gd/JS 版一致的
    mutate-in-place 語意）。"""
    m = member
    d = content["derived"]
    equipment = {e["id"]: e for e in content["equipment"]}
    party_templates = {p["id"]: p for p in content["party"]}
    attrs = m.get("attrs", {})

    if "eq" not in m:
        eq = {}
        tmpl = party_templates.get(m.get("id"))
        if tmpl is not None:
            for slot, eq_id in tmpl.get("startEq", {}).items():
                eq[slot] = eq_id
        m["eq"] = eq

    str_v = float(attrs.get("str", 0))
    agi_v = float(attrs.get("agi", 0))
    int_v = float(attrs.get("int", 0))
    main_attr = m.get("mainAttr", "")
    main_v = float(attrs.get(main_attr, 0))

    m["maxhp"] = d["hpBase"] + str_v * d["hpPerStr"] + eq_stat(m, "hp", equipment)
    m["maxmp"] = d["mpBase"] + int_v * d["mpPerInt"] + eq_stat(m, "mp", equipment)
    m["patk"] = d["weaponAtk"] + main_v * 2.0 + eq_stat(m, "patk", equipment)
    m["matk"] = js_round(int_v * d["matkPerInt"]) + eq_stat(m, "matk", equipment)
    m["pdef"] = str_v + eq_stat(m, "pdef", equipment)
    m["mdef"] = js_round(int_v * d["mdefPerInt"]) + eq_stat(m, "mdef", equipment)
    m["dodgeV"] = js_round(agi_v * d["dodgePerAgi"]) + eq_stat(m, "dodge", equipment)
    # critV：F-1 刻意修正點，統一取一位小數（WORLD 版寫法）——見 derive.gd 檔頭「刻意行為修正」註解。
    m["critV"] = js_round((d["critBase"] + agi_v * d["critPerAgi"] + eq_stat(m, "crit", equipment)) * 10.0) / 10.0
    m["spd"] = agi_v

    if "hp" not in m or float(m["hp"]) > float(m["maxhp"]):
        m["hp"] = m["maxhp"]
    if "mp" not in m or float(m["mp"]) > float(m["maxmp"]):
        m["mp"] = m["maxmp"]

    sk_val = m.get("sk", None)
    if sk_val is None or sk_val is False:
        sk = {}
        cls = m.get("cls", "")
        lv = int(m.get("lv", 1))
        for s in content["skills"]:
            if s.get("class") == cls and lv >= s.get("unlockLv", 1):
                sk[s["id"]] = 1
        m["sk"] = sk

    if "spts" not in m:
        m["spts"] = 0

    return m


def py_exp_need(lv: int, content: dict) -> int:
    """exp_need.gd `ExpNeed.exp_need()` 的逐行翻譯，對應 build_cq2.py `expNeed(lv)`（L1325/L2662）。"""
    d = content["derived"]
    return int(d["expBase"] + js_round(d["expCoef"] * math.pow(float(lv), d["expPow"])))


# =========================================================================
# 測試案例（見檔頭清單；_SYNTHETIC_NOTE 說明 int 主屬性角色為何是合成資料）
# =========================================================================

# _SYNTHETIC_NOTE：CONTENT.json 目前只有 3 名隊伍成員（ludo/str、marin/agi、alan/str），沒有
# int 主屬性角色（截至 2026-07-14）。TASKS/06 要求「至少涵蓋 3 名不同 mainAttr 的隊伍成員」，但真實
# 資料無法滿足（缺 int 分支）。這裡用一個明確標記為合成（synthetic_mage，id 不存在於 CONTENT.json）
# 的測試 member 補上 int 分支覆蓋，驗證 `patk = weaponAtk + attrs[mainAttr]*2` 對任意 mainAttr 字串都
# 正確索引，以及 matk/mdef 公式本來就跟 mainAttr 無關（恆用 attrs.int）。裝備/技能表仍查真實
# CONTENT.json 資料（cls="explorer" 沿用真實技能表），只有 attrs/mainAttr/id 是合成的。
DERIVE_CASES = [
    ("ludo_no_eq", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 1,
                     "attrs": {"str": 4, "agi": 3, "int": 2}, "eq": {}}),
    ("ludo_full_eq_lv5", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 5,
                           "attrs": {"str": 12, "agi": 7, "int": 6},
                           "eq": {"weapon": "steel_sword", "armor": "chainmail", "boots": "silver_boots",
                                  "wrist": "steel_bracer", "acc1": "lucky_coin"}}),
    ("marin_default_eq", {"id": "marin", "cls": "explorer", "mainAttr": "agi", "lv": 1,
                           "attrs": {"str": 3, "agi": 4, "int": 3}}),  # 沒有 eq -> 套用 startEq 模板
    ("synthetic_int_full_eq", {"id": "synthetic_mage", "cls": "explorer", "mainAttr": "int", "lv": 6,
                                "attrs": {"str": 5, "agi": 5, "int": 10},
                                "eq": {"weapon": "keen_dagger", "armor": "mage_robe", "boots": "silver_boots",
                                       "wrist": "steel_bracer", "acc1": "focus_earring"}}),
    ("alan_guest_lv20", {"id": "alan", "cls": "veteran", "mainAttr": "str", "lv": 20,
                           "attrs": {"str": 30, "agi": 24, "int": 14}, "guest": True}),  # 無 eq -> startEq
    ("ludo_skill_boundary_lv4", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 4,
                                  "attrs": {"str": 10, "agi": 6, "int": 5}, "eq": {}}),
    ("ludo_skill_boundary_lv5", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 5,
                                  "attrs": {"str": 12, "agi": 7, "int": 6}, "eq": {}}),
    ("hp_clamp_stale", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 1,
                         "attrs": {"str": 4, "agi": 3, "int": 2}, "eq": {}, "hp": 9999, "mp": 9999}),
    ("hp_undefined", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 1,
                       "attrs": {"str": 4, "agi": 3, "int": 2}, "eq": {}}),
    ("sk_already_empty_not_recomputed", {"id": "ludo", "cls": "explorer", "mainAttr": "str", "lv": 5,
                                          "attrs": {"str": 12, "agi": 7, "int": 6}, "eq": {}, "sk": {}}),
]

EXP_NEED_LEVELS = [1, 2, 3, 5, 10, 15, 20, 30, 50]

# 凍結 fixture：2026-07-14 用 Node.js v22 對上面 DERIVE_CASES / EXP_NEED_LEVELS 執行 build_cq2.py
# WORLD 版（L1326-1345，已是 F-1 要求的「取一位小數」寫法）與 BATTLE 版（L2641-2661，未取一位小數，
# 技術債版本）derive() 字面原始碼算出來的結果。derive.gd 應該對齊 EXPECTED_WORLD，不是 EXPECTED_BATTLE。
EXPECTED_WORLD_CRITV = {
    "ludo_no_eq": 6.7, "ludo_full_eq_lv5": 9.3, "marin_default_eq": 10.9,
    "synthetic_int_full_eq": 15.0, "alan_guest_lv20": 9.9,
    "ludo_skill_boundary_lv4": 7.2, "ludo_skill_boundary_lv5": 7.3,
    "hp_clamp_stale": 6.7, "hp_undefined": 6.7, "sk_already_empty_not_recomputed": 7.3,
}
# BATTLE 版（無 round）在這幾筆的 critV 跟 WORLD 版不同（浮點誤差讓「取一位小數」實際改變了數值，
# 不是巧合）：用來證明 derive.gd 確實套用了 F-1 修正、不是意外跟舊 BATTLE 版一樣。
EXPECTED_BATTLE_CRITV_DIVERGENT = {
    "marin_default_eq": 10.85, "alan_guest_lv20": 9.85, "ludo_skill_boundary_lv4": 7.15,
}

EXPECTED_WORLD_FULL = {
    "ludo_no_eq": {"maxhp": 62, "maxmp": 18, "patk": 14, "matk": 4, "pdef": 4, "mdef": 2,
                   "dodgeV": 5, "critV": 6.7, "spd": 3, "hp": 62, "mp": 18,
                   "sk": {"power_strike": 1}, "spts": 0, "eq": {}},
    "ludo_full_eq_lv5": {"maxhp": 126, "maxmp": 38, "patk": 43, "matk": 12, "pdef": 25, "mdef": 5,
                          "dodgeV": 16, "critV": 9.3, "spd": 7, "hp": 126, "mp": 38,
                          "sk": {"power_strike": 1, "swift_stab": 1, "heal_wind": 1, "whirl": 1}, "spts": 0},
    "marin_default_eq": {"maxhp": 54, "maxmp": 23, "patk": 15, "matk": 6, "pdef": 6, "mdef": 5,
                          "dodgeV": 6, "critV": 10.9, "spd": 4, "hp": 54, "mp": 23,
                          "sk": {"power_strike": 1}, "spts": 0,
                          "eq": {"weapon": "hunting_knife", "armor": "traveler_garb",
                                 "boots": "leather_boots", "acc1": "agate_charm"}},
    "synthetic_int_full_eq": {"maxhp": 70, "maxmp": 83, "patk": 33, "matk": 25, "pdef": 12, "mdef": 8,
                               "dodgeV": 11, "critV": 15.0, "spd": 5, "hp": 70, "mp": 83,
                               "sk": {"power_strike": 1, "swift_stab": 1, "heal_wind": 1, "whirl": 1},
                               "spts": 0},
    "alan_guest_lv20": {"maxhp": 270, "maxmp": 78, "patk": 74, "matk": 28, "pdef": 36, "mdef": 11,
                          "dodgeV": 40, "critV": 9.9, "spd": 24, "hp": 270, "mp": 78,
                          "sk": {"flash": 1}, "spts": 0,
                          "eq": {"weapon": "iron_sword", "armor": "leather_vest",
                                 "boots": "swift_boots", "wrist": "iron_bracer"}},
    "ludo_skill_boundary_lv4": {"maxhp": 110, "maxmp": 33, "patk": 26, "matk": 10, "pdef": 10, "mdef": 4,
                                 "dodgeV": 9, "critV": 7.2, "spd": 6, "hp": 110, "mp": 33,
                                 "sk": {"power_strike": 1, "swift_stab": 1, "heal_wind": 1}, "spts": 0},
    "ludo_skill_boundary_lv5": {"maxhp": 126, "maxmp": 38, "patk": 30, "matk": 12, "pdef": 12, "mdef": 5,
                                 "dodgeV": 11, "critV": 7.3, "spd": 7, "hp": 126, "mp": 38,
                                 "sk": {"power_strike": 1, "swift_stab": 1, "heal_wind": 1, "whirl": 1},
                                 "spts": 0},
    "hp_clamp_stale": {"maxhp": 62, "maxmp": 18, "patk": 14, "matk": 4, "pdef": 4, "mdef": 2,
                        "dodgeV": 5, "critV": 6.7, "spd": 3, "hp": 62, "mp": 18,
                        "sk": {"power_strike": 1}, "spts": 0},
    "hp_undefined": {"maxhp": 62, "maxmp": 18, "patk": 14, "matk": 4, "pdef": 4, "mdef": 2,
                      "dodgeV": 5, "critV": 6.7, "spd": 3, "hp": 62, "mp": 18,
                      "sk": {"power_strike": 1}, "spts": 0},
    "sk_already_empty_not_recomputed": {"maxhp": 126, "maxmp": 38, "patk": 30, "matk": 12, "pdef": 12,
                                         "mdef": 5, "dodgeV": 11, "critV": 7.3, "spd": 7, "hp": 126, "mp": 38,
                                         "sk": {}, "spts": 0},
}

EXPECTED_EXP_NEED = {1: 18, 2: 31, 3: 47, 5: 86, 10: 211, 15: 365, 20: 540, 30: 946, 50: 1923}


def numbers_equal(a, b) -> bool:
    if isinstance(a, dict) or isinstance(b, dict):
        return a == b
    return float(a) == float(b)


def run_frozen_fixture_check(content: dict) -> None:
    print("\n=== derive.gd (py_derive 鏡像) vs 凍結 WORLD fixture（0 誤差比對）===")
    for key, member in DERIVE_CASES:
        import copy
        result = py_derive(copy.deepcopy(member), content)
        expected = EXPECTED_WORLD_FULL[key]
        mismatches = []
        for field, exp_val in expected.items():
            got_val = result.get(field)
            if not numbers_equal(got_val, exp_val):
                mismatches.append(f"{field}: got={got_val} expected={exp_val}")
        if mismatches:
            fail(f"{key}: 跟凍結 WORLD fixture 不一致 -> {mismatches}")
        else:
            ok(f"{key}: 全部欄位跟凍結 WORLD fixture 完全相等 "
               f"(critV={result['critV']}, maxhp={result['maxhp']}, patk={result['patk']})")

    print("\n=== critV 刻意修正點驗證：derive.gd 對齊 WORLD，不對齊 BATTLE ===")
    for key, battle_v in EXPECTED_BATTLE_CRITV_DIVERGENT.items():
        import copy
        result = py_derive(copy.deepcopy(dict(DERIVE_CASES)[key]), content)
        world_v = EXPECTED_WORLD_CRITV[key]
        if result["critV"] != world_v:
            fail(f"{key}: critV={result['critV']} 應該等於 WORLD 版 {world_v}")
        elif result["critV"] == battle_v:
            fail(f"{key}: critV={result['critV']} 意外跟未修正的 BATTLE 版 {battle_v} 相同"
                 f"（這筆案例本來就是挑選來證明兩版真的有差異的，相同代表 fixture 選錯案例或修正沒生效）")
        else:
            ok(f"{key}: critV={result['critV']}（WORLD 版）明確不同於 BATTLE 版技術債結果 {battle_v}"
               f"，證明 derive.gd 確實套用了 F-1 的取一位小數修正")

    print("\n=== exp_need.gd (py_exp_need 鏡像) vs 凍結 fixture ===")
    for lv, expected in EXPECTED_EXP_NEED.items():
        got = py_exp_need(lv, content)
        if got != expected:
            fail(f"exp_need(lv={lv}): got={got} expected={expected}")
        else:
            ok(f"exp_need(lv={lv}) = {got}")


_REGEN_NOTE = """
--regen 模式：現場用 Node.js 重新執行 build_cq2.py WORLD/BATTLE 版 derive()/expNeed() 的字面 JS 原始碼
（跟本檔案凍結 fixture 用的是同一段抄錄邏輯），核對凍結 fixture 是否因為 build_cq2.py 之後被改動而過期。
"""

_JS_HARNESS = r"""
import { readFileSync } from "fs";
const CONTENT = JSON.parse(readFileSync(process.argv[2], "utf8"));
const EQ = {};
for (const e of CONTENT.equipment || []) EQ[e.id] = e;
function eqStat(m, k) { var t = 0; if (m.eq) { for (var s in m.eq) { var e = EQ[m.eq[s]]; if (e && e[k]) t += e[k]; } } return t; }
function deriveWorld(m0) {
  const m = JSON.parse(JSON.stringify(m0)); const d = CONTENT.derived;
  if (m.eq === undefined) { m.eq = {}; for (var i=0;i<CONTENT.party.length;i++){var t=CONTENT.party[i]; if(t.id===m.id&&t.startEq){for(var s in t.startEq)m.eq[s]=t.startEq[s];}} }
  m.maxhp=d.hpBase+m.attrs.str*d.hpPerStr+eqStat(m,"hp"); m.maxmp=d.mpBase+m.attrs.int*d.mpPerInt+eqStat(m,"mp");
  m.patk=d.weaponAtk+m.attrs[m.mainAttr]*2+eqStat(m,"patk"); m.matk=Math.round(m.attrs.int*d.matkPerInt)+eqStat(m,"matk");
  m.pdef=m.attrs.str+eqStat(m,"pdef"); m.mdef=Math.round(m.attrs.int*d.mdefPerInt)+eqStat(m,"mdef");
  m.dodgeV=Math.round(m.attrs.agi*d.dodgePerAgi)+eqStat(m,"dodge");
  m.critV=Math.round((d.critBase+m.attrs.agi*d.critPerAgi+eqStat(m,"crit"))*10)/10; m.spd=m.attrs.agi;
  if(m.hp===undefined||m.hp>m.maxhp)m.hp=m.maxhp; if(m.mp===undefined||m.mp>m.maxmp)m.mp=m.maxmp;
  if(!m.sk){m.sk={};for(var i=0;i<CONTENT.skills.length;i++){var s=CONTENT.skills[i];if(s["class"]===m.cls&&m.lv>=s.unlockLv)m.sk[s.id]=1;}}
  if(m.spts===undefined)m.spts=0; return m;
}
function expNeed(lv){var d=CONTENT.derived;return d.expBase+Math.round(d.expCoef*Math.pow(lv,d.expPow));}
const cases = JSON.parse(readFileSync(process.argv[3], "utf8"));
const out = {derive_world:{}, exp_need:{}};
for (const c of cases.derive) out.derive_world[c.key] = deriveWorld(c.member);
for (const lv of cases.exp_need_levels) out.exp_need[lv] = expNeed(lv);
console.log(JSON.stringify(out));
"""


def run_regen_check(content: dict) -> None:
    import copy
    import tempfile

    node = None
    for candidate in ("node", "nodejs"):
        found = subprocess.run(["which", candidate], capture_output=True, text=True)
        if found.returncode == 0:
            node = found.stdout.strip()
            break
    if node is None:
        print("\n[--regen] 找不到 Node.js，略過現場重跑比對（凍結 fixture 檢查已在上面跑過）。")
        return

    print(f"\n=== --regen：用 {node} 現場重跑 build_cq2.py 字面 derive()/expNeed() 核對 fixture 沒過期 ===")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        harness = tmp_path / "harness.mjs"
        harness.write_text(_JS_HARNESS, encoding="utf-8")
        cases_path = tmp_path / "cases.json"
        cases_path.write_text(json.dumps({
            "derive": [{"key": k, "member": v} for k, v in DERIVE_CASES],
            "exp_need_levels": EXP_NEED_LEVELS,
        }), encoding="utf-8")
        result = subprocess.run([node, str(harness), str(CONTENT_PATH), str(cases_path)],
                                 capture_output=True, text=True)
        if result.returncode != 0:
            fail(f"--regen: node 執行失敗: {result.stderr}")
            return
        live = json.loads(result.stdout)
        for key, expected in EXPECTED_WORLD_FULL.items():
            live_m = live["derive_world"][key]
            mismatches = [f"{f}: fixture={v} live={live_m.get(f)}" for f, v in expected.items()
                          if not numbers_equal(live_m.get(f), v)]
            if mismatches:
                fail(f"--regen {key}: 凍結 fixture 跟現場重跑 build_cq2.py 結果不一致（fixture 可能過期）"
                     f" -> {mismatches}")
            else:
                ok(f"--regen {key}: 凍結 fixture 跟現場重跑一致")
        for lv, expected in EXPECTED_EXP_NEED.items():
            live_v = live["exp_need"][str(lv)]
            if live_v != expected:
                fail(f"--regen exp_need(lv={lv}): fixture={expected} live={live_v}")
            else:
                ok(f"--regen exp_need(lv={lv}): 凍結 fixture 跟現場重跑一致")


def main() -> int:
    if not CONTENT_PATH.exists():
        fail(f"找不到 CONTENT.json: {CONTENT_PATH}")
        return 1
    content = json.loads(CONTENT_PATH.read_text(encoding="utf-8"))

    run_frozen_fixture_check(content)
    if "--regen" in sys.argv:
        run_regen_check(content)

    print("\n=== 總結 ===")
    print(f"FAIL: {len(FAILURES)}")
    if FAILURES:
        print("驗收未通過，詳見上方 [FAIL] 項目。")
        return 1
    print("驗收通過（純 Python 鏡像 derive.gd/exp_need.gd 邏輯，對照凍結的 build_cq2.py 實測 fixture，"
          "未實機跑過 Godot，見腳本檔頭說明）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
