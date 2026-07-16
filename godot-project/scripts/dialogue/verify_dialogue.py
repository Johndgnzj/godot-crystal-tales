#!/usr/bin/env python3
"""MOD-A 驗證腳本（Python，不依賴 Godot 執行檔——見 TASKS/01_對話劇情.md 驗收標準／
CLAUDE.md「驗證與測試」一節：這次執行環境沒有 Godot 執行檔，用 Python 做能做到的驗證，
不假裝做過實機驗證）。

做三件事：
  1. 筆數核對：重新對 build_cq2.py 做一次獨立抽取（不透過 extract_dialogue.py 的程式碼路徑，
     避免「用同一份程式碼驗證自己」），跟已寫出的 dialogue.json 逐筆比對 DLG/CUTS 是否完全相等。
  2. action 覆蓋率核對：dialogue.json 裡出現過的所有 action id，跟
     scripts/dialogue/dialogue_system.gd 的 `_run_action()` match 分支逐一比對，找出「資料有但程式碼
     沒處理」或「程式碼處理了但資料沒用到」的落差（後者不算錯，例如 give_earring 目前就是資料沒用到，
     但要能清楚列出來，不能悶著）。
  3. 抽樣核對三位分支最多的 NPC（緹娜/漢克/老葛雷）在幾種旗標組合下，用純 Python 重新實作的
     選擇邏輯選出的對話條目，跟 build_cq2.py 原始碼行為一致。選擇語意分兩軌（見 D-2）：室外 NPC
     扁平由上而下（L1859-1864）；室內主人先按 cmd 分組再組內由上而下（openOwnerCmd L1564-1566），
     一次性贈禮事件另有 done 旗標在選單層過濾（buildIntCmds L1580，只發一次）。

用法：python3 verify_dialogue.py
"""
from __future__ import annotations

import ast
import json
import re
import sys
from pathlib import Path

GODOT_ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = GODOT_ROOT.parent
SOURCE = REPO_ROOT / "reference" / "gdevelop" / "build_cq2.py"
DIALOGUE_JSON = GODOT_ROOT / "resources" / "content" / "dialogue.json"
DIALOGUE_SYSTEM_GD = GODOT_ROOT / "scripts" / "dialogue" / "dialogue_system.gd"

FAILURES: list[str] = []


def fail(msg: str) -> None:
    FAILURES.append(msg)
    print(f"[FAIL] {msg}")


def ok(msg: str) -> None:
    print(f"[OK] {msg}")


# ---------------------------------------------------------------------------
# 1. 獨立重新抽取 + 逐筆比對
# ---------------------------------------------------------------------------

def independent_extract() -> tuple[dict, dict]:
    tree = ast.parse(SOURCE.read_text(encoding="utf-8"), filename=str(SOURCE))
    dlg_raw = None
    cuts_raw = None
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id == "DLG":
                    dlg_raw = ast.literal_eval(node.value)
                elif isinstance(t, ast.Name) and t.id == "CUTS":
                    cuts_raw = ast.literal_eval(node.value)
    if dlg_raw is None or cuts_raw is None:
        fail("找不到 DLG 或 CUTS 頂層賦值")
        sys.exit(1)
    return dlg_raw, cuts_raw


def check_counts_and_content(dlg_raw: dict, cuts_raw: dict, data: dict) -> None:
    dlg_out = data.get("dlg", {})
    cuts_out = data.get("cuts", {})

    src_npc_ids = set(dlg_raw.keys())
    out_npc_ids = set(dlg_out.keys())
    if src_npc_ids != out_npc_ids:
        fail(f"DLG npc_id 集合不一致：來源多出 {src_npc_ids - out_npc_ids}，輸出多出 {out_npc_ids - src_npc_ids}")
    else:
        ok(f"DLG npc_id 集合一致（{len(src_npc_ids)} 個）")

    entry_mismatch = []
    for npc_id in src_npc_ids & out_npc_ids:
        src_entries = dlg_raw[npc_id]
        out_entries = dlg_out[npc_id]
        if len(src_entries) != len(out_entries):
            entry_mismatch.append(f"{npc_id}: 來源 {len(src_entries)} 筆，輸出 {len(out_entries)} 筆")
            continue
        for i, (s, o) in enumerate(zip(src_entries, out_entries)):
            if s.get("when", "always") != o.get("when"):
                entry_mismatch.append(f"{npc_id}[{i}].when: {s.get('when','always')!r} != {o.get('when')!r}")
            if s.get("name", "") != o.get("speaker"):
                entry_mismatch.append(f"{npc_id}[{i}].speaker: {s.get('name','')!r} != {o.get('speaker')!r}")
            if list(s.get("lines", [])) != list(o.get("lines", [])):
                entry_mismatch.append(f"{npc_id}[{i}].lines 不一致")
            src_action = s.get("action")
            out_action = o.get("action")
            if (src_action or None) != (out_action or None):
                entry_mismatch.append(f"{npc_id}[{i}].action: {src_action!r} != {out_action!r}")
    if entry_mismatch:
        for m in entry_mismatch:
            fail(f"DLG 內容不一致: {m}")
    else:
        total = sum(len(v) for v in dlg_raw.values())
        ok(f"DLG 逐筆內容比對全部一致（共 {total} 條對話條目）")

    src_cut_ids = set(cuts_raw.keys())
    out_cut_ids = set(cuts_out.keys())
    if src_cut_ids != out_cut_ids:
        fail(f"CUTS cut_id 集合不一致：來源多出 {src_cut_ids - out_cut_ids}，輸出多出 {out_cut_ids - src_cut_ids}")
    else:
        ok(f"CUTS cut_id 集合一致（{len(src_cut_ids)} 筆）")

    cut_mismatch = []
    for cut_id in src_cut_ids & out_cut_ids:
        s = cuts_raw[cut_id]
        o = cuts_out[cut_id]
        if (s.get("once") or None) != (o.get("once") or None):
            cut_mismatch.append(f"{cut_id}.once: {s.get('once')!r} != {o.get('once')!r}")
        s_lines = [[p[0], p[1]] for p in s.get("lines", [])]
        o_lines = [[l.get("speaker"), l.get("text")] for l in o.get("lines", [])]
        if s_lines != o_lines:
            cut_mismatch.append(f"{cut_id}.lines 不一致")
        if (s.get("battle") or None) != (o.get("battle") or None):
            cut_mismatch.append(f"{cut_id}.battle: {s.get('battle')!r} != {o.get('battle')!r}")
        s_transfer = list(s["transfer"]) if s.get("transfer") else None
        o_transfer = list(o["transfer"]) if o.get("transfer") else None
        if s_transfer != o_transfer:
            cut_mismatch.append(f"{cut_id}.transfer: {s_transfer!r} != {o_transfer!r}")
        if s.get("setstep") != o.get("setstep"):
            cut_mismatch.append(f"{cut_id}.setstep: {s.get('setstep')!r} != {o.get('setstep')!r}")
        s_party = list(s["party"]) if s.get("party") else None
        o_party = list(o["party"]) if o.get("party") else None
        if s_party != o_party:
            cut_mismatch.append(f"{cut_id}.party: {s_party!r} != {o_party!r}")
    if cut_mismatch:
        for m in cut_mismatch:
            fail(f"CUTS 內容不一致: {m}")
    else:
        ok(f"CUTS 逐筆內容比對全部一致（{len(src_cut_ids)} 筆，含 battle/transfer/setstep/party 欄位）")


# ---------------------------------------------------------------------------
# 2. action 覆蓋率
# ---------------------------------------------------------------------------

def check_action_coverage(data: dict) -> None:
    used_actions = set()
    for entries in data.get("dlg", {}).values():
        for e in entries:
            a = e.get("action")
            if a:
                used_actions.add(a)

    gd_text = DIALOGUE_SYSTEM_GD.read_text(encoding="utf-8")
    # 抓 _run_action() 裡 match 區塊中所有 "xxx": 開頭的分支字面值
    handled_actions = set()
    in_match = False
    for line in gd_text.splitlines():
        if "func _run_action" in line:
            in_match = True
        if in_match:
            m = re.match(r'\s*"([a-zA-Z0-9_]+)"\s*:\s*$', line)
            if m:
                handled_actions.add(m.group(1))
            if line.strip() == "_:":
                break

    missing = used_actions - handled_actions
    unused = handled_actions - used_actions
    if missing:
        fail(f"dialogue.json 用到但 dialogue_system.gd 沒處理的 action: {sorted(missing)}")
    else:
        ok(f"dialogue.json 用到的 {len(used_actions)} 個 action id 全部有對應的 _run_action 分支")
    if unused:
        print(f"[INFO] dialogue_system.gd 有實作但 dialogue.json 目前沒用到的 action（保留供未來/對稱性，"
              f"非錯誤）: {sorted(unused)}")


# ---------------------------------------------------------------------------
# 3. 抽樣核對三位分支最多的 NPC
# ---------------------------------------------------------------------------

def match_when(flags: dict, w) -> bool:
    if not w or w == "always":
        return True
    m = re.match(r"^(\w+)(==|>=)(\d+)$", str(w))
    if not m:
        return False
    v = flags.get(m.group(1), 0)
    n = int(m.group(3))
    return v == n if m.group(2) == "==" else v >= n


def choose(entries: list, flags: dict, cmd: str | None = None):
    """cmd=None：室外貼近 NPC 對話，扁平掃全表（build_cq2.py L1859-1864）。
    cmd 給值：室內主人指令，只掃同 cmd 組（openOwnerCmd L1564-1566，無 cmd 視為 "talk"）。"""
    for e in entries:
        if cmd is not None and (e.get("cmd") or "talk") != cmd:
            continue
        if match_when(flags, e.get("when")):
            return e
    return None


def event_visible(entries: list, flags: dict, cmd: str) -> bool:
    """一次性事件指令是否出現在室內互動選單（buildIntCmds L1580）：
    when 成立且 done 旗標未設才出現——贈禮只發一次的機制在選單層，不是 when 條件。"""
    for e in entries:
        if (e.get("cmd") or "talk") != cmd:
            continue
        if match_when(flags, e.get("when")) and not (e.get("done") and flags.get(e["done"], 0)):
            return True
    return False


def check_samples(data: dict) -> None:
    dlg = data["dlg"]
    # 兩套選擇語意（對照 build_cq2.py）：
    #   室外 NPC（gray/mira/rossel…，條目無 cmd）＝扁平由上而下（L1859-1864）→ cmd 給 None。
    #   室內主人（tina/hank/dora…，條目有 cmd）＝先選指令再組內由上而下（openOwnerCmd L1564-1566）
    #   → cmd 給 "talk"/"quest"/"trade"/事件 id。
    # 注意：matchWhen 對未定義旗標視為 0，tina talk 組第一條是 "step==0"（L950），所以 talk 組
    # 除了測 step==0 本身那組，其餘情境都要明確給 step 一個非 0 值（比照遊戲實際進度——
    # reg/ch1/ch2 開始有值時，step 早就因為 register 的 CUTS setstep 或 action 進到 >=3 了），
    # 不然 step 預設 0 會被 matchWhen 誤判成「還在 step==0」而蓋掉後面條件，這是 matchWhen 語意本身
    # 的特性（未定義旗標視為 0），不是資料或程式碼的錯。
    scenarios = [
        ("tina", "talk", {"step": 0}, "step==0"),
        ("tina", "quest", {"step": 3, "reg": 1}, "reg==1"),
        ("tina", "quest", {"step": 3, "ch1": 1}, "ch1==1"),
        ("tina", "quest", {"step": 3, "ch1": 2}, "ch1==2"),
        ("tina", "talk", {"step": 3, "ch2": 1}, "ch2>=1"),
        ("hank", "talk", {"step": 0}, "step==0"),
        ("hank", "hank_gift", {"step": 3, "ch1": 1}, "ch1>=1"),
        ("gray", None, {"ch1": 3}, "ch1==3"),
        ("gray", None, {"ch2": 1}, "ch2==1"),
        ("gray", None, {"ch2": 2}, "ch2==2"),
        ("gray", None, {"relic": 1}, "relic==1"),
    ]
    all_ok = True
    for npc_id, cmd, flags, expect_when in scenarios:
        chosen = choose(dlg[npc_id], flags, cmd)
        if chosen is None:
            fail(f"抽樣 {npc_id} cmd={cmd!r} flags={flags}: 沒有任何條目命中（預期命中 when={expect_when!r}）")
            all_ok = False
            continue
        if chosen.get("when") != expect_when:
            fail(f"抽樣 {npc_id} cmd={cmd!r} flags={flags}: 命中 when={chosen.get('when')!r}，預期 {expect_when!r}"
                 f"（可能是陣列順序被改動，優先權跟 GDevelop 版不一致）")
            all_ok = False
        else:
            print(f"[OK] {npc_id} cmd={cmd!r} flags={flags} -> when={chosen.get('when')!r} "
                  f"action={chosen.get('action')!r} 第一句={chosen['lines'][0][:20]!r}")
    # done 旗標語意（贈禮只發一次）：漢克贈劍事件在 gotSword 設起前可見、設起後從選單消失。
    for flags, expect in (({"step": 3, "ch1": 1}, True), ({"step": 3, "ch1": 1, "gotSword": 1}, False)):
        got = event_visible(dlg["hank"], flags, "hank_gift")
        if got != expect:
            fail(f"hank_gift flags={flags}: 選單可見={got}，預期 {expect}（done 旗標語意，L1580）")
            all_ok = False
        else:
            print(f"[OK] hank_gift flags={flags} -> 選單可見={got}（done='gotSword' 只發一次）")
    if all_ok:
        ok("緹娜/漢克/老葛雷抽樣情境全部命中預期的 when 分支（cmd 分組＋陣列優先順序＋done 語意跟原始碼一致）")


def main() -> int:
    if not SOURCE.exists():
        fail(f"找不到來源 build_cq2.py: {SOURCE}")
        return 1
    if not DIALOGUE_JSON.exists():
        fail(f"找不到 dialogue.json: {DIALOGUE_JSON}（先跑 extract_dialogue.py）")
        return 1
    if not DIALOGUE_SYSTEM_GD.exists():
        fail(f"找不到 dialogue_system.gd: {DIALOGUE_SYSTEM_GD}")
        return 1

    data = json.loads(DIALOGUE_JSON.read_text(encoding="utf-8"))
    dlg_raw, cuts_raw = independent_extract()

    check_counts_and_content(dlg_raw, cuts_raw, data)
    check_action_coverage(data)
    check_samples(data)

    print()
    if FAILURES:
        print(f"[SUMMARY] {len(FAILURES)} 項失敗，見上方 [FAIL]。")
        return 1
    print("[SUMMARY] 全部通過。再次強調：這是 Python 對資料/文字層級的核對，不是 Godot 實機驗證"
          "（GDScript 語法是否真的能在 Godot 4.3 引擎裡跑起來，仍待有 Godot 執行檔的環境確認，"
          "見 TASKS/01_對話劇情.md 與 TASKS/00_核心任務.md CORE-1 的驗收現況說明）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
