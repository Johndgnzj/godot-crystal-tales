extends "res://scripts/battle/battle_state_machine.gd"

## 美術試作專用：直接沿用正式戰鬥狀態機與 UI，只替換敵方資料。
## 不寫入 ContentDB，也不會出現在正常遭遇表中。

const PREVIEW_FOES := [
	{
		"id": "briar_bloom",
		"name": "荊棘食人花",
		"sprite": "briar_bloom",
		"hp": 520.0,
		"atk": 20.0,
		"def": 10.0,
		"spd": 6.0,
		"big": true,
		"battle_height": 180.0,
	},
	{
		"id": "crystal_bee",
		"name": "晶蜂",
		"sprite": "crystal_bee",
		"hp": 36.0,
		"atk": 9.0,
		"def": 3.0,
		"spd": 15.0,
		"big": false,
		"battle_height": 62.0,
	},
	{
		"id": "giant_rat",
		"name": "礦坑巨鼠",
		"sprite": "giant_rat",
		"hp": 74.0,
		"atk": 13.0,
		"def": 5.0,
		"spd": 9.0,
		"big": false,
		"battle_height": 92.0,
	},
]


func _init_battle() -> void:
	if GameState.party.is_empty():
		GameFlow.new_game()
	GameState.encounter = "forest"
	super()

	foes.clear()
	for i in PREVIEW_FOES.size():
		var source: Dictionary = PREVIEW_FOES[i]
		var foe := source.duplicate(true)
		foe.merge({
			"maxhp": foe["hp"],
			"exp": 0,
			"gold": 0,
			"healer": false,
			"allAttack": false,
			"foeSkills": [],
			"drops": [],
			"side": "foe",
			"slot": i,
			"alive": true,
			"atb": 0.0,
			"row": "back" if bool(foe["big"]) else "front",
		})
		foes.append(foe)

	state = "menu"
	actor = heroes[0] if not heroes.is_empty() else null
	msg = "LPC 怪物試作：荊棘食人花、晶蜂、礦坑巨鼠"
	_build_view()
