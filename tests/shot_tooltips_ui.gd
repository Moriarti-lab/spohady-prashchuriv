extends Node

const W := 1920
const H := 864


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(W, H))
	get_tree().root.size = Vector2i(W, H)
	await get_tree().process_frame
	var out_abs := ProjectSettings.globalize_path("res://docs/game_0_6_0/screenshots")
	DirAccess.make_dir_recursive_absolute(out_abs)

	PerkTree.ensure_loaded()
	GameState.new_hero("Скрін", "perun", "druzhynnyk")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sword: Dictionary = Items.make("sword", 6, 2, rng)
	sword["name"] = "Клинок люті пращурів"
	sword["flavour"] = "Викутий у тіні кургану — досі теплий."
	var sk0 := "power_strike"
	for k in Skills.DATA.keys():
		sk0 = str(k)
		break
	var nauz: Dictionary = Nauzi.make_nauz(sk0, 12, 3)
	GameState.gold = 500
	GameState.bag = [sword, nauz]
	GameState.merchant_stock = [Items.make("axe", 4, 2, rng), Items.make("mail", 5, 1, rng)]

	var root := get_tree().root
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05)
	bg.size = Vector2(W, H)
	root.add_child(bg)

	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv.open(InventoryScreen.TAB_BAG)
	await get_tree().create_timer(0.55).timeout
	if inv._detail_rich:
		inv._detail_rich.text = DescFormat.item_tooltip(sword, {"where": "bag"})
	await get_tree().create_timer(0.35).timeout
	await _shot(out_abs + "/inv_tooltip_weapon.png")

	if inv._detail_rich:
		inv._detail_rich.text = DescFormat.item_tooltip(nauz, {"where": "nauz"})
	await get_tree().create_timer(0.3).timeout
	await _shot(out_abs + "/inv_tooltip_nauz.png")
	inv.visible = false

	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop.open()
	await get_tree().create_timer(0.55).timeout
	await _shot(out_abs + "/shop_tooltip.png")
	shop.visible = false

	var hud := Hud.new()
	hud.editor_preview = true
	root.add_child(hud)
	await get_tree().create_timer(0.5).timeout
	if hud.has_method("editor_set_menu_open"):
		hud.editor_set_menu_open(true)
	elif hud.get("_submenu"):
		hud._submenu.visible = true
	if hud.has_method("_layout"):
		hud._layout()
	await get_tree().create_timer(0.4).timeout
	await _shot(out_abs + "/hud_submenu.png")

	# Editor checks/gen tabs quick
	print("SHOTS_OK")
	get_tree().quit(0)


func _shot(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var tex := get_viewport().get_texture()
	if tex == null:
		print("FAIL tex ", path)
		return
	var img: Image = tex.get_image()
	if img == null:
		print("FAIL img ", path)
		return
	if img.get_width() != W or img.get_height() != H:
		img.resize(W, H)
	img.save_png(path)
	print("SHOT ", path)
