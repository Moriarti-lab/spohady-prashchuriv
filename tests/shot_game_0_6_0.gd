extends Node
## Phone landscape 1920×864 shots for 0.6.0 report.

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
	GameState.level = 8
	GameState.gold = 800
	GameState.perk_points = 12
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sword: Dictionary = Items.make("sword", 6, 2, rng)
	sword["name"] = "Клинок люті пращурів"
	sword["flavour"] = "Викутий у тіні кургану — досі теплий."
	var sk0 := "power_strike"
	for k in Skills.DATA.keys():
		sk0 = str(k)
		break
	var nauz: Dictionary = Nauzi.make_nauz(sk0, 10, 3)
	var tid := "fury"
	for k2 in Nauzi.THREADS.keys():
		tid = str(k2)
		break
	var thread: Dictionary = Nauzi.make_thread(tid, "red", 2)
	GameState.bag = [sword, nauz, thread, Items.make("mail", 5, 1, rng)]
	GameState.merchant_stock = [Items.make("axe", 4, 2, rng), Items.make("mail", 5, 1, rng)]

	var root := get_tree().root
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05)
	bg.size = Vector2(W, H)
	root.add_child(bg)

	# 1) Inventory weapon tooltip
	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv.open(InventoryScreen.TAB_BAG)
	await get_tree().create_timer(0.5).timeout
	if inv._detail_rich:
		inv._detail_rich.text = DescFormat.item_tooltip(sword, {"where": "bag"})
	await get_tree().create_timer(0.25).timeout
	await _shot(out_abs + "/phone_inv_tooltip.png")

	# 2) Nauzi tab
	inv.open(InventoryScreen.TAB_NAUZI)
	inv._nauz_inner = 0
	if inv.has_method("_select_nauz_uid"):
		inv._select_nauz_uid(int(nauz.get("uid", 0)))
	if inv.has_method(" _refresh_skills"):
		inv. _refresh_skills()
	elif inv.has_method("_refresh"):
		inv._refresh()
	if inv._nauz_detail_rich:
		inv._nauz_detail_rich.text = DescFormat.item_tooltip(nauz, {"where": "nauz"})
	await get_tree().create_timer(0.4).timeout
	await _shot(out_abs + "/phone_nauzi.png")

	# 3) Threads
	inv._nauz_inner = 1
	if inv.has_method(" _refresh_skills"):
		inv. _refresh_skills()
	elif inv.has_method("_refresh"):
		inv._refresh()
	if inv._detail_rich:
		inv._detail_rich.text = DescFormat.item_tooltip(thread, {"where": "bag"})
	if inv._nauz_detail_rich:
		inv._nauz_detail_rich.text = DescFormat.item_tooltip(thread, {"where": "bag"})
	await get_tree().create_timer(0.35).timeout
	await _shot(out_abs + "/phone_threads.png")
	inv.visible = false

	# 4) Shop
	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop.open()
	await get_tree().create_timer(0.5).timeout
	await _shot(out_abs + "/phone_shop.png")
	shop.visible = false

	# 5) Perk tree v7.3 (starter already chosen to show the web)
	GameState.choose_starter(sk0)
	var tree := PerkTreeScreen.new()
	root.add_child(tree)
	tree.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.open()
	# Dismiss starter modal if still up
	if tree.get("_modal") and tree._modal.visible:
		tree._modal.visible = false
	await get_tree().create_timer(0.8).timeout
	await _shot(out_abs + "/phone_tree_v73.png")
	tree.visible = false

	# 6) Refund notice (same copy as GameState.notice after tree migration)
	var hud := Hud.new()
	hud.editor_preview = true
	root.add_child(hud)
	await get_tree().process_frame
	if hud.has_method("_layout"):
		hud._layout()
	var notice := "Древо звитяги оновлено. Відкриті вузли скинуто, усі очки перків повернено — розподіли їх наново. Золото й Воду забуття не витрачено."
	var toast := FolkTheme.label(notice, 26, Palette.LINEN, HORIZONTAL_ALIGNMENT_CENTER, true)
	toast.add_theme_constant_override("outline_size", 8)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	toast.custom_minimum_size = Vector2(1400, 0)
	toast.size = Vector2(1400, 120)
	toast.position = Vector2((W - 1400) / 2.0, H * 0.52)
	hud._root.add_child(toast)
	await get_tree().create_timer(0.45).timeout
	await _shot(out_abs + "/phone_refund_notice.png")
	toast.queue_free()

	# 7) HUD submenu
	if hud.has_method("editor_set_menu_open"):
		hud.editor_set_menu_open(true)
	elif hud.get("_submenu"):
		hud._submenu.visible = true
	if hud.has_method("_layout"):
		hud._layout()
	# hide banner for clean HUD
	if hud.get("_banner"):
		hud._banner.visible = false
	await get_tree().create_timer(0.4).timeout
	await _shot(out_abs + "/phone_hud_submenu.png")

	print("GAME_SHOTS_OK")
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
