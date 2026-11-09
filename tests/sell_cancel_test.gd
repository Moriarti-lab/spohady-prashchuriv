## Підтвердження продажу цінної речі має «Скасувати»; скасування не змінює золото/сумку.
extends Node

var _fail := 0
var _ok := 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("Підсумок sell_cancel_test: ok=%d fail=%d" % [_ok, _fail])
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(1 if _fail else 0)

func _check(c: bool, msg: String) -> void:
	if c:
		_ok += 1
		print("  ok ", msg)
	else:
		_fail += 1
		print("  FAIL ", msg)

func _run() -> void:
	GameState.delete_save()
	PerkTree.ensure_loaded()
	GameState.new_hero("Тест", "perun", "volkhv")
	if GameState.starter_pending():
		var ch: Array = GameState.starter_choices()
		if ch.size() > 0 and typeof(ch[0]) == TYPE_DICTIONARY:
			GameState.choose_starter(str(ch[0].get("node", "")))
	var it := {
		"id": "test_rare",
		"name": "Дорогоцінність",
		"kind": "gear",
		"type": "amulet",
		"slot": "amulet",
		"rarity": 3,
		"price": 100,
	}
	GameState.add_item(it)
	var gold0: int = int(GameState.gold)
	var bag0: int = GameState.bag.size()
	var inv: InventoryScreen = InventoryScreen.new()
	add_child(inv)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(inv._confirm != null, "confirm dialog exists")
	var has_cancel := inv._sell_cancel_btn != null and str(inv._sell_cancel_btn.text).find("Скасувати") >= 0
	_check(has_cancel, "кнопка Скасувати на діалозі продажу")
	var tree_ui: PerkTreeScreen = PerkTreeScreen.new()
	add_child(tree_ui)
	await get_tree().process_frame
	var tree_cancel := tree_ui._confirm_cancel_btn != null and str(tree_ui._confirm_cancel_btn.text).find("Скасувати") >= 0
	_check(tree_cancel, "кнопка Скасувати на діалозі скидання Древа")
	inv._sel_bag = 0
	for i in range(GameState.bag.size()):
		if int(GameState.bag[i].get("rarity", 0)) >= 2:
			inv._sel_bag = i
			break
	inv._on_sell()
	await get_tree().process_frame
	_check(inv._confirm.visible, "діалог відкрито для рідкісної речі")
	inv._confirm.hide()
	inv._on_sell_canceled()
	await get_tree().process_frame
	_check(int(GameState.gold) == gold0, "золото не змінилось після Скасувати")
	_check(GameState.bag.size() == bag0, "сумка не змінилась після Скасувати")
	inv._sel_bag = 0
	for i in range(GameState.bag.size()):
		if int(GameState.bag[i].get("rarity", 0)) >= 2:
			inv._sel_bag = i
			break
	inv._do_sell_confirmed()
	_check(GameState.bag.size() < bag0 or int(GameState.gold) > gold0, "після Так продаж відбувається")
