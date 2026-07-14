class_name Atb
extends RefCounted
## F-7　ATB（Active Time Battle）蓄力（specs/BATTLE_FORMULAS.md F-7）。
##
## 對應 build_cq2.py L2675（`ATB_K` 常數）與 L2708-2721（主狀態機 `state==="run"` 分支的蓄力/判定
## 迴圈）。純函式集合，不持有任何狀態——`battle_state_machine.gd` 持有 `heroes`/`foes` 兩個 Array，
## 每個元素是 Dictionary（英雄＝`Derive.derive()` 處理過的隊伍成員 + 戰鬥暫態欄位，敵人＝
## `initB()` 等價建構出的 Dictionary），本檔案只讀寫其中的 `"atb"`/`"alive"`/`"attrs"`/`"spd"` 欄位。

## 全域速度倍率。**Design Tweaks 定案值，不是可隨意調整的臨時參數**——調整前必須先跟設計端（John）
## 確認，不要因為「覺得戰鬥步調太慢/太快」就直接改這個數字。see specs/BATTLE_FORMULAS.md F-7
const ATB_K: float = 1.05

## 敵人初始 ATB 上限（`random()*30`，見 F-7 v1.1 修正後的正確對應：build_cq2.py L2862）。
const FOE_INITIAL_ATB_MAX: float = 30.0

## 英雄初始 ATB 上限（`random()*40`，build_cq2.py L2852）。
const HERO_INITIAL_ATB_MAX: float = 40.0


## 每幀對存活單位蓄力（只在 `state==="run"` 時呼叫，非 run 狀態暫停 ATB——這條規則由呼叫端
## `battle_state_machine.gd` 只在 `state=="run"` 時呼叫本函式來保證，本函式不自己檢查狀態）。
## `units` 是 heroes.concat(foes) 的等價陣列（見 build_cq2.py L2711 `b.heroes.concat(b.foes)`）。
static func tick(units: Array, dt: float) -> void:
	for u in units:
		var unit: Dictionary = u
		if not bool(unit.get("alive", false)):
			continue
		var spd: float
		if unit.has("attrs"):
			spd = float(unit["attrs"].get("agi", 0.0))
		else:
			spd = float(unit.get("spd", 0.0))
		var cur: float = float(unit.get("atb", 0.0))
		unit["atb"] = min(100.0, cur + (10.0 + spd) * ATB_K * dt)


## 找出第一個 ATB 蓄滿（>=100）的存活英雄（同一幀只處理第一個達標者，對應 L2715-2716 的
## `for` 迴圈 + `break`——陣列順序即優先權，不是「最高 ATB 優先」）。回傳 null 代表沒有。
static func find_ready_hero(heroes: Array) -> Variant:
	for h in heroes:
		var hero: Dictionary = h
		if bool(hero.get("alive", false)) and float(hero.get("atb", 0.0)) >= 100.0:
			return hero
	return null


## 找出第一個 ATB 蓄滿的存活敵人（只在沒有英雄就緒時才會被呼叫，對應 L2718-2721 的 `else` 分支）。
static func find_ready_foe(foes: Array) -> Variant:
	for f in foes:
		var foe: Dictionary = f
		if bool(foe.get("alive", false)) and float(foe.get("atb", 0.0)) >= 100.0:
			return foe
	return null


## 行動結束歸零（對應 `endAction()` L2838 `b.actor.atb=0` 與 `foeAct()` L3020 `a.atb=0`）。
static func reset(unit: Dictionary) -> void:
	unit["atb"] = 0.0
