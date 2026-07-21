#!/usr/bin/env python3
"""組建水晶傳說設定集：解析 content_db.tres → GAME JSON、解析對話 .tres 真相源
（dialogue_db.tres 聚合）→ DLG/CUTS、掃 assets-source/role 產圖片相對路徑映射（IMG，非 base64——
圖片直接參考專案素材）→ 注入 codex_template.html，產出 crystal_codex.html＋可 diff 的 data.json 快照。
發佈＝GitHub Actions（.github/workflows/codex.yml）在 push 後重跑本腳本並部署 GitHub Pages，
不再用 claude.ai Artifact。本地重跑本腳本即可預覽最新產出（見 tools/codex/README.md）。"""
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]  # tools/codex/ -> repo 根（跨機器可攜）
GODOT = REPO / "godot-project"
BATTLE = GODOT / "assets/battle"
CONTENT_DB = GODOT / "resources/content/content_db.tres"
DIALOGUE_DB = GODOT / "resources/content/dialogue/dialogue_db.tres"
UI = GODOT / "assets/ui"


# ── content_db.tres 解析 ──────────────────────────────────────────────
def godot_value(raw: str):
    raw = raw.strip()
    if raw in ("true", "false"):
        return raw == "true"
    if raw.startswith(("ExtResource", "SubResource")):
        return raw
    if raw.startswith(("[", "{", '"')):
        return json.loads(raw)  # 本檔的 dict/array/字串字面量皆為 JSON 相容格式
    try:
        return int(raw)
    except ValueError:
        return float(raw)


def parse_body(body: str) -> dict:
    props, lines, i = {}, body.splitlines(), 0
    while i < len(lines):
        m = re.match(r"^(\w+) = (.*)$", lines[i])
        if not m:
            i += 1
            continue
        key, val = m.groups()
        depth = sum(val.count(c) for c in "[{") - sum(val.count(c) for c in "]}")
        buf = [val]
        while depth > 0:
            i += 1
            buf.append(lines[i])
            depth += sum(lines[i].count(c) for c in "[{") - sum(lines[i].count(c) for c in "]}")
        props[key] = godot_value("\n".join(buf))
        i += 1
    return props


def parse_tres(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    body_text, res_sec = text.split("\n[resource]\n", 1)
    parts = re.split(r'\[sub_resource type="Resource" id="([^"]+)"\]', body_text)
    subs = {}
    for i in range(1, len(parts) - 1, 2):
        subs[parts[i]] = parse_body(parts[i + 1])

    def order(cat: str) -> list[str]:
        m = re.search(cat + r" = Array\[[^\]]*\]\(\[(.*?)\]\)", res_sec, re.S)
        if not m:
            sys.exit(f"[resource] 區找不到分類 {cat}")
        return re.findall(r'SubResource\("([^"]+)"\)', m.group(1))

    def single(cat: str) -> dict:
        rid = re.search(cat + r' = SubResource\("([^"]+)"\)', res_sec).group(1)
        return subs[rid]

    return subs, order, single


def to_int(v, default=0):
    return int(v) if v is not None else default


def build_game_json():
    subs, order, single = parse_tres(CONTENT_DB)

    def rows(cat):
        return [subs[rid] for rid in order(cat)]

    game = {}

    d = single("derived")
    camel = {
        "hp_base": "hpBase", "hp_per_str": "hpPerStr", "mp_base": "mpBase", "mp_per_int": "mpPerInt",
        "weapon_atk": "weaponAtk", "points_per_level": "pointsPerLevel",
        "skill_points_per_level": "skillPointsPerLevel", "skill_max_lv": "skillMaxLv",
        "skill_power_per_lv": "skillPowerPerLv", "exp_base": "expBase", "exp_coef": "expCoef",
        "exp_pow": "expPow", "matk_per_int": "matkPerInt", "mdef_per_int": "mdefPerInt",
        "dodge_per_agi": "dodgePerAgi", "dodge_cap": "dodgeCap", "crit_base": "critBase",
        "crit_per_agi": "critPerAgi",
    }
    game["derived"] = {camel[k]: v for k, v in d.items() if k in camel}

    p = single("pacing")
    game["pacing"] = {"partySize": to_int(p["party_size"]), "maps": p["maps"]}

    game["party"] = [{
        "id": r["id"], "name": r["display_name"], "cls": r["char_class"], "main": r["main_attr"],
        "lv": to_int(r.get("start_level"), 1), "guest": bool(r.get("guest")),
        "base": r["base"], "growth": r.get("growth"), "eq": r["start_eq"], "story": r["story"],
    } for r in rows("party")]

    game["skills"] = [{
        "id": r["id"], "name": r["display_name"], "cls": r["char_class"],
        "lv": to_int(r.get("unlock_lv"), 1), "mp": r["mp"], "kind": r["kind"], "attr": r["attr"],
        "mult": r["mult"], "flat": r["flat"], "target": r["target"],
    } for r in rows("skills")]

    game["equipment"] = [{
        "id": r["id"], "name": r["display_name"], "slot": r["slot"], "tier": to_int(r.get("tier"), 1),
        "buy": r.get("buy"), "sell": r.get("sell"), "stats": r.get("stats", {}),
        "desc": r.get("desc", ""), "attr": r.get("attr_type", ""), "rarity": r.get("rarity", "common"),
    } for r in rows("equipment")]

    game["items"] = [{
        "id": r["id"], "name": r["display_name"], "cat": r["cat"],
        "buy": r.get("buy"), "sell": r.get("sell"), "start": r.get("count"),
        "effect": r.get("effect", ""), "rarity": r.get("rarity", "common"),
        "baseDrop": r.get("base_drop_rate", 0),
    } for r in rows("items")]

    game["enemies"] = [{
        "id": r["id"], "name": r["display_name"], "spr": r["sprite"], "hp": r["hp"], "atk": r["atk"],
        "def": r["def_stat"], "spd": r["spd"], "exp": to_int(r.get("exp")), "gold": to_int(r.get("gold")),
        "big": bool(r.get("big")), "allAttack": bool(r.get("all_attack")), "healer": bool(r.get("healer")),
        "drops": [[x["id"], x["rate"]] for x in r.get("drops", [])],
        "foeSkills": r.get("foe_skills"),
    } for r in rows("enemies")]

    game["encounters"] = {r["map_id"]: r["formations"] for r in rows("encounters")}

    game["shops"] = [{
        "id": r["id"], "name": r["display_name"], "greet": r["greet"], "sells": r["sell_ids"],
    } for r in rows("shops")]

    game["chests"] = [{
        "id": r["id"], "map": r["map"], "tx": r["tx"], "ty": r["ty"], "tier": r["tier"],
        "loot": r["loot"],
    } for r in rows("chests")]

    return game


# ── 對話 .tres 解析（真相源＝dialogue/**/*.tres，取代舊 dialogue.json 種子）────────
def _dlg_str(raw: str):
    """tres 字串字面量（含引號）→ python 字串；tres 逃逸與 JSON 相容。"""
    return json.loads(raw)


def _packed(raw: str) -> list:
    """PackedStringArray("a","b") → ["a","b"]；PackedStringArray() → []。"""
    m = re.match(r"PackedStringArray\((.*)\)\s*$", raw, re.S)
    if not m:
        sys.exit(f"無法解析 PackedStringArray：{raw!r}")
    inner = m.group(1).strip()
    return json.loads("[" + inner + "]") if inner else []


def _opt(props: dict, key: str):
    """省略或空字串 → None，還原舊 json 的 null 語意（template 靠 null 判斷有無此欄）。"""
    return (_dlg_str(props[key]) or None) if key in props else None


def _dlg_props(body: str) -> dict:
    """對話 .tres 每行 `key = value` 皆單行，逐行取原始右值字串。"""
    return dict(re.findall(r"^(\w+) = (.*)$", body, re.M))


def _split_tres(path: pathlib.Path):
    """切出 sub_resource(id→props) 與 [resource] props。"""
    text = path.read_text(encoding="utf-8")
    if "\n[resource]\n" not in text:
        sys.exit(f"{path} 缺少 [resource] 區")
    head, res = text.split("\n[resource]\n", 1)
    parts = re.split(r'\[sub_resource type="Resource" id="([^"]+)"\]', head)
    subs = {parts[i]: _dlg_props(parts[i + 1]) for i in range(1, len(parts) - 1, 2)}
    return subs, _dlg_props(res)


def _order(raw: str) -> list[str]:
    """Array[...]([SubResource("a"), SubResource("b")]) → ["a","b"]（有序）。"""
    return re.findall(r'SubResource\("([^"]+)"\)', raw)


def build_dialogue() -> dict:
    """解析 dialogue_db.tres → 依聚合順序組出 {dlg, cuts}，結構同舊 dialogue.json。"""
    db = DIALOGUE_DB.read_text(encoding="utf-8")
    ext = {eid: rel for rel, eid in re.findall(
        r'\[ext_resource type="Resource" path="res://([^"]+)" id="([^"]+)"\]', db)}
    res = db.split("\n[resource]\n", 1)[1]

    def paths(key: str) -> list[pathlib.Path]:
        m = re.search(key + r" = Array\[[^\]]*\]\(\[(.*?)\]\)", res, re.S)
        if not m:
            sys.exit(f"dialogue_db.tres [resource] 找不到 {key}")
        return [GODOT / ext[e] for e in re.findall(r'ExtResource\("([^"]+)"\)', m.group(1))]

    dlg = {}
    for path in paths("npcs"):
        subs, r = _split_tres(path)
        dlg[_dlg_str(r["id"])] = [{
            "when": _dlg_str(s["when"]) if "when" in s else "always",
            "speaker": _dlg_str(s["speaker"]) if "speaker" in s else "",
            "lines": _packed(s.get("lines", "PackedStringArray()")),
            "action": _opt(s, "action"), "cmd": _opt(s, "cmd"),
            "label": _opt(s, "label"), "done": _opt(s, "done"),
        } for s in (subs[sid] for sid in _order(r["entries"]))]

    cuts = {}
    for path in paths("cutscenes"):
        subs, r = _split_tres(path)
        step = int(r["setstep"]) if "setstep" in r else -1
        transfer = _packed(r["transfer"]) if "transfer" in r else []
        party = _packed(r["party"]) if "party" in r else []
        cuts[_dlg_str(r["id"])] = {
            "once": _opt(r, "once"),
            "lines": [{
                "speaker": _dlg_str(s["speaker"]) if "speaker" in s else "",
                "text": _dlg_str(s["text"]) if "text" in s else "",
            } for s in (subs[sid] for sid in _order(r["lines"]))],
            "battle": _opt(r, "battle"),
            "transfer": transfer or None,
            "setstep": step if step >= 0 else None,
            "party": party or None,
        }
    return {"dlg": dlg, "cuts": cuts}


# ── 圖片：掃 assets-source/role 目錄，逐 id 收 face/portrait/battle_idle/bounty/combat ──
# html 在 tools/codex/，故相對路徑走 ../../assets-source/role/…；GitHub Pages 從 repo root
# 服務時同一相對路徑亦成立。有就收、缺就略——template 靠 face_/p_/bi_/bounty_/combat_ 這些
# key 掛圖（key 的 id ＝ role 子資料夾名，需與遊戲 party/enemy id 對得上）。
ROLE = REPO / "assets-source/role"
ROLE_REL = "../../assets-source/role"


def build_img():
    img = {}
    for sub in ("main", "npc", "enemies"):
        base = ROLE / sub
        if not base.is_dir():
            continue
        for d in sorted(p for p in base.iterdir() if p.is_dir()):
            rid = d.name
            rel = f"{ROLE_REL}/{sub}/{rid}"
            if (d / f"face_{rid}.png").exists():
                img[f"face_{rid}"] = f"{rel}/face_{rid}.png"
            if (d / f"portrait_{rid}.png").exists():
                img[f"p_{rid}"] = f"{rel}/portrait_{rid}.png"
            if (d / f"menuart_{rid}.png").exists():
                img[f"mn_{rid}"] = f"{rel}/menuart_{rid}.png"
            if (d / f"bounty_{rid}.png").exists():
                img[f"bounty_{rid}"] = f"{rel}/bounty_{rid}.png"
            if (d / "combat_0.png").exists():
                img[f"combat_{rid}"] = f"{rel}/combat_0.png"
            bi = d / "battle_idle"
            if bi.is_dir():
                al = sorted(bi.glob(f"{rid}_battle_idle_alpha_*.png"))
                if al:
                    img[f"bi_{rid}"] = f"{rel}/battle_idle/{al[-1].name}"
    return img


# ── 組裝 ─────────────────────────────────────────────────────────────
def main():
    game = build_game_json()
    counts = {k: len(v) for k, v in game.items() if isinstance(v, list)}
    print("解析 content_db.tres：", counts)

    dlg = build_dialogue()
    print("解析對話 .tres：", {k: len(v) for k, v in dlg.items()})

    # 資料快照（不含圖、可 diff、進 git）：pre-commit hook 用此檔讓 .tres 資料與版控同步，
    # John 也能用 `git diff` 一眼看出「這次 commit 改了哪個數值」。務必保持 deterministic
    # （不放時間戳），否則每次重跑都變動、diff 失去意義。
    data_out = HERE / "data.json"
    data_out.write_text(
        json.dumps({"game": game, "dialogue": dlg}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    print(f"OK {data_out} ({data_out.stat().st_size / 1024:.0f} KB)")

    tpl = (HERE / "codex_template.html").read_text(encoding="utf-8")
    for token, payload in [("__IMG_JSON__", build_img()), ("__DLG_JSON__", dlg), ("__GAME_JSON__", game)]:
        if token not in tpl:
            sys.exit(f"模板缺少 {token} 佔位符")
        tpl = tpl.replace(token, json.dumps(payload, ensure_ascii=False, separators=(",", ":")))

    out = HERE / "crystal_codex.html"
    out.write_text(tpl, encoding="utf-8")
    print(f"OK {out} ({out.stat().st_size/1024:.0f} KB)")


if __name__ == "__main__":
    main()
