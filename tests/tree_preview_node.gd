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
	await get_tree().create_timer(0.55).timeout
	var screen: PerkTreeScreen = w.hud._perk_screen
	var view: PerkTreeView = screen._view
	var focus := "trunk0" if PerkTree.has_node("trunk0") else PerkTree.class_start("druzhynnyk")
	view.center = Vector2(0, 200)
	view.zoom = 0.32
	view.queue_redraw()
	await get_tree().process_frame
	screen._on_node_selected(focus)
	view.selected = focus
	await get_tree().create_timer(0.55).timeout
	get_viewport().get_texture().get_image().save_png("/workspace/spohady-tree-v4-screen-node.png")
	print("TREE_SCREEN_NODE_OK")
	get_tree().quit(0)
