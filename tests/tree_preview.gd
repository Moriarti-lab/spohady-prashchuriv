extends Node
func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit(2))
	_run.call_deferred()
func _run() -> void:
	GameState.delete_save()
	GameState.new_hero("Перегляд", "perun", "druzhynnyk")
	GameState.choose_starter(GameState.starter_choices()[0]["node"])
	GameState.perk_points = 80
	var w: GameWorld = load("res://scenes/world.tscn").instantiate()
	w.skip_warmup = true
	add_child(w)
	await get_tree().process_frame
	await get_tree().process_frame
	w.hud.open_perks()
	await get_tree().create_timer(0.5).timeout
	var view: PerkTreeView = w.hud._perk_screen._view
	# крона: серед плодів сили + верх стовбура
	var fruit := "s_fruit1" if PerkTree.has_node("s_fruit1") else PerkTree.class_start("druzhynnyk")
	var trunk := "s_t14" if PerkTree.has_node("s_t14") else fruit
	view.center = PerkTree.pos(fruit) * 0.65 + PerkTree.pos(trunk) * 0.35
	view.zoom = 0.36
	view.queue_redraw()
	await get_tree().create_timer(0.55).timeout
	get_viewport().get_texture().get_image().save_png("/workspace/spohady-tree-v4-screen.png")
	print("TREE_SCREEN_OK")
	get_tree().quit(0)
