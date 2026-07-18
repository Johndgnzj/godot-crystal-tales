#!/usr/bin/env python3
"""MOD-A 抽取腳本：把 build_cq2.py 的 DLG/CUTS dict literal 轉成 dialogue.json（種子）。

注意（v3.0 起）：dialogue.json 已不是遊戲直接讀的資料——它是「種子」，之後由
scripts/dialogue/build_dialogue_tres.gd 轉成原生 .tres（真相源＝resources/content/dialogue/**/*.tres，
DialogueSystem 讀聚合 dialogue_db.tres）。本腳本＋build_dialogue_tres.gd 只在「重新匯入種子」時才跑；
平時設計員直接在 Godot Inspector 編個別 .tres。

決定（見 TASKS/01_對話劇情.md「已知風險」與 specs/DIALOGUE_SPEC.md D-2 最後一段）：不要手動抄
DLG/CUTS 到 Godot 端資料檔，容易漏抄/抄錯；改用這支腳本直接對 build_cq2.py 做 AST 解析，取出
`DLG = {...}` 與 `CUTS = {...}` 兩個頂層 Assign 節點，`ast.literal_eval()` 還原成真正的 Python
物件（DLG/CUTS 本來就是合法的 Python dict/list/str 字面值，不是動態產生的），再做欄位轉寫後輸出
JSON。之後 GDevelop 端台詞異動，重跑這支腳本即可重新抽取，不用手動比對。

轉寫規則（跟原始 GDevelop 資料結構的差異，皆為刻意決定，見 specs/DIALOGUE_SPEC.md D-2/D-3/D-8）：
  - DLG 條目的 "name" 欄位改名為 "speaker"（跟 CutsceneEntry 的 speaker 欄位一致，避免 Godot 端
    一個叫 name 一個叫 speaker）。
  - DLG 條目缺少的 "action" 一律補 null（而不是 KeyError），方便 Godot 端 from_dict 用同一種
    d.get("action", "") 寫法處理。
  - DLG 條目保留 "cmd"/"label"/"done"（缺省補 null）：立繪＋選單式室內（town 六棟主人）靠這三個欄位
    組動態指令選單（交談／功能／一次性事件／離開），見 interior.gd 與 dialogue_system.get_interior_commands()。
    戶外 NPC（gray/mira/guard）沒有 cmd，維持既有「首個 when 命中」的對話行為，不受影響。
  - CUTS 的 "lines" 從 `[[speaker, text], ...]` 轉成 `[{"speaker":..., "text":...}, ...]`
    （json 種子層仍是 Dictionary 陣列；Godot 端 v3.0 起已進一步轉為 Array[CutsceneLine]，轉換在
    build_dialogue_tres.gd／cutscene_entry.gd from_dict，見 DIALOGUE_SPEC v3.0）。
  - CUTS 額外欄位 "battle"/"transfer"/"setstep"/"party" 目前不在 spec D-3 文件內（该文件只寫了
    once/lines），是本次抽取時從原始碼發現的既有欄位（L995-997 的 demon_pre/demon_post/town_start）：
    一併保留，並回頭更新了 specs/DIALOGUE_SPEC.md D-3（見該檔案版本註記）。缺省一律補 null / 空陣列，
    不用 KeyError，方便 Godot 端讀取。

用法：
    python3 extract_dialogue.py            # 抽取 + 寫檔
    python3 extract_dialogue.py --check    # 只核對筆數，不寫檔（CI / pre-commit 用）
"""

from __future__ import annotations

import argparse
import ast
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

GODOT_ROOT = Path(__file__).resolve().parents[2]           # .../godot-crystal-tales/godot-project
REPO_ROOT = GODOT_ROOT.parent                               # .../godot-crystal-tales
SOURCE = REPO_ROOT / "reference" / "gdevelop" / "build_cq2.py"
DEST = GODOT_ROOT / "resources" / "content" / "dialogue.json"


class ExtractError(Exception):
    pass


def _find_dict_literal(tree: ast.Module, name: str) -> dict:
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == name:
                    if not isinstance(node.value, ast.Dict):
                        raise ExtractError(f"{name} 頂層不是 dict literal，抽取腳本假設可能已過期")
                    return ast.literal_eval(node.value)
    raise ExtractError(f"在來源檔案裡找不到頂層 `{name} = {{...}}` 賦值")


def transform_dlg(raw: dict) -> dict:
    out: dict = {}
    entry_count = 0
    for npc_id, entries in raw.items():
        conv = []
        for e in entries:
            conv.append({
                "when": e.get("when", "always"),
                "speaker": e.get("name", ""),
                "lines": list(e.get("lines", [])),
                "action": e.get("action"),
                # 室內選單（立繪＋選單式室內，build_cq2.py buildIntCmds L1575-1582）需要這三個欄位：
                #   cmd  ＝指令分類（talk/quest/rest/pray/trade／一次性事件如 hank_gift）
                #   label＝功能/事件在選單裡顯示的中文（cmd==talk 者無 label）
                #   done ＝一次性事件的完成旗標名；該旗標設立後此指令從選單消失
                "cmd": e.get("cmd"),
                "label": e.get("label"),
                "done": e.get("done"),
            })
            entry_count += 1
        out[npc_id] = conv
    return out, entry_count


def transform_cuts(raw: dict) -> dict:
    out: dict = {}
    for cut_id, c in raw.items():
        lines = [{"speaker": pair[0], "text": pair[1]} for pair in c.get("lines", [])]
        out[cut_id] = {
            "once": c.get("once"),
            "lines": lines,
            "battle": c.get("battle"),
            "transfer": list(c["transfer"]) if c.get("transfer") else None,
            "setstep": c.get("setstep"),
            "party": list(c["party"]) if c.get("party") else None,
        }
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="只核對筆數，不寫檔")
    args = parser.parse_args()

    if not SOURCE.exists():
        print(f"[FAIL] 找不到來源 build_cq2.py: {SOURCE}", file=sys.stderr)
        return 1

    src_text = SOURCE.read_text(encoding="utf-8")
    tree = ast.parse(src_text, filename=str(SOURCE))

    try:
        dlg_raw = _find_dict_literal(tree, "DLG")
        cuts_raw = _find_dict_literal(tree, "CUTS")
    except ExtractError as e:
        print(f"[FAIL] {e}", file=sys.stderr)
        return 1

    dlg_out, dlg_entry_count = transform_dlg(dlg_raw)
    cuts_out = transform_cuts(cuts_raw)

    # 核對筆數：dlg 用「條目數」（陣列元素總和），不是 npc 數；cuts 用 key 數
    src_dlg_entry_count = sum(len(v) for v in dlg_raw.values())
    src_cuts_count = len(cuts_raw)
    if dlg_entry_count != src_dlg_entry_count:
        print(f"[FAIL] DLG 條目數不一致：來源 {src_dlg_entry_count}，轉出 {dlg_entry_count}", file=sys.stderr)
        return 1
    if len(cuts_out) != src_cuts_count:
        print(f"[FAIL] CUTS 筆數不一致：來源 {src_cuts_count}，轉出 {len(cuts_out)}", file=sys.stderr)
        return 1

    print(f"[OK] DLG: {len(dlg_out)} 個 npc_id，共 {dlg_entry_count} 條對話條目。")
    print(f"[OK] CUTS: {len(cuts_out)} 筆過場。")

    if args.check:
        print("[OK] --check 模式，不寫檔。")
        return 0

    out = {
        "_meta": {
            "generated_by": "godot-project/scripts/dialogue/extract_dialogue.py",
            "source": str(SOURCE.relative_to(WORKSPACE_ROOT)) if SOURCE.is_relative_to(WORKSPACE_ROOT) else str(SOURCE),
            "extracted_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "dlg_npc_count": len(dlg_out),
            "dlg_entry_count": dlg_entry_count,
            "cuts_count": len(cuts_out),
            "note": "DialogueSystem 只讀取 dlg/cuts 兩個頂層 key，_meta 是抽取溯源用，會被忽略。",
        },
        "dlg": dlg_out,
        "cuts": cuts_out,
    }

    DEST.parent.mkdir(parents=True, exist_ok=True)
    with DEST.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[OK] 已寫出 -> {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
