extends CanvasLayer
## shop.tscn 的控制腳本 —— 商店 UI（買/賣兩頁籤）。
##
## build_cq2.py 商店段落（openShop L1298-1300、else if(st.shop){…} L2167-2230）的 Godot 移植。
## 沿用選單的共用面板 CqMenuPanel（原版註解：「商店（買/賣兩頁籤，複用選單面板元件）」）。
##
## 觸發：監聽 DialogueSystem.shop_requested(shop_id)（對話 action shop_gid/shop_hank 等會發此訊號，
## 見 dialogue_system.gd _run_action）。開店時關閉選單（對應 openShop 的 st.menu=false）。
##
## 只做「現有已實作」的商店功能（見 TASKS/04_選單UI.md 已知風險）：買/賣道具與裝備。tier>=2 的第二章
## 進貨閘門照原版保留（目前恆未進貨，因為沒有 ch2 旗標），但不新增任何第二章專屬商店功能。
##
## 資料/狀態異動：讀 ContentDB.get_shop()/get_item()/get_equipment()；買賣改 GameState.gold 與
## eq_inv/inv_add/inv_use，成交後透過 SaveManager（若已註冊）自動存檔（對應原版每筆成交 saveGame()）。
## 輸入走 CORE-6 InputBridge：move_left/right 切買賣、move_up/down 選、ui_accept 成交、ui_cancel 離開。

signal shop_opened
signal shop_closed

const CATN := {"consumable": "消耗", "material": "素材", "key": "重要"}
const SLOTN := {"weapon": "武器", "armor": "防具", "boots": "靴子", "wrist": "護腕", "acc": "飾品"}
const EQSTAT_N := {"patk": "物攻", "matk": "魔攻", "pdef": "物防", "mdef": "魔防", "dodge": "閃避", "crit": "會心", "hp": "生命", "mp": "法力"}
const C_NO_AFFORD := Color(0.667, 0.549, 0.549)   # 170;140;140

@onready var _panel: CqMenuPanel = $Panel

var _open := false
var _shop_id := ""
var _tab := 0        # 0=購買 1=販售
var _sel := 0
var _msg := ""


func _ready() -> void:
	add_to_group("cq_shop")
	DialogueSystem.shop_requested.connect(_on_shop_requested)


func is_open() -> bool:
	return _open


func _hit(action: String) -> bool:
	return InputBridge.is_action_hit(action)


func _on_shop_requested(shop_id: String) -> void:
	open_shop(shop_id)


## 對應 openShop(id)（L1298-1300）：設定商店狀態、關閉選單。
func open_shop(shop_id: String) -> void:
	_shop_id = shop_id
	_tab = 0
	_sel = 0
	_msg = ""
	_open = true
	var mnode := get_tree().get_first_node_in_group("cq_menu")
	if mnode != null and mnode.has_method("force_close"):
		mnode.force_close()
	shop_opened.emit()


func _close_shop() -> void:
	_open = false
	_panel.close_panel()
	shop_closed.emit()


func _process(_delta: float) -> void:
	if not _open:
		return
	if not ContentDB.is_loaded:
		return

	var shop: ShopDef = ContentDB.get_shop(_shop_id)
	var shop_name := shop.display_name if shop != null else "商店"

	# 買清單：shop.sell 的 id → 中繼資料；tier>=2 需 ch2（目前恆未進貨），對應 L2172-2175。
	var buy_list: Array = []
	if shop != null:
		var ch2 := GameState.flag_get("ch2")
		for sid in shop.sell_ids:
			var bm := _item_meta(String(sid))
			if bm.is_empty():
				continue
			if int(bm.get("tier", 0)) >= 2 and ch2 == 0:
				continue
			buy_list.append(bm)

	# 賣清單：背包內 sell>0 的道具 ＋ 裝備袋內 sell>0 的裝備，對應 L2176-2183。
	var sell_list: Array = []
	var iv: Dictionary = GameState.inv_all()
	for it_def in ContentDB.get_all_items():
		var q := int(iv.get(it_def.id, 0))
		if q > 0:
			var sm := _item_meta(String(it_def.id))
			if not sm.is_empty() and int(sm.get("sell", 0)) > 0:
				sm["count"] = q
				sell_list.append(sm)
	var ecnt := {}
	var euniq: Array = []
	for eid in GameState.eq_inv:
		if ContentDB.get_equipment(String(eid)) == null:
			continue
		if not ecnt.has(eid):
			ecnt[eid] = 0
			euniq.append(eid)
		ecnt[eid] = int(ecnt[eid]) + 1
	for eid in euniq:
		var sm2 := _item_meta(String(eid))
		if not sm2.is_empty() and int(sm2.get("sell", 0)) > 0:
			sm2["count"] = int(ecnt[eid])
			sell_list.append(sm2)

	# ---- 輸入（L2184-2209）----
	if _hit("move_left") or _hit("move_right"):
		_tab = _tab ^ 1
		_sel = 0
		_msg = ""
	var list: Array = buy_list if _tab == 0 else sell_list
	if _sel >= list.size():
		_sel = max(0, list.size() - 1)
	if _hit("move_up") and _sel > 0:
		_sel -= 1
		_msg = ""
	if _hit("move_down") and _sel < list.size() - 1:
		_sel += 1
		_msg = ""
	if _hit("ui_cancel"):
		_close_shop()
		return
	elif _hit("ui_accept") and _sel < list.size():
		_do_transaction(list[_sel], list)

	if not _open:
		return
	_render(buy_list, sell_list, shop_name)


## 對應成交邏輯 L2192-2209。tr 是 _item_meta 產出的中繼資料，list 是成交當下的清單（供賣出後 sel 夾動）。
func _do_transaction(tr: Dictionary, list: Array) -> void:
	var gold := GameState.gold
	if _tab == 0:
		var buy := int(tr.get("buy", 0))
		if buy <= 0:
			_msg = "這件不賣。"
		elif gold < buy:
			_msg = "金幣不足！"
		else:
			GameState.gold = gold - buy
			if String(tr.get("kind", "")) == "eq":
				GameState.eq_inv.append(tr["id"])
			else:
				GameState.inv_add(String(tr["id"]), 1)
			_msg = "購買了 " + String(tr["name"]) + "（-" + str(buy) + "G）"
	else:
		var sell := int(tr.get("sell", 0))
		GameState.gold = gold + sell
		if String(tr.get("kind", "")) == "eq":
			GameState.eq_inv.erase(tr["id"])
		else:
			GameState.inv_use(String(tr["id"]))
		_msg = "賣出 " + String(tr["name"]) + "（+" + str(sell) + "G）"
		# 對應 L2206：賣掉的是最後一列時游標上移（用成交當下的 list 長度判斷，跟原版一致）。
		if _sel > 0 and _sel >= list.size() - 1:
			_sel -= 1
	_try_save()


## 對應渲染段落 L2211-2229。
func _render(buy_list: Array, sell_list: Array, shop_name: String) -> void:
	var rows: Array = []
	var vlist: Array = buy_list if _tab == 0 else sell_list
	# maxi/mini（回傳 int）而非 max/min（回傳 Variant）：本專案把「型別從 Variant 推斷」當 error。
	var base := maxi(0, mini(_sel - 5, vlist.size() - 11))
	if base < 0:
		base = 0
	if vlist.size() == 0:
		rows.append({"t": ("（目前沒有進貨的商品）" if _tab == 0 else "（沒有可販售的道具或裝備）"), "c": _panel.col_dim, "x": 180, "y": 214})
	var i := base
	while i < vlist.size() and i < base + 11:
		var vi: Dictionary = vlist[i]
		if _tab == 0:
			var owned := GameState.inv_get(String(vi["id"])) if String(vi.get("kind", "")) == "item" else 0
			var afford := GameState.gold >= int(vi.get("buy", 0))
			var owned_str := ("（持有 " + str(owned) + "）") if owned > 0 else ""
			var row := {"t": ("▶ " if i == _sel else "　 ") + "［" + String(vi["label"]) + "］" + String(vi["name"]) + "　" + str(int(vi.get("buy", 0))) + "G" + owned_str, "sel": i == _sel, "x": 180, "y": 206 + (i - base) * 26, "hw": 920}
			if not afford:
				row["c"] = C_NO_AFFORD
			rows.append(row)
		else:
			rows.append({"t": ("▶ " if i == _sel else "　 ") + "［" + String(vi["label"]) + "］" + String(vi["name"]) + "　×" + str(int(vi.get("count", 0))) + "　售 " + str(int(vi.get("sell", 0))) + "G", "sel": i == _sel, "x": 180, "y": 206 + (i - base) * 26, "hw": 920})
		i += 1
	if _sel < vlist.size():
		var desc := String(vlist[_sel].get("desc", ""))
		rows.append({"t": "　" + (desc if desc != "" else "（無說明）"), "c": _panel.col_accent, "x": 180, "y": 508, "hw": 960})
	var tab_str := ("【購買】" if _tab == 0 else " 購買 ") + "　" + ("【販售】" if _tab == 1 else " 販售 ")
	var hint := (_msg + "　　" if _msg != "" else "") + "←→ 買/賣　↑↓ 選　Enter 成交　Esc 離開"
	_panel.render(rows, [], {"title": shop_name, "tab": tab_str, "hint": hint})


## 對應 itemMeta(id)（L1316-1322）：統一取任一 id（道具或裝備）的商店中繼資料。
func _item_meta(id: String) -> Dictionary:
	var it: ItemDef = ContentDB.get_item(id)
	if it != null:
		# ItemDef 無 tier 欄位（第一章道具皆 tier<2），tier 給 0 即「不受 ch2 閘門擋」，與原版
		# bm.tier 為 undefined→falsy 的效果一致。
		return {"id": id, "name": it.display_name, "buy": it.buy, "sell": it.sell, "cat": it.cat, "kind": "item", "tier": 0, "label": String(CATN.get(it.cat, "道具")), "desc": it.effect}
	var e: EquipmentDef = ContentDB.get_equipment(id)
	if e != null:
		return {"id": id, "name": e.display_name, "buy": e.buy, "sell": e.sell, "slot": e.slot, "kind": "eq", "tier": e.tier, "label": String(SLOTN.get(e.slot, "裝備")), "desc": _eq_desc(e)}
	return {}


## 對應 eqDesc()（L1850-1854）：依 EQSTAT_N 順序列出非零屬性加成。
func _eq_desc(e: EquipmentDef) -> String:
	var out: Array = []
	for k in EQSTAT_N.keys():
		var v := e.get_stat(k)
		if v != 0.0:
			out.append(String(EQSTAT_N[k]) + "+" + _num(v))
	return " ".join(out)


func _num(v) -> String:
	var f := float(v)
	if is_equal_approx(f, round(f)):
		return str(int(round(f)))
	return str(f)


func _try_save() -> void:
	var save_mgr := get_node_or_null("/root/SaveManager")
	if save_mgr != null and save_mgr.has_method("save_game"):
		save_mgr.save_game()
