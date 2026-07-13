extends RefCounted
class_name FlagMatcher

## D-1　共用旗標比對器（specs/DIALOGUE_SPEC.md D-1，對應 build_cq2.py L1270-1274 `matchWhen`）。
##
## 純函式，MOD-A（對話/劇情）與 MOD-B（撿取/觸發）共用同一份判斷邏輯，不要各自重寫。
##
## 呼叫介面（MOD-A 依此簽名呼叫，不要更動）：
##     FlagMatcher.matches(flags: Dictionary, when: String) -> bool
##
## 語法只支援三種：
##   ""  或 "always"          -> 永遠成立
##   "<旗標名>==<整數>"        -> flags[旗標名]（未定義視為 0）等於該整數
##   "<旗標名>>=<整數>"        -> flags[旗標名]（未定義視為 0）大於等於該整數
## 其他任何寫法（包含大小寫混合運算子、非整數等）一律回傳 false，對應原始碼「no match: return false」。
##
## 注意：DLG／CUTS 的 `step`／`minStep` 欄位是另一層獨立閘門（見 D-3、D-4），不是走這個函式，
## trigger_zone.gd / exit_zone.gd 會另外處理，不要把兩者混為一談。

static var _pattern: RegEx = null


static func matches(flags: Dictionary, when: String) -> bool:
	if when == "" or when == "always":
		return true
	if _pattern == null:
		_pattern = RegEx.new()
		_pattern.compile("^(\\w+)(==|>=)(\\d+)$")
	var m: RegExMatch = _pattern.search(when)
	if m == null:
		return false
	var key: String = m.get_string(1)
	var op: String = m.get_string(2)
	var n: int = int(m.get_string(3))
	var v: int = int(flags.get(key, 0))
	if op == "==":
		return v == n
	return v >= n
