## Одноразовий знімок Древа для прев'ю v0.5.3.
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
	await get_tree().create_timer(0.8).timeout
	var view: PerkTreeView = w.hud._perk_screen._view
	view.focus_on(PerkTree.class_start("druzhynnyk"), 0.28)
	await get_tree().create_timer(0.4).timeout
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("/workspace/spohady-tree-v4-ingame.png")
	# zoom crown
	view.focus_on("core", 0.55)
	await get_tree().create_timer(0.4).timeout
	var img2: Image = get_viewport().get_texture().get_image()
	img2.save_png("/workspace/spohady-tree-v4-zoom-ingame.png")
	print("TREE_PREVIEW_OK")
	get_tree().quit(0)
