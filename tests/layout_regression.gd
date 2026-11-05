## Регресія видимих дій UI на вузьких landscape-розмірах (звіт користувача 1024×473).
## xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tests/layout_regression.tscn -- /tmp/layout_shots
extends Node

var out_dir := "/tmp/layout_shots"
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


func shot(name: String) -> void:
	await frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())


func _rect_inside(r: Rect2, vp: Rect2, pad: float = 2.0) -> bool:
	return r.position.x >= vp.position.x - pad and r.position.y >= vp.position.y - pad \
		and r.end.x <= vp.end.x + pad and r.end.y <= vp.end.y + pad


func _btn_report(label: String, b: Control, vp: Rect2) -> void:
	if b == null or not b.visible:
		print("  skip ", label, " (hidden)")
		return
	var gr := b.get_global_rect()
	print("  rect ", label, " ", gr, " inside=", _rect_inside(gr, vp))
	ok(_rect_inside(gr, vp) and gr.size.x >= 40 and gr.size.y >= 36, "%s у межах екрана %s" % [label, gr])


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _set_size(w: int, h: int) -> void:
	DisplayServer.window_set_size(Vector2i(w, h))
	get_viewport().size = Vector2i(w, h)
	await frames(4)


func _long_item() -> Dictionary:
	# довгий опис: науз із нитками + mods, щоб DetailScroll був високим
	var it := Nauzi.make_nauz("element_wave", 12, 2)
	it["threads"] = [
		Nauzi.make_thread("circle", "red", 2),
		Nauzi.make_thread("far", "white", 1),
		Nauzi.make_thread("lasting", "blue", 2),
	]
	return it


func _check_inventory(tag: String, w: GameWorld) -> void:
	var vp := get_viewport().get_visible_rect()
	print("-- inventory ", tag, " vp=", vp.size)
	w.hud.open_inventory(InventoryScreen.TAB_BAG)
	await frames(4)
	var inv = w.hud._inventory
	ok(inv != null and inv.visible, "%s: сумка відкрита" % tag)
	GameState.bag.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	GameState.add_item(_long_item())
	GameState.add_item(Items.make("sword", 8, 3, rng))
	inv._refresh()
	await frames(2)
	# 1) довгий науз — Продати + Ще в ActionBar, опис скролиться
	var nauz_slot = null
	for sl in inv._bag_slots:
		var bi: int = sl.index
		if bi >= 0 and bi < GameState.bag.size() and Nauzi.is_nauz(GameState.bag[bi]):
			nauz_slot = sl
			break
	ok(nauz_slot != null, "%s: науз у сітці" % tag)
	if nauz_slot:
		inv._on_slot_tapped(nauz_slot)
	await frames(3)
	ok(inv._action_bar != null and inv._action_bar.visible, "%s: ActionBar існує" % tag)
	ok(inv._detail_scroll != null, "%s: DetailScroll існує" % tag)
	_btn_report("%s/sell_nauz" % tag, inv._btn_sell, vp)
	_btn_report("%s/more_nauz" % tag, inv._more_menu, vp)
	var txt := str(inv._detail_rich.text) if inv._detail_rich else ""
	ok(not ("radius_pct" in txt or "range_pct" in txt or "duration_pct" in txt),
		"%s: опис без сирих ключів radius/range/duration_pct" % tag)
	ok("радіус" in txt.to_lower() or "дальност" in txt.to_lower() or "тривал" in txt.to_lower() or "Властивості" in txt,
		"%s: є україномовні властивості" % tag)
	await shot("inv_nauz_%s" % tag)
	# 2) спорядження — Одягти + Продати видимі
	var gear_slot = null
	for sl in inv._bag_slots:
		var bi2: int = sl.index
		if bi2 >= 0 and bi2 < GameState.bag.size() and not Nauzi.is_nauz(GameState.bag[bi2]) and not Nauzi.is_thread(GameState.bag[bi2]):
			gear_slot = sl
			break
	ok(gear_slot != null, "%s: спорядження у сітці" % tag)
	if gear_slot:
		inv._on_slot_tapped(gear_slot)
	await frames(3)
	_btn_report("%s/equip" % tag, inv._btn_equip, vp)
	_btn_report("%s/sell" % tag, inv._btn_sell, vp)
	await shot("inv_gear_%s" % tag)
	w.hud._close_overlay()
	await frames(2)


func _check_tree(tag: String, w: GameWorld) -> void:
	var vp := get_viewport().get_visible_rect()
	print("-- tree ", tag, " vp=", vp.size)
	if GameState.starter_pending():
		var ch2: Array = GameState.starter_choices()
		if ch2.size() > 0 and typeof(ch2[0]) == TYPE_DICTIONARY:
			GameState.choose_starter(str(ch2[0].get("node", "")))
		await frames(2)
	w.hud.open_perks()
	await frames(5)
	var ps = w.hud._perk_screen
	ok(ps != null and ps.visible, "%s: Древо відкрито" % tag)
	if ps != null and ps._modal != null and ps._modal.visible:
		ps._modal.visible = false
	if ps != null and ps.has_method("_focus_start"):
		ps._focus_start()
	await frames(3)
	var view = ps._view
	ok(view != null, "%s: PerkTreeView" % tag)
	print("  zoom=", view.zoom, " center=", view.center, " ZOOM_MIN=", view.ZOOM_MIN)
	ok(view.zoom >= 0.25 and view.zoom <= 1.0, "%s: стартовий zoom читабельний (%.3f), не огляд усього" % [tag, view.zoom])
	ok(view.ZOOM_MIN <= 0.02, "%s: ZOOM_MIN дозволяє огляд 10× світу (%.4f)" % [tag, view.ZOOM_MIN])
	# відстань між сусідніми вузлами на екрані біля центру
	var st := PerkTree.class_start(GameState.hero_class)
	var nbs: Array = PerkTree.neighbors(st)
	if nbs.size() > 0:
		var a: Vector2 = view.to_screen(PerkTree.pos(st))
		var b: Vector2 = view.to_screen(PerkTree.pos(str(nbs[0])))
		var d: float = a.distance_to(b)
		print("  screen_sep start→nb=", d)
		ok(d >= 40.0, "%s: сусіди стартy розділені на екрані (%.1f px)" % [tag, d])
	_btn_report("%s/unlock" % tag, ps._unlock_btn, vp)
	await shot("tree_%s" % tag)
	w.hud._close_overlay()
	await frames(2)


func _run() -> void:
	print("== Layout regression ==")
	GameState.delete_save()
	PerkTree.ensure_loaded()
	GameState.new_hero("Тест", "perun", "volkhv")
	if GameState.starter_pending():
		var ch: Array = GameState.starter_choices()
		print("starter choices=", ch)
		if ch.size() > 0 and typeof(ch[0]) == TYPE_DICTIONARY:
			var ok_st := GameState.choose_starter(str(ch[0].get("node", "")))
			print("choose_starter=", ok_st, " pending=", GameState.starter_pending())
	var w: GameWorld = load("res://scenes/world.tscn").instantiate()
	add_child(w)
	await frames(20)

	var sizes := [
		Vector2i(1024, 473),
		Vector2i(1280, 576),
		Vector2i(854, 480),
	]
	for sz in sizes:
		await _set_size(sz.x, sz.y)
		var tag := "%dx%d" % [sz.x, sz.y]
		await _check_inventory(tag, w)
		await _check_tree(tag, w)

	# round-trip coords still scaled
	var xs: Array = []
	for id in PerkTree.nodes().keys():
		xs.append(absf(PerkTree.pos(id).x))
	xs.sort()
	ok(xs[xs.size() - 1] > 10000.0, "координати Древа після 10× (max |x|=%.1f)" % xs[xs.size() - 1])

	print("\nПідсумок: %d перевірок, %d помилок" % [_n, _bad])
	get_tree().quit(1 if _bad > 0 else 0)
