class_name PortraitMap
extends RefCounted
## 對話說話者「顯示名」→ 對話立繪 id 的對照表。
##
## 權威來源：build_cq2.py L1407-1409 的 `FACE` 物件（顯示名 → 立繪 id），由 setFace(nm) L1410-1421
## 以「當前說話者的顯示名」查表切立繪。Godot 端 DialogueSystem 的 signal 帶的 speaker 就是顯示名
## （dlg 的 entry.speaker、cuts 每行的 speaker），故直接沿用同一份對照，NPC 對話與過場共用。
##
## 對應素材：res://assets/ui/portrait_<id>.png（id 取自 build_cq2.py L521 FACE_IDS，共 13 個）。
## 查不到（旁白 speaker==""、或「？？？」等無立繪角色）回傳空字串，呼叫端不顯示立繪
## （比照 build_cq2.py L1416「無對應立繪（旁白等）→ 不顯示」）。

const FACE := {
	"路德": "ludo",
	"瑪琳": "marin",
	"亞倫": "alan",
	"緹娜": "tina",
	"朵拉": "dora",
	"希雅修女": "shea",
	"巴頓鎮長": "barton",
	"吉德": "gid",
	"漢克": "hank",
	"瑪莎": "martha",
	"老葛雷": "gray",
	"米拉": "mira",
	"羅素隊長": "rossel",
	"死靈術士": "necro",
}


## 顯示名 → 立繪 id；查不到回 ""（不顯示立繪）。
static func portrait_id(speaker: String) -> String:
	return FACE.get(speaker, "")
