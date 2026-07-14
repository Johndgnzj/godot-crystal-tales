extends RefCounted
class_name ExpNeed

## F-2　升級所需經驗（specs/BATTLE_FORMULAS.md F-2）。
##
## 對應 build_cq2.py `expNeed(lv)`（WORLD L1325 / BATTLE L2662，兩處逐字相同——跟 F-1 的 derive() 不同，
## 這個函式本來就沒有技術債，這裡合併成一份純粹是延續 MOD-F「衍生屬性/戰鬥公式只留一份」的目標，沒有
## 行為修正）。


static func exp_need(lv: int) -> int:
	var d: DerivedParams = ContentDB.get_derived()
	# see specs/BATTLE_FORMULAS.md F-2
	return int(d.exp_base + round(d.exp_coef * pow(float(lv), d.exp_pow)))
