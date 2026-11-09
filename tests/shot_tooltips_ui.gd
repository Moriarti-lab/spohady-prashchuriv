extends Node
## Phone-res картки підказок (420×720) + sheet 1920×864 + інв/shop/loot.

const CARD_W := 420
const CARD_H := 720
const SHEET_W := 1920
const SHEET_H := 864


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(SHEET_W, SHEET_H))
	get_tree().root.size = Vector2i(SHEET_W, SHEET_H)
	await get_tree().process_frame
	var out_abs := ProjectSettings.globalize_path("res://docs/game_0_6_0/screenshots")
	DirAccess.make_dir_recursive_absolute(out_abs)

	PerkTree.ensure_loaded()
	GameState.new_hero("Скрін", "perun", "druzhynnyk")
	GameState.level = 8
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sword: Dictionary = Items.make("sword", 6, 2, rng)
	sword["name"] = "Клинок люті пращурів"
	sword["flavour"] = "Викутий у тіні кургану — досі теплий."
	var mail: Dictionary = Items.make("mail", 5, 1, rng)
	var sk0 := "power_strike"
	for k in Skills.DATA.keys():
		sk0 = str(k)
		break
	var nauz: Dictionary = Nauzi.make_nauz(sk0, 12, 3)
	var tid := "fury"
	for k2 in Nauzi.THREADS.keys():
		tid = str(k2)
		break
	var thread: Dictionary = Nauzi.make_thread(tid, "red", 2)
	GameState.gold = 500
	GameState.bag = [sword, nauz, thread]
	GameState.merchant_stock = [Items.make("axe", 4, 2, rng), mail]

	var root := get_tree().root
	# --- Isolated phone cards ---
	var cards := [
		["phone_card_weapon.png", sword, "bag"],
		["phone_card_armor.png", mail, "bag"],
		["phone_card_nauz.png", nauz, "nauz"],
		["phone_card_thread.png", thread, "bag"],
		["phone_card_loot.png", sword, "loot"],
	]
	for entry in cards:
		_clear_extras(root)
		var bg := ColorRect.new()
		bg.color = Color(0.06, 0.05, 0.04)
		bg.size = Vector2(SHEET_W, SHEET_H)
		root.add_child(bg)
		var card: PanelContainer = DescFormat.make_tooltip_card(entry[1], {"where": entry[2]}, float(CARD_W))
		root.add_child(card)
		await get_tree().process_frame
		await get_tree().process_frame
		# Force card into phone column size for crop
		card.position = Vector2(40, 40)
		card.size = Vector2(CARD_W, maxf(card.get_combined_minimum_size().y, 80.0))
		await get_tree().process_frame
		await _shot_region(out_abs + "/" + entry[0], Rect2i(40, 40, CARD_W, CARD_H))
		bg.queue_free()
		card.queue_free()

	# Sheet of 4 cards
	_clear_extras(root)
	var sheet_bg := ColorRect.new()
	sheet_bg.color = Color(0.07, 0.06, 0.05)
	sheet_bg.size = Vector2(SHEET_W, SHEET_H)
	root.add_child(sheet_bg)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.position = Vector2(40, 60)
	root.add_child(row)
	for pair in [[sword, "bag"], [mail, "bag"], [nauz, "nauz"], [thread, "bag"]]:
		row.add_child(DescFormat.make_tooltip_card(pair[0], {"where": pair[1]}, 420.0))
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot(out_abs + "/tooltip_sheet_phone.png", SHEET_W, SHEET_H)
	sheet_bg.queue_free()
	row.queue_free()

	# Inventory / shop / loot popup (full phone landscape)
	_clear_extras(root)
	var bg2 := ColorRect.new()
	bg2.color = Color(0.08, 0.06, 0.05)
	bg2.size = Vector2(SHEET_W, SHEET_H)
	root.add_child(bg2)

	var inv := InventoryScreen.new()
	root.add_child(inv)
	inv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inv.open(InventoryScreen.TAB_BAG)
	await get_tree().create_timer(0.55).timeout
	if inv._detail_rich:
		inv._detail_rich.text = DescFormat.item_tooltip(sword, {"where": "bag"})
	await get_tree().create_timer(0.35).timeout
	await _shot(out_abs + "/inv_tooltip_weapon.png", SHEET_W, SHEET_H)

	if inv._detail_rich:
		inv._detail_rich.text = DescFormat.item_tooltip(nauz, {"where": "nauz"})
	await get_tree().create_timer(0.3).timeout
	await _shot(out_abs + "/inv_tooltip_nauz.png", SHEET_W, SHEET_H)
	inv.visible = false

	var shop := ShopScreen.new()
	root.add_child(shop)
	shop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop.open()
	await get_tree().create_timer(0.55).timeout
	await _shot(out_abs + "/shop_tooltip.png", SHEET_W, SHEET_H)
	shop.visible = false

	# Loot popup via Hud
	var hud := Hud.new()
	hud.editor_preview = true
	root.add_child(hud)
	await get_tree().process_frame
	# Fake LootDrop-like show via make card overlay (no world)
	var fake := LootDrop.new()
	fake.kind = LootDrop.KIND_ITEM
	fake.item = sword
	# Don't add to tree as 3D; just use item dict path
	hud.show_loot_popup(fake)
	await get_tree().create_timer(0.5).timeout
	await _shot(out_abs + "/loot_popup_phone.png", SHEET_W, SHEET_H)
	hud.hide_loot_popup()

	print("SHOTS_OK")
	get_tree().quit(0)


func _clear_extras(root: Node) -> void:
	for c in root.get_children():
		if c == self:
			continue
		var n := str(c.name)
		# Autoloads + engine nodes stay
		if c.get_parent() == root and c is Node and not (c is Control or c is ColorRect or c is CanvasLayer):
			continue
		if n.begins_with("Loot") or c is InventoryScreen or c is ShopScreen or c is Hud or c is ColorRect or c is PanelContainer or c is HBoxContainer:
			c.queue_free()
	await get_tree().process_frame


func _shot(path: String, w: int, h: int) -> void:
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
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h)
	img.save_png(path)
	print("SHOT ", path)


func _shot_region(path: String, region: Rect2i) -> void:
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
	var r := region
	r.position.x = clampi(r.position.x, 0, img.get_width() - 1)
	r.position.y = clampi(r.position.y, 0, img.get_height() - 1)
	r.size.x = mini(r.size.x, img.get_width() - r.position.x)
	r.size.y = mini(r.size.y, img.get_height() - r.position.y)
	var crop := img.get_region(r)
	# Pad to exact CARD_H if content shorter (keep auto-height look: don't stretch empty)
	if crop.get_height() < CARD_H or crop.get_width() < CARD_W:
		var canvas := Image.create(CARD_W, CARD_H, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0.06, 0.05, 0.04, 1))
		canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i.ZERO)
		canvas.save_png(path)
	else:
		crop.save_png(path)
	print("SHOT ", path, " ", crop.get_width(), "x", crop.get_height())
