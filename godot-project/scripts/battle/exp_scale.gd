class_name ExpScale
extends RefCounted
## F-9　EXP 縮放係數（specs/BATTLE_FORMULAS.md F-9）。
##
## build_cq2.py 的 `EXPSCALE` 是 **build-time** 常數表（L3304-3317，Python 算完直接字串替換進
## JS），從未進入 `CONTENT.json` 本體，CORE-2 轉存 `content.json` 時也沒有帶這張表（已核對
## `sync_content.py`／`content_db.gd`／`resources/content/content.json`，確認沒有 `expScale`
## 這類欄位）。MOD-E 在自己擁有的檔案裡用**唯讀**查詢（`ContentDB.get_pacing()`/`get_encounter()`/
## `get_enemy()`、`ExpNeed.exp_need()`）現場算出等價值，不算「MOD 任務自己重算衍生屬性」那類被禁止的
## 行為（那條規則管的是 `derive()`，這裡是完全不同的一條 build-time 換算公式）。
##
## 若之後 CORE-2 任務負責者想把這張表移到轉存階段預先算好（跟原始碼設計更一致、也省下每次進戰鬥都要
## 重算一次），這裡的公式可以直接搬過去、`ContentDB` 加一個 `get_exp_scale(map_id)` 查詢介面，呼叫端
## （`battle_state_machine.gd`）改叫該介面即可，`compute()` 的簽名/回傳值語意不需要變。見
## specs/BATTLE_FORMULAS.md F-9「MOD-E 實作現況」一節。


## 算出 `map_id`（即 `GameState.encounter`）對應的 EXP 縮放係數。`map_id` 不在
## `CONTENT.pacing.maps` 裡（例如 `ch1_boss`/`ch2_bear`/`prologue_demon` 這類特殊戰鬥）時回傳
## `1.0`，效果等同原始碼「`EXPSCALE[b.enc]` 是 `undefined` 時不縮放」。
static func compute(map_id: String) -> float:
	var pacing: PacingParams = ContentDB.get_pacing()
	var cfg: Dictionary = pacing.get_map(map_id)
	if cfg.is_empty():
		return 1.0

	var enc: EncounterDef = ContentDB.get_encounter(map_id)
	if enc == null or enc.formations.is_empty():
		return 1.0

	# formations v2（F-11）：每組期望 EXP = Σ member(期望隻數 × 單隻 EXP)，各組再依 weight 加權平均。
	# member 全填 min=max、weight 省略時，等價於舊「各組固定編成 EXP 的算術平均」。
	var acc := 0.0
	var total_w := 0.0
	for f in enc.formations:
		if typeof(f) != TYPE_DICTIONARY:
			continue
		var w: float = maxf(0.0, float(f.get("weight", 1.0)))
		var group_exp := 0.0
		for m in f.get("members", []):
			if typeof(m) != TYPE_DICTIONARY:
				continue
			var ed: EnemyDef = ContentDB.get_enemy(String(m.get("id", "")))
			if ed != null:
				var lo := int(m.get("min", 1))
				var hi := int(m.get("max", lo))
				group_exp += float(ed.exp) * float(lo + hi) * 0.5
		acc += w * group_exp
		total_w += w
	var avg: float = (acc / total_w) if total_w > 0.0 else 0.0
	if avg <= 0.0:
		return 1.0

	var entry_lv: int = int(cfg.get("entryLv", 1))
	var target_lv: int = int(cfg.get("targetLv", entry_lv))
	var need := 0
	# Python `range(entryLv, targetLv)`：不含 targetLv 本身
	for lv in range(entry_lv, target_lv):
		need += ExpNeed.exp_need(lv)

	var party: int = int(cfg.get("party", pacing.party_size))
	var battles: int = int(cfg.get("battles", 1))
	if battles <= 0:
		return 1.0

	var raw: float = float(party) * float(need) / (float(battles) * avg)
	return roundf(raw * 1000.0) / 1000.0
