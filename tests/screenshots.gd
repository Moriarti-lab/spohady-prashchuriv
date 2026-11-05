## Знімки екранів для перевірки вигляду (потрібен дисплей, наприклад xvfb):
## xvfb-run -s "-screen 0 1280x720x24" godot --path . res://tests/screenshots.tscn -- /tmp/shots
extends Node

var out_dir := "/tmp/shots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())


func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


func _run() -> void:
	GameState.delete_save()
	GameState.has_hero = false
	var title: Node = load("res://scenes/main.tscn").instantiate()
	add_child(title)
	await frames(3)
	await shot("01_title")
	title.queue_free()
	var ch: CreateHero = load("res://scenes/create_hero.tscn").instantiate()
	add_child(ch)
	await frames(2)
	ch._name_edit.text = "Ярослав"
	await shot("02_name")
	ch._on_next()
	await frames(2)
	await shot("03_intro")
	ch._on_next()
	await frames(2)
	ch._pick_blessing("perun")
	await shot("04_blessing")
	ch._on_next()
	await frames(2)
	ch._pick_class("volkhv")
	await shot("05_class")
	ch.queue_free()
	await frames(2)
	GameState.new_hero("Ярослав", "perun", "druzhynnyk")
	if GameState.starter_pending():
		var sch: Array = GameState.starter_choices()
		if sch.size() > 0 and typeof(sch[0]) == TYPE_DICTIONARY:
			GameState.choose_starter(str(sch[0].get("node", "")))
	GameState.add_xp(GameState.xp_needed())
	var w: GameWorld = load("res://scenes/world.tscn").instantiate()
	add_child(w)
	await frames(30)
	for e in get_tree().get_nodes_in_group("enemies"):
		(e as Node3D).global_position = w.player.global_position + Vector3(2.5, 0, -2.0 * (1 + randi() % 3))
	await frames(10)
	w.player.basic_attack()
	await frames(6)
	await shot("06_world")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in range(9):
		GameState.add_item(Items.generate(GameState.level + 2, rng, "", -1 if k < 6 else 3))
	GameState.add_gold(240)
	GameState.add_potion("health", 3)
	await frames(3)
	await shot("06b_hud")
	w.hud.open_inventory(InventoryScreen.TAB_BAG)
	await frames(3)
	await shot("07a_bag")
	# довгий опис науза + видимі дії (регресія 0.5.4)
	var long_nauz := Nauzi.make_nauz("element_wave", 12, 2)
	long_nauz["threads"] = [Nauzi.make_thread("circle", "red", 2), Nauzi.make_thread("far", "white", 1)]
	GameState.add_item(long_nauz)
	w.hud._inventory._refresh()
	await frames(2)
	for sl in w.hud._inventory._bag_slots:
		var bi: int = sl.index
		if bi >= 0 and bi < GameState.bag.size() and Nauzi.is_nauz(GameState.bag[bi]):
			w.hud._inventory._on_slot_tapped(sl)
			break
	await frames(3)
	await shot("07a_bag_long_desc")
	w.hud.open_inventory(InventoryScreen.TAB_SKILLS)
	await frames(3)
	await shot("07b_skills")
	w.hud._close_overlay()
	w.hud.open_map()
	await frames(4)
	await shot("07c_map")
	w.hud._close_overlay()
	w.hud.open_perks()
	await frames(4)
	await shot("07_perks_default_zoom")
	var st := PerkTree.class_start(GameState.hero_class)
	w.hud._perk_screen._on_node_selected(st)
	await frames(2)
	await shot("07_perks")
	w.hud._close_overlay()
	w.hud._open_pause()
	await frames(2)
	await shot("08_pause")
	w.hud._close_overlay()
	await frames(30)
	w.player.invuln = 0.0
	w.player.take_damage(99999.0, w.player.global_position + Vector3(1, 0, 0), 0.0)
	await frames(30)
	print("dead=", w.player.dead, " overlay=", w.hud._death_box.visible)
	await shot("09_death")
	get_tree().quit()
