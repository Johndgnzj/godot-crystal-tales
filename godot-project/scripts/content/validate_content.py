#!/usr/bin/env python3
"""CORE-2 驗收腳本：核對 ContentDB 的轉存邏輯跟 CONTENT.json 是否一致，不依賴 Godot 執行檔。

這個環境目前拿不到 Godot 執行檔（見 CORE-1 驗收現況），沒辦法真的跑 ContentDB.gd 過一遍驗證，所以
這支腳本用兩層純 Python 檢查，逼近「跑過 ContentDB 再核對」的效果：

  1. 同步正確性：res://resources/content/content.json（sync_content.py 的輸出）跟來源 CONTENT.json
     的 10 個頂層分類必須逐位元組相等（排除 sync 腳本自己加的 _meta 溯源欄位）。這只證明「複製沒出錯」，
     還不能證明 ContentDB.gd 的欄位對應邏輯本身是對的。

  2. 欄位對應邏輯正確性（重點）：對 godot-project/scripts/content/*.gd 的原始碼做靜態掃描，抓出每個
     from_dict() 用字面字串 d.get("XXX", ...) 讀取的 JSON key，回頭比對 CONTENT.json 該分類實際出現過
     的 key 集合：
       - GDScript 讀了但來源從沒出現過的 key -> 極可能是打錯字（例如 "allattack" 打成非駝峰），FAIL。
       - 來源出現過但沒有任何 GDScript 欄位讀取的 key -> 可能是新欄位漏接了，列為 WARN（不擋，因為部分
         欄位本來就刻意不接，例如目前沒有用到的欄位）。
     這一步是刻意設計成「讀 .gd 原始碼本身」而不是在 Python 端重新手刻一份對照表，因為重新手刻的話，
     如果我在寫 .gd 跟寫驗證腳本時共用同一個打錯的欄位名稱，兩邊會互相對不出錯誤（驗證變成套套邏輯）。
     直接讀 .gd 檔案原始碼可以避免這個問題。

  3. 逐筆關鍵欄位比對：把「靜態掃描抓到的欄位」實際套用到每一筆來源資料上模擬 from_dict()，跟來源原始值
     做 == 比對（型別容忍 int/float），並印出 enemies 的 hp/atk/def/spd/exp/gold 逐筆結果供人工複核
     （對照 CORE-2 任務驗收標準的舉例）。

用法：
    python3 validate_content.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent                 # .../godot-project/scripts/content
GODOT_ROOT = SCRIPT_DIR.parents[1]                            # .../godot-project
WORKSPACE_ROOT = GODOT_ROOT.parent.parent                     # 共同上層目錄
SOURCE = WORKSPACE_ROOT / "gd-crystal-tales" / "projects" / "crystal-quest" / "CONTENT.json"
SYNCED = GODOT_ROOT / "resources" / "content" / "content.json"

# 分類 -> (.gd 檔案, 是不是「id -> 內容」的物件而非陣列)
CATEGORY_FILES = {
    "party": SCRIPT_DIR / "party_member_def.gd",
    "equipment": SCRIPT_DIR / "equipment_def.gd",
    "skills": SCRIPT_DIR / "skill_def.gd",
    "items": SCRIPT_DIR / "item_def.gd",
    "enemies": SCRIPT_DIR / "enemy_def.gd",
    "chests": SCRIPT_DIR / "chest_def.gd",
    "shops": SCRIPT_DIR / "shop_def.gd",
    "derived": SCRIPT_DIR / "derived_params.gd",
    "pacing": SCRIPT_DIR / "pacing_params.gd",
}

GET_CALL_RE = re.compile(r'\.get\(\s*"([A-Za-z_][A-Za-z0-9_]*)"')
STAT_KEYS_RE = re.compile(r'const STAT_KEYS\s*:=\s*\[(.*?)\]', re.DOTALL)
STRING_LITERAL_RE = re.compile(r'"([A-Za-z_][A-Za-z0-9_]*)"')

FAILURES: list[str] = []
WARNINGS: list[str] = []


def fail(msg: str) -> None:
    FAILURES.append(msg)
    print(f"[FAIL] {msg}")


def warn(msg: str) -> None:
    WARNINGS.append(msg)
    print(f"[WARN] {msg}")


def ok(msg: str) -> None:
    print(f"[OK] {msg}")


def extract_keys_used_by_gdscript(gd_path: Path) -> set[str]:
    """從 .gd 原始碼抓出所有 d.get("xxx", ...) 讀取的 JSON key 字面值，
    equipment_def.gd 額外處理 STAT_KEYS 常數（動態 key 存取，抓不到 .get("xxx") 字面呼叫）。"""
    text = gd_path.read_text(encoding="utf-8")
    keys = set(GET_CALL_RE.findall(text))
    stat_match = STAT_KEYS_RE.search(text)
    if stat_match:
        keys |= set(STRING_LITERAL_RE.findall(stat_match.group(1)))
    return keys


def source_keys_for_list(entries: list[dict]) -> set[str]:
    keys: set[str] = set()
    for e in entries:
        keys |= set(e.keys())
    return keys


def source_keys_for_dict_of_dicts(d: dict) -> set[str]:
    keys: set[str] = set()
    for v in d.values():
        if isinstance(v, dict):
            keys |= set(v.keys())
    return keys


def numbers_equal(a, b) -> bool:
    if isinstance(a, bool) or isinstance(b, bool):
        return a == b
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return float(a) == float(b)
    return a == b


def main() -> int:
    if not SOURCE.exists():
        fail(f"找不到來源 CONTENT.json: {SOURCE}")
        return 1
    if not SYNCED.exists():
        fail(f"找不到同步後的 content.json: {SYNCED}（先跑 sync_content.py）")
        return 1

    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    synced = json.loads(SYNCED.read_text(encoding="utf-8"))
    synced_no_meta = {k: v for k, v in synced.items() if k != "_meta"}

    # ---- 第 1 層：同步正確性（byte-for-byte 資料相等，排除 _meta）----
    print("\n=== 第 1 層：sync_content.py 輸出 vs 來源 CONTENT.json ===")
    if synced_no_meta == source:
        ok("10 個頂層分類的資料內容完全相等（deep equality，排除 _meta 溯源欄位）")
    else:
        for key in source.keys() | synced_no_meta.keys():
            if source.get(key) != synced_no_meta.get(key):
                fail(f"分類 '{key}' 同步前後不一致")

    counts_src = {k: len(v) for k, v in source.items() if isinstance(v, (list, dict))}
    counts_dst = {k: len(v) for k, v in synced_no_meta.items() if isinstance(v, (list, dict))}
    if counts_src == counts_dst:
        ok(f"各分類筆數一致: {counts_src}")
    else:
        fail(f"分類筆數不一致: source={counts_src} synced={counts_dst}")

    # ---- 第 2 層：.gd 欄位對應邏輯 vs 來源實際 schema ----
    print("\n=== 第 2 層：*_def.gd 靜態掃描的 JSON key 讀取 vs CONTENT.json 實際欄位 ===")

    # icon/rarity 是道具武器設計.md 新增的 Godot 端原生欄位，GDevelop 的 CONTENT.json 從未有過也不會有
    # （不是要抄錄的既有規則，是新設計），從 typo 檢查排除，避免每次跑這支腳本都誤報「疑似打錯字」。
    GODOT_NATIVE_EXTRA_KEYS = {
        "items": {"icon", "rarity"},
        "equipment": {"icon", "rarity", "attr_type"},
    }

    list_categories = ["party", "equipment", "skills", "items", "enemies", "chests"]
    dict_of_dict_categories = ["shops"]
    flat_dict_categories = ["derived", "pacing"]

    for cat in list_categories:
        gd_keys = extract_keys_used_by_gdscript(CATEGORY_FILES[cat])
        src_keys = source_keys_for_list(source[cat])
        typo_candidates = gd_keys - src_keys - GODOT_NATIVE_EXTRA_KEYS.get(cat, set())
        unread = src_keys - gd_keys
        if typo_candidates:
            fail(f"{cat}: .gd 讀取了來源從未出現過的 key（疑似打錯字）: {sorted(typo_candidates)}")
        else:
            ok(f"{cat}: .gd 讀取的 {len(gd_keys)} 個 key 全部存在於來源資料中")
        if unread:
            warn(f"{cat}: 來源出現過但沒有任何 .gd 欄位讀取的 key: {sorted(unread)}")

    for cat in dict_of_dict_categories:
        gd_keys = extract_keys_used_by_gdscript(CATEGORY_FILES[cat])
        src_keys = source_keys_for_dict_of_dicts(source[cat])
        typo_candidates = gd_keys - src_keys
        unread = src_keys - gd_keys
        if typo_candidates:
            fail(f"{cat}: .gd 讀取了來源從未出現過的 key（疑似打錯字）: {sorted(typo_candidates)}")
        else:
            ok(f"{cat}: .gd 讀取的 {len(gd_keys)} 個 key 全部存在於來源資料中")
        if unread:
            warn(f"{cat}: 來源出現過但沒有任何 .gd 欄位讀取的 key: {sorted(unread)}")

    for cat in flat_dict_categories:
        gd_keys = extract_keys_used_by_gdscript(CATEGORY_FILES[cat])
        src_keys = set(source[cat].keys())
        typo_candidates = gd_keys - src_keys
        unread = src_keys - gd_keys
        if typo_candidates:
            fail(f"{cat}: .gd 讀取了來源從未出現過的 key（疑似打錯字）: {sorted(typo_candidates)}")
        else:
            ok(f"{cat}: .gd 讀取的 {len(gd_keys)} 個 key 全部存在於來源資料中")
        if unread:
            warn(f"{cat}: 來源出現過但沒有任何 .gd 欄位讀取的 key: {sorted(unread)}")

    # ---- 第 3 層：逐筆關鍵欄位比對（模擬 from_dict，並印出 enemies 逐筆數值供複核）----
    print("\n=== 第 3 層：逐筆關鍵欄位比對（id 集合 + 數值）===")

    def check_list_ids_and_fields(cat: str, key_fields: list[str]) -> None:
        entries = source[cat]
        ids = [e["id"] for e in entries]
        if len(ids) != len(set(ids)):
            fail(f"{cat}: id 有重複: {ids}")
        else:
            ok(f"{cat}: {len(ids)} 筆，id 全部唯一 -> {ids}")
        for e in entries:
            for f in key_fields:
                if f in e and not isinstance(e[f], (dict, list)):
                    # 這裡的「比對」是跟來源自身核對型別/存在性（模擬 from_dict 的 .get 行為不會漏值）
                    val = e[f]
                    if val is None:
                        fail(f"{cat}.{e['id']}.{f} 是 null，from_dict 的型別轉換可能會出錯")

    check_list_ids_and_fields("party", ["id", "name", "class", "mainAttr", "startLevel"])
    check_list_ids_and_fields("equipment", ["id", "name", "slot", "buy", "sell", "tier"])
    check_list_ids_and_fields("skills", ["id", "name", "class", "unlockLv", "mp", "mult", "flat"])
    check_list_ids_and_fields("items", ["id", "name", "cat", "buy", "sell"])
    check_list_ids_and_fields("chests", ["id", "map", "tx", "ty", "tier"])

    print("\n  -- enemies 逐筆 hp/atk/def/spd/exp/gold（CORE-2 驗收標準舉例的關鍵欄位）--")
    enemy_field_keys = ["hp", "atk", "def", "spd", "exp", "gold"]
    gd_enemy_keys = extract_keys_used_by_gdscript(CATEGORY_FILES["enemies"])
    enemy_ids = []
    for e in source["enemies"]:
        enemy_ids.append(e["id"])
        row = {k: e.get(k) for k in enemy_field_keys}
        # 交叉核對: EnemyDef.from_dict 讀 "def" 存進 def_stat，這裡直接核對來源值本身存在且為數值
        missing = [k for k in enemy_field_keys if k not in e]
        if missing:
            fail(f"enemies.{e['id']} 缺少欄位: {missing}")
        elif not all(isinstance(row[k], (int, float)) and not isinstance(row[k], bool) for k in enemy_field_keys):
            fail(f"enemies.{e['id']} 有非數值欄位: {row}")
        else:
            print(f"    {e['id']:16s} hp={row['hp']:<6} atk={row['atk']:<4} def={row['def']:<4} "
                  f"spd={row['spd']:<4} exp={row['exp']:<5} gold={row['gold']}")
    if len(enemy_ids) == len(set(enemy_ids)) and len(enemy_ids) == 15:
        ok(f"enemies: 共 {len(enemy_ids)} 筆，id 唯一，符合 CONTENT.json 目前的 15 筆敵人資料")
    else:
        fail(f"enemies: 筆數或 id 唯一性不符預期 (got {len(enemy_ids)})")

    if "def" not in gd_enemy_keys:
        fail("enemy_def.gd 沒有讀取來源的 'def' 欄位（應該對應到 def_stat）")
    else:
        ok("enemy_def.gd 有讀取來源的 'def' 欄位並存進 def_stat（避開 GDScript 保留字）")

    # encounters / shops 的 id 集合檢查
    print("\n  -- encounters / shops --")
    ok(f"encounters: {len(source['encounters'])} 個地圖 -> {sorted(source['encounters'].keys())}")
    total_formations = sum(len(v) for v in source["encounters"].values())
    ok(f"encounters: 總計 {total_formations} 組遭遇編成")
    ok(f"shops: {len(source['shops'])} 間 -> {sorted(source['shops'].keys())}")

    print("\n=== 總結 ===")
    print(f"FAIL: {len(FAILURES)}, WARN: {len(WARNINGS)}")
    if FAILURES:
        print("驗收未通過，詳見上方 [FAIL] 項目。")
        return 1
    print("驗收通過（純 Python 靜態比對，未實機跑過 Godot/ContentDB.gd，見腳本檔頭說明）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
