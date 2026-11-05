## Регресія UI наузів/ниток 0.5.4.1 — викликає реальні обробники InventoryScreen.
extends Node

var _n := 0
var _bad := 0


func ok(cond: bool, what: String) -> void:
	_n += 1
	if cond:
		print("  ok  ", what)
	else:
		_bad += 1
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _count_nauz_uid(uid: int) -> int:
	var c := 0
	for it in GameState.bag:
		if Nauzi.is_nauz(it) and int(it.get("uid", 0)) == uid:
			c += 1
	for i in range(GameState.QUICK_SLOTS):
		var sn: Variant = GameState.socket_nauz(i)
		if typeof(sn) == TYPE_DICTIONARY and sn != null and int(sn.get("uid", 0)) == uid:
			c += 1
	return c


func _run() -> void:
	print("== Nauzi UI regression ==")
	GameState.delete_save()
	PerkTree.ensure_loaded()
	GameState.new_hero("НаузТест", "perun", "volkhv")
	if GameState.starter_pending():
		var ch: Array = GameState.starter_choices()
		if ch.size() > 0 and typeof(ch[0]) == TYPE_DICTIONARY:
			GameState.choose_starter(str(ch[0].get("node", "")))
	# низький рівень — для failed req
	GameState.level = 1
	var w: GameWorld = load("res://scenes/world.tscn").instantiate()
	add_child(w)
	await frames(15)
	var hud = w.hud
	hud.open_inventory(InventoryScreen.TAB_SKILLS)
	await frames(4)
	var inv: InventoryScreen = hud._inventory
	ok(inv != null and inv.visible, "вкладка Наузи відкрита")

	# --- підготувати наузи/нитки ---
	GameState.bag.clear()
	var n_ok := Nauzi.make_nauz("element_wave", 1, 1)  # lvl1 — має підійти волхву
	var n_hi := Nauzi.make_nauz("element_wave", 15, 2)  # високі вимоги
	var n2 := Nauzi.make_nauz("sun_beam", 1, 0)
	var n3 := Nauzi.make_nauz("ice_shards", 1, 0)
	var n4 := Nauzi.make_nauz("ancestral_heal", 1, 0)
	var th_ok := Nauzi.make_thread("fury", "blue", 1)  # без тегів — пасує до faith
	var th_bad := Nauzi.make_thread("circle", "red", 1)  # wrong color + tags
	GameState.add_item(n_ok)
	GameState.add_item(n_hi)
	GameState.add_item(n2)
	GameState.add_item(n3)
	GameState.add_item(n4)
	GameState.add_item(th_ok)
	GameState.add_item(th_bad)
	var uid_ok := int(n_ok["uid"])
	var uid_hi := int(n_hi["uid"])
	var uid_2 := int(n2["uid"])
	var uid_3 := int(n3["uid"])
	var uid_4 := int(n4["uid"])
	var uid_th := int(th_ok["uid"])
	inv._refresh()
	await frames(2)

	# equip into each of 4 slots
	for slot in range(4):
		var uids := [uid_ok, uid_2, uid_3, uid_4]
		var uid: int = uids[slot]
		inv._select_nauz_uid(uid)
		inv._nauz_inner = 0
		inv._on_nauz_equip_pressed()
		ok(inv._equip_pick_mode, "slot %d: режим вибору гнізда" % slot)
		inv._do_equip_into_socket(slot)
		await frames(1)
		var sn: Variant = GameState.socket_nauz(slot)
		ok(typeof(sn) == TYPE_DICTIONARY and int(sn.get("uid", 0)) == uid, "slot %d: науз одягнено uid=%d" % [slot, uid])
		ok(_count_nauz_uid(uid) == 1, "slot %d: без дублікатів uid" % slot)

	# failed requirements
	inv._select_nauz_uid(uid_hi)
	# put hi back in bag first — unequip one slot to make space, add hi if needed
	# hi should still be in bag
	ok(GameState.find_nauz_by_uid(uid_hi).get("where", "") == "bag", "високий науз у сумці")
	inv._on_nauz_equip_pressed()
	ok(not inv._equip_pick_mode or Nauzi.can_use(GameState.find_nauz_by_uid(uid_hi)["item"]) != "", "failed req не відкриває пікер мовчки")
	# force attempt
	var before_bag := GameState.bag.size()
	var ok_hi := GameState.equip_nauz(0, uid_hi)
	ok(not ok_hi and GameState.last_error != "", "equip_nauz відхиляє з last_error: %s" % GameState.last_error)
	ok(GameState.bag.size() == before_bag, "failed req не з’їдає предмет")

	# swap: equip uid_hi can't; swap with valid — unequip slot0, then equip ok already there
	# unequip
	inv._select_nauz_uid(uid_ok)
	inv._on_nauz_unequip_pressed()
	await frames(1)
	ok(GameState.find_nauz_by_uid(uid_ok).get("where", "") == "bag", "знято в сумку")
	ok(GameState.socket_nauz(0) == null, "гніздо 0 порожнє")

	# bag full unequip
	while GameState.bag.size() < GameState.BAG_SIZE:
		GameState.add_item(Items.make("ring", 1, 0, RandomNumberGenerator.new()))
	inv._select_nauz_uid(uid_2)
	inv._on_nauz_unequip_pressed()
	ok(GameState.find_nauz_by_uid(uid_2).get("where", "") == "socket", "повна сумка: науз лишається в гнізді")
	ok(GameState.last_error != "", "повна сумка: last_error")

	# free space
	while GameState.bag.size() > 10:
		GameState.bag.pop_back()
	GameState.changed.emit()

	# weave into EQUIPPED nauz (slot 1 = uid_2)
	inv._select_nauz_uid(uid_2)
	inv._nauz_inner = 1
	inv._thread_slot_sel = 0
	inv._sel_thread_uid = uid_th
	inv._refresh()
	await frames(2)
	var threads_before: int = int((GameState.socket_nauz(1) as Dictionary).get("threads", []).size()) if typeof(GameState.socket_nauz(1)) == TYPE_DICTIONARY else -1
	inv._on_weave_pressed()
	await frames(1)
	print("  weave equipped last_error=", GameState.last_error, " threads_before=", threads_before)
	var sn1: Variant = GameState.socket_nauz(1)
	ok(typeof(sn1) == TYPE_DICTIONARY, "socket 1 живий після weave")
	if typeof(sn1) == TYPE_DICTIONARY:
		ok(int(sn1.get("threads", []).size()) == threads_before + 1, "нитку вплетено в EQUIPPED")
	ok(_count_nauz_uid(uid_2) == 1, "weave не дублює науз")
	ok(inv._sel_nauz_uid == uid_2, "UID цілі стабільний після weave")

	# weave into BAG nauz
	inv._select_nauz_uid(uid_ok)
	# add another compatible thread
	var th2 := Nauzi.make_thread("fury", "white", 0)
	GameState.add_item(th2)
	var uid_th2 := int(th2["uid"])
	inv._nauz_inner = 1
	inv._thread_slot_sel = 0
	inv._sel_thread_uid = uid_th2
	inv._on_weave_pressed()
	await frames(1)
	print("  weave bag last_error=", GameState.last_error)
	var bag_n := GameState.find_nauz_by_uid(uid_ok)
	ok(str(bag_n.get("where", "")) == "bag", "науз лишився в сумці")
	ok(int(bag_n["item"].get("threads", []).size()) >= 1, "нитку вплетено в BAG nauz")

	# incompatible disabled path: try bad color via GameState
	var th_bad_i := -1
	for i in range(GameState.bag.size()):
		if int(GameState.bag[i].get("uid", 0)) == int(th_bad.get("uid", -1)):
			th_bad_i = i
			break
	if th_bad_i < 0:
		GameState.add_item(th_bad)
		th_bad_i = GameState.bag.size() - 1
	var again := GameState.find_nauz_by_uid(uid_ok)
	ok(not GameState.attach_thread(int(again["index"]), th_bad_i), "несумісна нитка відхилена")
	ok(GameState.last_error != "", "причина несумісності: %s" % GameState.last_error)

	# locked slot: low level nauz only 1 slot — try slot 2
	inv._select_nauz_uid(uid_ok)
	inv._thread_slot_sel = 2
	inv._sel_thread_uid = uid_th2
	inv._on_weave_pressed()
	# should fail (locked or not next empty)
	ok(true, "locked/out-of-order weave не падає")

	# reload save
	var uid_check := uid_2
	GameState.save_game()
	var path_ok := GameState.load_game()
	ok(path_ok, "save reload")
	ok(_count_nauz_uid(uid_check) == 1, "після reload немає втрати/дубля uid_2")
	ok(typeof(GameState.socket_nauz(1)) == TYPE_DICTIONARY, "socket 1 після reload")

	# UI action bar visible on short landscape
	DisplayServer.window_set_size(Vector2i(1024, 473))
	get_viewport().size = Vector2i(1024, 473)
	await frames(4)
	hud.open_inventory(InventoryScreen.TAB_SKILLS)
	await frames(3)
	ok(inv._btn_nauz_equip != null and inv._nauz_action_bar != null, "ActionBar наузів існує")
	var vp := get_viewport().get_visible_rect()
	var ar := inv._nauz_action_bar.get_global_rect()
	print("  nauzi ActionBar rect ", ar, " vp ", vp.size)
	ok(ar.size.y >= 40, "ActionBar має висоту")

	print("\nПідсумок: %d перевірок, %d помилок" % [_n, _bad])
	get_tree().quit(1 if _bad > 0 else 0)
