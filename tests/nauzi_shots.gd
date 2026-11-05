extends Node
var out_dir := "/tmp/nauzi_shots"
func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
func shot(name: String) -> void:
	await frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()
func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1024, 473))
	get_viewport().size = Vector2i(1024, 473)
	await frames(3)
	GameState.delete_save()
	PerkTree.ensure_loaded()
	GameState.new_hero("Ярослав", "perun", "volkhv")
	if GameState.starter_pending():
		var ch: Array = GameState.starter_choices()
		if ch.size() > 0 and typeof(ch[0]) == TYPE_DICTIONARY:
			GameState.choose_starter(str(ch[0].get("node", "")))
	var w: GameWorld = load("res://scenes/world.tscn").instantiate()
	add_child(w)
	await frames(20)
	var n := Nauzi.make_nauz("element_wave", 1, 2)
	var th := Nauzi.make_thread("fury", "blue", 1)
	var th2 := Nauzi.make_thread("circle", "red", 0)
	GameState.add_item(n)
	GameState.add_item(th)
	GameState.add_item(th2)
	w.hud.open_inventory(InventoryScreen.TAB_SKILLS)
	await frames(4)
	var inv = w.hud._inventory
	inv._select_nauz_uid(int(n.get("uid", 0)))
	inv._nauz_inner = 0
	inv._refresh()
	await frames(3)
	await shot("nauzi_bag_equip_1024x473")
	inv._on_nauz_equip_pressed()
	await frames(3)
	await shot("nauzi_pick_socket_1024x473")
	inv._do_equip_into_socket(0)
	await frames(3)
	await shot("nauzi_equipped_1024x473")
	inv._nauz_inner = 1
	inv._thread_slot_sel = 0
	inv._sel_thread_uid = int(th.get("uid", 0))
	inv._refresh()
	await frames(3)
	await shot("nauzi_threads_weave_1024x473")
	print("rects equip=", inv._btn_nauz_equip.get_global_rect(), " weave=", inv._btn_weave.get_global_rect())
	get_tree().quit()
