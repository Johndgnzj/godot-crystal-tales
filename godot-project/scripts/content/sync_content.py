#!/usr/bin/env python3
"""CORE-2 轉存腳本：把 CONTENT.json 同步進 Godot 專案。

角色（2026-07-14 更新，見 ../../autoload/content_db.gd 檔頭與 CORE-2 spec）：切斷 GDevelop 臍帶後，
Godot 端的 .tres 才是資料真相源，平時不跑這支。本腳本淪為**可選的「從 GDevelop 重新匯入」工具**——把
GDevelop 那份 CONTENT.json 複製進 res://resources/content/content.json（帶輕量 schema 檢查），之後再跑
scripts/content/build_tres.gd 產生 .tres。只有「要把 GDevelop 的新資料拉進來」時才需要這條路。

用法：
    python3 sync_content.py            # 同步 + 檢查
    python3 sync_content.py --check    # 只檢查，不寫檔（CI / pre-commit 用）

不依賴 Godot 執行檔，只用標準函式庫，跟 GDevelop 那邊 art_v*.py 系列風格一致（純 Python 腳本，
無額外套件依賴）。
"""

from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

GODOT_ROOT = Path(__file__).resolve().parents[2]          # .../godot-crystal-tales/godot-project
WORKSPACE_ROOT = GODOT_ROOT.parent.parent                  # .../ (GDevelop 與 Godot 兩個 repo 的共同上層)
SOURCE = WORKSPACE_ROOT / "GDevelop" / "projects" / "crystal-quest" / "CONTENT.json"
DEST = GODOT_ROOT / "resources" / "content" / "content.json"

REQUIRED_TOP_KEYS = [
    "party", "derived", "equipment", "skills", "pacing",
    "items", "enemies", "encounters", "shops", "chests",
]

REQUIRED_FIELDS = {
    "party": ["id", "name", "class", "mainAttr", "base", "startLevel", "startEq"],
    "equipment": ["id", "name", "slot", "buy", "sell"],
    "skills": ["id", "name", "class", "unlockLv", "mp", "kind", "attr", "mult", "target"],
    "items": ["id", "name", "cat", "buy", "sell"],
    "enemies": ["id", "name", "sprite", "hp", "atk", "def", "spd", "exp", "gold"],
    "chests": ["id", "map", "tx", "ty", "tier", "loot"],
}


class SchemaError(Exception):
    pass


def validate(data: dict) -> list[str]:
    """回傳警告清單（非致命）；schema 破壞性問題直接 raise SchemaError。"""
    warnings: list[str] = []

    missing_top = [k for k in REQUIRED_TOP_KEYS if k not in data]
    if missing_top:
        raise SchemaError(f"缺少頂層分類: {missing_top}")

    for category, fields in REQUIRED_FIELDS.items():
        entries = data[category]
        if not isinstance(entries, list):
            raise SchemaError(f"{category} 應該是陣列，實際是 {type(entries).__name__}")
        for i, entry in enumerate(entries):
            missing = [f for f in fields if f not in entry]
            if missing:
                raise SchemaError(
                    f"{category}[{i}] (id={entry.get('id', '?')}) 缺少必要欄位: {missing}"
                )

    # derived 必要係數（see specs/BATTLE_FORMULAS.md）
    derived_required = [
        "hpBase", "hpPerStr", "mpBase", "mpPerInt", "weaponAtk", "pointsPerLevel",
        "skillPointsPerLevel", "skillMaxLv", "skillPowerPerLv", "expBase", "expCoef",
        "expPow", "matkPerInt", "mdefPerInt", "dodgePerAgi", "dodgeCap", "critBase",
        "critPerAgi",
    ]
    missing_derived = [k for k in derived_required if k not in data["derived"]]
    if missing_derived:
        raise SchemaError(f"derived 缺少必要係數: {missing_derived}")

    # pacing
    if "partySize" not in data["pacing"] or "maps" not in data["pacing"]:
        raise SchemaError("pacing 缺少 partySize 或 maps")

    # encounters / shops 是 id -> 內容的物件，不是陣列
    if not isinstance(data["encounters"], dict):
        raise SchemaError("encounters 應該是物件（map_id -> 陣列）")
    if not isinstance(data["shops"], dict):
        raise SchemaError("shops 應該是物件（shop_id -> 內容）")
    for shop_id, shop in data["shops"].items():
        if "sell" not in shop:
            warnings.append(f"shops.{shop_id} 沒有 sell 欄位")

    # equipment 的屬性加成欄位是稀疏的（見 EquipmentDef.STAT_KEYS），這裡只警告未知欄位，不擋
    known_eq_fields = {
        "id", "name", "slot", "desc", "buy", "sell", "tier",
        "patk", "pdef", "matk", "mdef", "hp", "mp", "crit", "dodge",
    }
    for entry in data["equipment"]:
        unknown = set(entry.keys()) - known_eq_fields
        if unknown:
            warnings.append(f"equipment.{entry.get('id')} 有未知欄位（EquipmentDef 沒對應到）: {unknown}")

    return warnings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="只做 schema 檢查，不寫檔")
    args = parser.parse_args()

    if not SOURCE.exists():
        print(f"[FAIL] 找不到來源 CONTENT.json: {SOURCE}", file=sys.stderr)
        return 1

    with SOURCE.open("r", encoding="utf-8") as f:
        data = json.load(f)

    try:
        warnings = validate(data)
    except SchemaError as e:
        print(f"[FAIL] schema 檢查未通過: {e}", file=sys.stderr)
        return 1

    for w in warnings:
        print(f"[WARN] {w}")

    counts = {k: (len(v) if isinstance(v, (list, dict)) else None) for k, v in data.items()}
    print(f"[OK] schema 檢查通過。分類筆數: {counts}")

    if args.check:
        print("[OK] --check 模式，不寫檔。")
        return 0

    out = dict(data)
    out["_meta"] = {
        "generated_by": "godot-project/scripts/content/sync_content.py",
        "source": str(SOURCE.relative_to(WORKSPACE_ROOT)) if SOURCE.is_relative_to(WORKSPACE_ROOT) else str(SOURCE),
        "synced_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "note": "ContentDB 只讀取原有 10 個頂層分類，_meta 是同步溯源用，會被忽略。",
    }

    DEST.parent.mkdir(parents=True, exist_ok=True)
    with DEST.open("w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"[OK] 已同步 -> {DEST}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
