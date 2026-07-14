class_name CqMenuPanel
extends Control

## 選單／商店共用的面板渲染器（對應 build_cq2.py 的 renderPanel()，L1874-1916）。
##
## 職責：管理 20 列文字（MRow0-19）、一組血條（BarBg/BarFill）、選取列高亮（RowHi）、
## 標題（MenuTitle）／分頁列（MenuTab）／提示（MenuHint）的顯示。menu_root.gd 與 shop.gd 各自組出
## rows/bars/opt 資料，統一丟給 render() 畫出，跟原版一樣「一份面板兩處共用」。
##
## 座標系統：照 build_cq2 的作法用「全螢幕絕對座標」（rows 的 x/y 直接是 1280x720 內的像素位置，
## 見原版 renderPanel 的 ro.setX/setY），所以 Rows/Bars 容器都是滿版 (0,0) 對齊，行資料的 x/y 原封
## 不動照抄自 build_cq2，不用換算。
##
## 美術：目前用 ColorRect + 主題色畫面板底/血條/高亮（assets/ui/*.png 尚未由 Godot 編輯器產生 .import，
## 無法在無編輯器環境以 ext_resource 載入紋理——現有世界場景 .tscn 同樣未引用任何紋理）。等資產匯入後
## 可把 Frame/RowHi/血條換成 panel.png/rowhi.png/bar_*.png 紋理，資料與版面不需要改。見任務報告。
##
## 顏色一律讀主題（type "CQ"，見 resources/ui_theme.tres），不寫死。

const ROW_COUNT := 20
const BAR_COUNT := 12

var col_accent: Color
var col_gold: Color
var col_dim: Color
var col_text: Color
var col_good: Color
var col_warn: Color
var col_hp: Color
var col_mp: Color

@onready var _frame: ColorRect = $Frame
@onready var _title: Label = $Title
@onready var _tab: Label = $Tab
@onready var _hint: Label = $Hint
@onready var _rowhi: ColorRect = $RowHi
@onready var _rows_root: Control = $Rows
@onready var _bars_root: Control = $Bars

var _row_nodes: Array[Label] = []
var _bar_nodes: Array = []   # 每格：{ "ctrl": Control, "bg": ColorRect, "fill": ColorRect }


func _ready() -> void:
	col_accent = get_theme_color("accent", "CQ")
	col_gold = get_theme_color("gold", "CQ")
	col_dim = get_theme_color("dim", "CQ")
	col_text = get_theme_color("text", "CQ")
	col_good = get_theme_color("good", "CQ")
	col_warn = get_theme_color("warn", "CQ")
	col_hp = get_theme_color("hp", "CQ")
	col_mp = get_theme_color("mp", "CQ")

	_frame.color = get_theme_color("panel_bg", "CQ")
	_rowhi.color = get_theme_color("row_hi", "CQ")
	_title.add_theme_color_override("font_color", col_gold)
	_tab.add_theme_color_override("font_color", col_accent)
	_hint.add_theme_color_override("font_color", Color(0.6667, 0.7059, 0.8627))

	for i in ROW_COUNT:
		var lbl := Label.new()
		lbl.name = "MRow%d" % i
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rows_root.add_child(lbl)
		_row_nodes.append(lbl)

	for i in BAR_COUNT:
		var ctrl := Control.new()
		ctrl.name = "Bar%d" % i
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := ColorRect.new()
		bg.name = "Bg"
		bg.color = get_theme_color("bar_bg", "CQ")
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(bg)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.add_child(fill)
		_bars_root.add_child(ctrl)
		_bar_nodes.append({"ctrl": ctrl, "bg": bg, "fill": fill})

	hide()


## 對應 renderPanel(rows,barsp,opt)。
## rows：Array[Dictionary]，每列 {t:String, x?:float, y?:float, c?:Color, sel?:bool, hw?:float}。
##   省略 c → 用預設 text 色；sel==true → 用 accent 色並畫高亮列（只取第一個 sel 列）。
## bars：Array[Dictionary]，每條 {x,y,w,cur,max,kind("hp"/"mp")}。
## opt：{title:String, tab?:String, hint:String}。
func render(rows: Array, bars: Array, opt: Dictionary) -> void:
	visible = true
	_title.text = String(opt.get("title", "選單"))

	if opt.has("tab") and opt["tab"] != null:
		_tab.visible = true
		_tab.text = String(opt["tab"])
	else:
		_tab.visible = false

	_hint.text = String(opt.get("hint", "")) + "　　金幣 " + str(GameState.gold)

	var has_hi := false
	var hi_x := 0.0
	var hi_y := 0.0
	var hi_w := 0.0
	for i in ROW_COUNT:
		var lbl := _row_nodes[i]
		var r = rows[i] if i < rows.size() else null
		if r != null and r is Dictionary and not (r as Dictionary).is_empty():
			var rd: Dictionary = r
			lbl.visible = true
			lbl.text = String(rd.get("t", ""))
			var rx := float(rd.get("x", 200))
			var ry := float(rd.get("y", 176 + i * 28))
			lbl.position = Vector2(rx, ry)
			var sel := bool(rd.get("sel", false))
			var c: Color = col_accent if sel else rd.get("c", col_text)
			lbl.add_theme_color_override("font_color", c)
			if sel and not has_hi:
				has_hi = true
				hi_x = rx
				hi_y = ry
				hi_w = float(rd.get("hw", 640))
		else:
			lbl.visible = false

	_rowhi.visible = has_hi
	if has_hi:
		_rowhi.position = Vector2(hi_x - 16, hi_y - 2)
		_rowhi.size = Vector2(hi_w, 28)

	for i in BAR_COUNT:
		var slot: Dictionary = _bar_nodes[i]
		if i < bars.size():
			var bp: Dictionary = bars[i]
			slot["ctrl"].visible = true
			var bx := float(bp.get("x", 0))
			var by := float(bp.get("y", 0))
			var bw := float(bp.get("w", 0))
			var bmax := float(bp.get("max", 0))
			var bcur := float(bp.get("cur", 0))
			var ratio := clampf(bcur / bmax, 0.0, 1.0) if bmax > 0.0 else 0.0
			slot["bg"].position = Vector2(bx - 2, by - 2)
			slot["bg"].size = Vector2(bw + 4, 14)
			slot["fill"].position = Vector2(bx, by)
			slot["fill"].size = Vector2(maxf(1.0, round(bw * ratio)), 10)
			slot["fill"].color = col_hp if String(bp.get("kind", "hp")) == "hp" else col_mp
		else:
			slot["ctrl"].visible = false


## 收起整個面板（對應 build_cq2 選單/商店關閉時把 MenuPanel/MRow…全部 hide 的那段，L2231-2236）。
func close_panel() -> void:
	hide()
