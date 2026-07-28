extends RefCounted
class_name ExpNeed

## F-2　升級所需經驗（specs/BATTLE_FORMULAS.md F-2）。
##
## **真相源＝`resources/content/exp_table.json` 的 100 級經驗表**（2026-07-28 John 定案，spec v5.0）：
## 表是用 `round(100 * lv^1.7)` 產出來的，但**之後以表內數值為準**——調某幾級的曲線直接改 JSON，不用回頭
## 改公式。原本的 `derived.tres` 三參數（`exp_base`/`exp_coef`/`exp_pow`，對應 build_cq2.py `expNeed(lv)`
## WORLD L1325 / BATTLE L2662）降為**表讀不到時的 fallback**，不再是正常路徑。
##
## 滿級（表的最後一級，目前 Lv100）`required_exp = 0`，本函式回傳 0＝「不會再升級」。
## **呼叫端的升級迴圈必須把 0 當終止條件**（`while need > 0 and exp >= need`），否則會無限迴圈——
## 見 scripts/battle/battle_state_machine.gd `_settle_win()`。

const TABLE_PATH := "res://resources/content/exp_table.json"

## 各級 required_exp（index 0 = Lv1）。第一次呼叫時載入；空的代表載入失敗、走 fallback 公式。
static var _required: PackedInt32Array = PackedInt32Array()
static var _loaded := false


## Lv `lv` 升到 `lv+1` 所需經驗；滿級（含超過表範圍）回傳 0。
static func exp_need(lv: int) -> int:
	_ensure_loaded()
	if _required.is_empty():
		# fallback：經驗表讀不到時退回 build_cq2.py 的舊公式，讓遊戲還能跑（_ensure_loaded 已報錯）。
		var d: DerivedParams = ContentDB.get_derived()
		return int(d.exp_base + round(d.exp_coef * pow(float(lv), d.exp_pow)))
	var i := maxi(1, lv) - 1
	if i >= _required.size():
		return 0
	return _required[i]


## 滿級等級（經驗表最後一級）。表讀不到時回傳 0＝「沒有上限」。
static func max_level() -> int:
	_ensure_loaded()
	return _required.size()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(TABLE_PATH):
		push_error("ExpNeed: 找不到經驗表 %s，退回 derived.tres 舊公式" % TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY or typeof(parsed.get("levels")) != TYPE_ARRAY:
		push_error("ExpNeed: 經驗表格式不符（缺 levels 陣列），退回 derived.tres 舊公式")
		return
	var rows: Array = parsed["levels"]
	var out := PackedInt32Array()
	out.resize(rows.size())
	for row in rows:
		if typeof(row) != TYPE_DICTIONARY:
			continue
		var lv := int(row.get("level", 0))
		if lv >= 1 and lv <= out.size():
			out[lv - 1] = int(row.get("required_exp", 0))
	_required = out
