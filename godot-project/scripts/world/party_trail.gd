extends RefCounted
class_name PartyTrail

## MOD-C 產出：隊伍跟隨（trail）邏輯。
##
## 對應 build_cq2.py:2272-2296（`st.trail`/`fobjs` 段落）與 DEV_開發指南.md L55「隊伍跟隨（trail）」。
##
## 演算法照抄原始碼的資料結構/取樣規則（不是逐行翻譯 JS，是重建同一套語意）：
## - `trail`：領隊（Player）歷史位置點陣列（含當時面向），開場塞滿 `history_size`（原始碼固定 160）
##   個起始點，避免陣列未滿時 index 越界（對應 build_cq2.py:2276 `if(!st.trail){...for i<160...}`）。
## - 領隊移動距離平方 >= `min_step_sq`（原始碼固定 16，即 4px）才記一個新點，插入陣列頭部，超過
##   `history_size` 就丟棄尾端最舊的點（對應 build_cq2.py:2279
##   `if(mdx*mdx+mdy*mdy>=16){st.trail.unshift(...);if(st.trail.length>160)st.trail.pop();}`）——
##   不是每個 physics frame 都記錄，避免站著不動時陣列塞滿重複點。
## - 每個跟隨者的取樣 index = `min(trail.size()-1, rank * step_per_follower)`，`rank` 從 1 起算
##   （原始碼 `for(var i=1;i<ps9.length&&i<4;i++)`，領隊本身 rank 0 不經過這個陣列，呼叫端直接讀
##   領隊目前位置），`step_per_follower` 原始碼固定 13（對應 build_cq2.py:2289
##   `var idx=Math.min(st.trail.length-1,i*13);`）。
##
## 跟 GDevelop 版的刻意差異：原始碼在同一段迴圈裡把「記錄取樣點」跟「決定哪個 Follower 物件要
## hide/顯示哪個 sprite」（`FSPRITES` 白名單、`fobjs` 物件池數量）混在一起，因為那些都是當時場景/
## 角色資料決定的。這裡刻意拆開，本檔案只管「取樣點在哪裡」，不管「哪個隊伍成員配哪個節點/貼圖」
## ——那屬於呈現層，等 MOD-H 世界場景/角色渲染接上時才決定要幾個跟隨者節點、綁哪個角色的動畫，本檔案
## 保持純邏輯、脫離 Node，方便單元測試（見下方 Python 交叉驗證）。
##
## 用 `RefCounted`（不是 `Node`）：不需要進場景樹、不需要 `_process`，世界場景根節點在 `_ready()`
## `PartyTrail.new()` 建立一份、每個 physics frame 呼叫 `update_leader()` 即可。

## 歷史位置點上限，對應原始碼固定 160。
## 不用 `@export`：本類別 `extends RefCounted`（不是 Node/Resource），沒有 Inspector 可以編輯，
## `@export` 在這裡不會有實際效果，用一般 `var` 搭配預設值即可（呼叫端要覆寫照樣直接賦值）。
var history_size: int = 160

## 4px 的平方（原始碼固定 16），跟原始碼一致用平方距離比較，省開根號。
var min_step_sq: float = 16.0

## 每個跟隨者之間的取樣點間隔。原版是 13；目前縮短為一半（6.5）。
var step_per_follower: float = 6.5

## 最多跟隨者數，對應原始碼 `i<4`（i 從 1 起算，最多 3 個跟隨者：ps9[1]/ps9[2]/ps9[3]）。
var max_followers: int = 3

## Array[Dictionary]，每個元素 `{"pos": Vector2, "facing": String}`，index 0 是最新記錄的點。
var _trail: Array = []


## 用領隊起始位置塞滿整個歷史陣列（對應原始碼 `for(var i=0;i<160;i++)st.trail.push(...)`）。
## 世界場景進場/玩家傳送後應該呼叫一次，避免跟隨者從舊位置「飛」過來。
func reset(start_pos: Vector2, start_facing: String = "Down") -> void:
	_trail.clear()
	for _i in range(history_size):
		_trail.append({"pos": start_pos, "facing": start_facing})


## 每個 physics frame 由世界場景控制器（或 player_controller 本身）呼叫一次，餵入領隊目前位置/面向。
## 尚未 `reset()` 過時，第一次呼叫會自動用當下位置初始化（等同原始碼 `if(!st.trail)` 分支，
## 塞滿陣列的初始面向固定用 `reset()` 的預設值 "Down"，**不是**這一幀傳進來的 `facing`——照抄
## build_cq2.py:2276 `st.trail.push([p.getX(),p.getY(),"Down"])` 寫死 "Down" 的行為，不是隨意選擇。
## 交叉驗證見 scratchpad `verify_trail.py`：一開始曾誤寫成 `reset(pos, facing)`，被 Python 對照測試
## 抓出跟原始碼行為不一致，已修正）。
func update_leader(pos: Vector2, facing: String) -> void:
	if _trail.is_empty():
		reset(pos)
		return
	var head: Dictionary = _trail[0]
	if pos.distance_squared_to(head["pos"]) >= min_step_sq:
		_trail.push_front({"pos": pos, "facing": facing})
		if _trail.size() > history_size:
			_trail.resize(history_size)


## `rank` 從 1 起算（1 = 緊接領隊的第一個跟隨者，2 = 第二個，以此類推）。回傳
## `{"pos": Vector2, "facing": String}`；`reset()`/`update_leader()` 都還沒被呼叫過時回傳 null，
## 呼叫端應該視為「還沒有可用資料，不畫」（對應原始碼場景剛載入、`st.trail` 尚未初始化的等價情境，
## 原始碼用 `if(!st.trail)` 立刻補滿陣列，這裡改成回傳 null 讓呼叫端自行決定要不要先 reset()）。
func sample_follower(rank: int) -> Variant:
	if _trail.is_empty():
		return null
	var idx: int = mini(_trail.size() - 1, roundi(rank * step_per_follower))
	return _trail[idx]


## 一次拿到 1..max_followers 的所有取樣點，呼叫端可自行決定要不要全部用上（例如目前隊伍只有 2 人，
## 只需要用第一個跟隨者的結果，其餘忽略或不顯示——對應原始碼 `FSPRITES` 白名單/隊伍人數不足時
## `fobjs[fi].hide(true)` 的收尾邏輯，那部分屬於呈現層，不在本檔案處理）。
func sample_all_followers() -> Array:
	var out: Array = []
	for rank in range(1, max_followers + 1):
		out.append(sample_follower(rank))
	return out


## 目前歷史陣列長度，主要給測試/除錯用。
func trail_size() -> int:
	return _trail.size()
