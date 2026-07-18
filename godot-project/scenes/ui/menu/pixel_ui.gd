class_name PixelUI
extends RefCounted

## 像素風選單的共用建構工具（角色選單重設 3a 版）。
##
## 設計稿把遊戲原生視覺 DNA（深藍紫漸層底、深色半透明面板、8 向描邊字、金/青/選取黃色票）套到
## 整套選單。這裡把那套視覺收斂成一組 static factory，供 menu_root 與各 page 程序化建節點時共用，
## 避免每頁各自寫死顏色/StyleBox（比照 menu_panel.gd 程序化建列的既有作法）。
##
## 色票對齊設計稿（見計畫 Context）；面板一律用 StyleBoxFlat（panel.png 是 78-byte 佔位檔，不可依賴）。
## 字型沿用 ui_theme.tres 的 CJK SystemFont，靠 outline_size 營造像素描邊感（設計稿的 DotGothic16／
## Press Start 2P 未內建、環境無法下載，為已知偏差）。

# --- 色票（設計稿 tokens）---
const GOLD := Color("ffe178")        # 標題/金幣/強調
const CYAN := Color("aadceb")        # 次要標籤/衍生值
const SEL := Color("ffeb78")         # 選取黃
const OUTLINE := Color("0a0a14")     # 描邊/硬邊框
const WHITE := Color("ffffff")
const DIM := Color("788296")         # 停用/佔位灰
const SUBTLE := Color("aab4dc")      # 欄位標籤淺藍
const GOOD := Color("78e68c")        # 屬性上升
const BAD := Color("ff9696")         # 屬性下降/危險
const HP := Color("d0584a")
const MP := Color("5aa0c8")
const PANEL_BG := Color(0.063, 0.070, 0.125, 0.86)   # ~rgba(16,18,32,.82)
const PANEL_BG2 := Color(0.117, 0.133, 0.211, 0.85)  # ~rgba(30,34,54,.85)
const CELL_BG := Color(0.039, 0.039, 0.078, 0.42)    # 內格底 rgba(10,10,20,.4)
const BAR_BG := Color(0.165, 0.180, 0.251)           # #2a2e40
const TOPBAR_BG := Color(0.047, 0.055, 0.102, 0.86)  # rgba(12,14,26,.82)
const BORDER := Color(0.275, 0.314, 0.478)           # #46507a 面板亮邊
const INNER := Color(0.478, 0.549, 0.784, 0.22)      # 內側 2px 高光

const F_TITLE := 26
const F_NAME := 24
const F_ROW := 17
const F_SMALL := 14
const F_TINY := 12


## 描邊 Label（8 向描邊感 → Godot outline）。size/color 可調；預設白字。
static func label(text: String, size: int = F_ROW, color: Color = WHITE, outline_px: int = 4) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", outline_px)
	lbl.add_theme_color_override("font_outline_color", OUTLINE)
	return lbl


## 面板底（深色半透明 + 硬邊框 + 內側高光）。border_px<=0 則無邊。
static func panel_style(fill: Color = PANEL_BG, border_px: int = 3, border_col: Color = OUTLINE, inner: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	if border_px > 0:
		sb.set_border_width_all(border_px)
		sb.border_color = border_col
	if inner:
		# 內側高光靠額外 expand 難做，改用第二層邊近似：這裡只給外硬邊，內光交由呼叫端疊 ColorRect（多數情況省略）。
		pass
	sb.set_corner_radius_all(0)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


## 一個套好底的 PanelContainer。
static func panel(fill: Color = PANEL_BG, border_px: int = 3, border_col: Color = OUTLINE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(fill, border_px, border_col))
	return p


## 選取高亮底（選取黃邊 + 微亮底）。
static func selected_style(strong: bool = true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.235, 0.251, 0.353, 0.55) if strong else Color(0.078, 0.086, 0.149, 0.55)
	sb.set_border_width_all(2)
	sb.border_color = SEL if strong else BORDER
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## HP/MP 條（ProgressBar 套色）。w 給最小寬。
static func progress(color: Color, w: float = 170.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, 16)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	bg.set_border_width_all(2)
	bg.border_color = OUTLINE
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fg)
	return pb


## 像素按鈕（btn 底 + 描邊字色）。用於 使用/升級/裝備/卸下/存讀 等。
static func button(text: String, color: Color = GOLD, size: int = F_ROW) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_pressed_color", WHITE)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.19, 0.25, 0.39, 0.96)   # 可見的藍灰（繼續按鈕太黑→換色；共用鈕一起改）
	normal.set_border_width_all(2)
	normal.border_color = OUTLINE
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.27, 0.34, 0.50, 0.98)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.098, 0.110, 0.157, 0.9)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("disabled", disabled)
	return b


## 小標籤 chip（部位/元素/種類 tag）。
static func chip(text: String, color: Color = SUBTLE, size: int = F_TINY) -> PanelContainer:
	var p := panel(Color(0.039, 0.039, 0.078, 0.35), 2, BORDER)
	var st := p.get_theme_stylebox("panel") as StyleBoxFlat
	st.content_margin_left = 7
	st.content_margin_right = 7
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	var l := label(text, size, color, 3)
	p.add_child(l)
	return p


## slot 佔位圖示（設計用 SVG，環境無 emoji 字型會豆腐 → 改用 CJK 單字縮寫，SystemFont 必能顯示）。
const SLOT_GLYPH := {
	"weapon": "武", "armor": "防", "boots": "靴", "wrist": "腕", "acc": "飾",
}


static func slot_icon(slot: String, size: int = 32) -> PanelContainer:
	var p := panel(Color(0.039, 0.039, 0.078, 0.5), 2, BORDER)
	var st := p.get_theme_stylebox("panel") as StyleBoxFlat
	st.content_margin_left = 2
	st.content_margin_right = 2
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	p.custom_minimum_size = Vector2(size, size)
	var l := label(String(SLOT_GLYPH.get(slot, "◆")), int(size * 0.5), CYAN, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## 佔位字（無資料欄位統一顯示「—」灰字）。
static func placeholder(size: int = F_ROW) -> Label:
	return label("—", size, DIM)
