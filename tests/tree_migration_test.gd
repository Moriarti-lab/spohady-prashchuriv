extends Node
## Міграція tree_version: скидання unlocked, notice, ідемпотентність.

var _fail := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	# Ізоляція від overrides редактора
	if FileAccess.file_exists(PerkTree.OVERRIDE_TREE):
		DirAccess.remove_absolute(PerkTree.OVERRIDE_TREE)
	PerkTree.reload_from_path(PerkTree.TREE_PATH)
	var cur := PerkTree.tree_id()
	ok(cur != "", "tree_id не порожній (%s)" % cur)

	var gs := GameState
	var gold0 := 999
	var water0 := 3
	var start := PerkTree.class_start("druzhynnyk")
	ok(start != "", "є class_start")
	var d1 := {
		"version": 4, "name": "Тест", "blessing": "perun", "class": "druzhynnyk",
		"level": 8, "xp": 10, "perk_points": 0,
		"unlocked": ["trunk_s0", "no_such_node", start], "skills": [],
		"gold": gold0, "oblivion_water": water0, "bonus_perks": 2,
		"hp_potions": 0, "mana_potions": 0, "bag": [], "equipment": {}, "quick": ["", "", "", ""],
		"sockets": [null, null, null, null], "attr_points": 0, "attr_spent": {"str": 0, "agi": 0, "faith": 0},
	}
	ok(gs.from_dict(d1), "from_dict v4 без tree_version")
	ok(gs.unlocked == [start], "unlocked скинуто до старту")
	ok(gs.perk_points == gs.expected_perk_points(), "очки = expected")
	ok(gs.gold == gold0, "золото не чіпали")
	ok(gs.oblivion_water == water0, "воду не чіпали")
	ok(str(gs.notice) != "", "є notice")
	ok(gs.tree_version == cur, "tree_version оновлено")

	var d2: Dictionary = gs.to_dict()
	ok(gs.from_dict(d2), "повторне from_dict")
	ok(str(gs.notice) == "", "повторно notice порожній")
	ok(gs.unlocked == [start], "unlocked лишається")
	ok(gs.tree_version == cur, "tree_version стабільний")

	var neigh: Array = PerkTree.neighbors(start)
	if not neigh.is_empty():
		var n1 := str(neigh[0])
		gs.unlocked = [start, n1]
		gs.perk_points = gs.expected_perk_points()
		gs.tree_version = cur
		gs.notice = ""
		var d3: Dictionary = gs.to_dict()
		ok(gs.from_dict(d3), "збіг версій")
		ok(n1 in gs.unlocked, "валідний unlock збережено")
		ok(str(gs.notice) == "", "без notice при збігу")
	else:
		print("SKIP no neighbor")

	var d4: Dictionary = gs.to_dict()
	d4["tree_version"] = "v0-fake#deadbeef"
	var gold4: int = int(gs.gold)
	ok(gs.from_dict(d4), "чужий tree_version")
	ok(gs.unlocked == [start], "refund після чужої версії")
	ok(str(gs.notice) != "", "notice після чужої версії")
	ok(int(gs.gold) == gold4, "золото після чужої версії")

	if _fail == 0:
		print("TREE_MIGRATION_OK")
		get_tree().quit(0)
	else:
		print("TREE_MIGRATION_FAIL ", _fail)
		get_tree().quit(1)


func ok(cond: bool, msg: String) -> void:
	if cond:
		print("OK ", msg)
	else:
		print("FAIL ", msg)
		_fail += 1
