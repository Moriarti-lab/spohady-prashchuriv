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
	# trunk + lower canopy fan (wide enough to read silhouette)
	view.center = Vector2(0, 100)
	view.zoom = 0.28
	view.queue_redraw()
	screen._hide_detail()
	await get_tree().create_timer(0.55).timeout
	get_viewport().get_texture().get_image().save_png("/workspace/spohady-tree-v4-screen.png")
	print("TREE_SCREEN_OK")
	get_tree().quit(0)
