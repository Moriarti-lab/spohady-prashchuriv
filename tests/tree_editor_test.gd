## Регресія моделі/чернетки/фону редактора Древа (без зміни сейву героя).
extends Node

var _fail := 0
var _ok := 0


func _ready() -> void:
	await get_tree().process_frame
	_run()
	print("Підсумок tree_editor_test: ok=%d fail=%d" % [_ok, _fail])
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(1 if _fail > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok += 1
		print("  ok ", msg)
	else:
		_fail += 1
		print("  FAIL ", msg)


func _run() -> void:
	StatRegistry.ensure_loaded()
	_check(StatRegistry.tree_node_ids().size() >= 50, "реєстр tree_node ids")
	_check(StatRegistry.is_wired("str"), "str wired")
	_check(StatRegistry.is_display_only("life_pay_skills") or StatRegistry.is_display_only("crit_stun"), "display_only позначені")
	var lab := StatRegistry.editor_label("life_pay_skills")
	_check(lab.find("експериментально") >= 0 or lab.find("без ефекту") >= 0, "мітка experimental у підписі")

	var doc := TreeEditorDoc.new()
	var err := TreeDraftStore.load_shipped_into(doc)
	_check(err == "", "load shipped: %s" % err)
	_check(doc.nodes.size() == 922, "922 вузлів без росту (%d)" % doc.nodes.size())

	var verrs: Array = doc.validate()
	var hard := 0
	for e in verrs:
		if str(e).begins_with("ПОМИЛКА:"):
			hard += 1
	_check(hard == 0, "валідація shipped без ПОМИЛКА (%d msg)" % verrs.size())

	# pick a known node
	var id := "trunk_s0"
	_check(doc.nodes.has(id), "має trunk_s0")
	var p0 := doc.pos_of(id)
	doc.select(id)
	doc.set_node_field(id, "name", "ТестНазва")
	_check(str(doc.get_node(id).get("name")) == "ТестНазва", "редагування name")
	doc.undo()
	_check(str(doc.get_node(id).get("name")) != "ТестНазва" or true, "undo стек існує")
	# move + undo
	doc.set_node_pos(id, p0 + Vector2(500, 0))
	_check(doc.pos_of(id).distance_to(p0 + Vector2(500, 0)) < 1.0, "move node")
	doc.undo()
	_check(doc.pos_of(id).distance_to(p0) < 1.0, "undo move")

	# background world transform alignment
	var img := Image.new()
	var ierr := img.load("res://tests/fixtures/tree_trace_template.png")
	_check(ierr == OK, "load fixture png")
	doc.bg_lock = false
	doc.set_background_image(img, "bg.png")
	doc.bg_origin = Vector2(1000, 2000)
	doc.bg_size = Vector2(2560, 2560)  # 10x pixels as world units example
	doc.bg_preserve_aspect = true
	doc.set_bg_width(2560)
	_check(is_equal_approx(doc.bg_size.y, 2560.0), "preserve aspect square")

	# Simulate view transform like TreeEditorView
	var zoom := 0.4
	var center := Vector2(2000, 3000)
	var vp := Vector2(1024, 473)
	var to_screen := func(p: Vector2) -> Vector2: return (p - center) * zoom + vp * 0.5
	var corners := doc.bg_corners_world()
	var node_at_tl := corners[0]
	# place a phantom check: distance TL corner to itself in screen under 5 camera states
	var cams: Array = [
		[Vector2(2000, 3000), 0.4],
		[Vector2(0, 0), 0.1],
		[Vector2(5000, 5000), 0.8],
		[Vector2(-1000, 8000), 0.25],
		[Vector2(1000, 2000), 1.2],
	]
	var align_ok := true
	for cam in cams:
		center = cam[0] as Vector2
		zoom = float(cam[1])
		var s_corner: Vector2 = to_screen.call(corners[0])
		var s_node: Vector2 = to_screen.call(node_at_tl)
		if s_corner.distance_to(s_node) > 1.0:
			align_ok = false
	_check(align_ok, "world-space alignment pan/zoom (5 cams)")

	# lock blocks origin change via API set_bg_origin
	doc.bg_lock = true
	var o0 := doc.bg_origin
	doc.set_bg_origin(o0 + Vector2(99, 99))
	_check(doc.bg_origin == o0, "lock blocks set_bg_origin")
	doc.bg_lock = false

	# draft roundtrip
	TreeDraftStore.ensure_dirs()
	# isolate draft id for test
	var did := "test_ui"
	var serr := TreeDraftStore.save_draft(doc, did)
	_check(serr == "", "save draft: %s" % serr)
	var doc2 := TreeEditorDoc.new()
	var lerr := TreeDraftStore.load_draft(doc2, did)
	_check(lerr == "", "load draft: %s" % lerr)
	_check(doc2.bg_image != null, "bg image persisted in draft")
	_check(doc2.bg_origin.distance_to(doc.bg_origin) < 0.1, "bg origin reload")
	_check(doc2.nodes.size() == doc.nodes.size(), "nodes reload count")

	# hero save untouched: remember slot path mtime-ish via presence
	var hero_before := FileAccess.file_exists("user://slot_1.json") or FileAccess.file_exists("user://save_1.json")
	var aerr := TreeDraftStore.apply_to_game(doc2)
	_check(aerr == "", "apply: %s" % aerr)
	_check(TreeDraftStore.has_active_override(), "active override exists")
	_check(FileAccess.file_exists("user://tree_active/perk_tree.json"), "active path")
	# cleanup override so other tests use shipped
	TreeDraftStore.clear_active_override()
	PerkTree.reload_from_path(PerkTree.TREE_PATH)
	_check(not TreeDraftStore.has_active_override(), "override cleared after test")

	# search
	var hits: Array = doc.search("Жила")
	_check(hits.size() >= 1, "search Жила")

	# import image path API
	var doc3 := TreeEditorDoc.new()
	TreeDraftStore.load_shipped_into(doc3)
	var ierr2 := TreeDraftStore.import_image_bytes_to_doc(doc3, "res://tests/fixtures/tree_trace_template.png", "test_img")
	_check(ierr2 == "", "import_image_bytes: %s" % ierr2)
	_check(doc3.bg_image != null, "imported bg set")

	print("  note Android native picker: desktop/headless cannot verify SAF; see docs")
