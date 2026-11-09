extends SceneTree
## Відкриває editor_main, перемикає вкладки, зберігає скріншоти 1920×864.

const OUT := "user://editor_drafts/screenshots"
const W := 1920
const H := 864


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(W, H))
	get_root().size = Vector2i(W, H)
	await process_frame
	await process_frame
	var err := change_scene_to_file("res://scenes/editor_app/editor_main.tscn")
	if err != OK:
		print("FAIL change_scene ", err)
		quit(1)
		return
	await create_timer(0.8).timeout
	var tree_root := self.root
	var main := _find_editor(tree_root)
	if main == null:
		print("FAIL no EditorMain")
		quit(1)
		return
	var tabs: TabContainer = _find_tabs(main)
	if tabs == null:
		print("FAIL no TabContainer")
		quit(1)
		return
	print("TABS ", tabs.get_tab_count(), " vp=", get_root().size, " vis=", tree_root.get_viewport().get_visible_rect().size)
	if tabs.get_tab_count() != 7:
		print("FAIL expected 7 tabs got ", tabs.get_tab_count())
		quit(1)
		return
	for i in range(tabs.get_tab_count()):
		tabs.current_tab = i
		await create_timer(0.55 if i == 1 else 0.4).timeout
		if i == 1:
			# Tree: ensure fit after layout
			var tree_tab = tabs.get_current_tab_control()
			var screen = _find_tree_screen(tree_tab)
			if screen and screen.get("_view") and screen._view.has_method("fit_all"):
				screen._view.fit_all()
				await create_timer(0.25).timeout
		if i == 3:
			var gen = tabs.get_current_tab_control()
			if gen:
				if gen.get("_seed"):
					gen._seed.text = str(TreeGeneratorV7.DEFAULT_SEED)
				if gen.has_method("_on_run"):
					gen._on_run()
				# Wait until not busy (default seed returns sync; others async)
				var waited := 0.0
				while gen.get("_busy") == true and waited < 90.0:
					await create_timer(0.25).timeout
					waited += 0.25
				await create_timer(0.35).timeout
		await process_frame
		await process_frame
		var tex := tree_root.get_viewport().get_texture()
		if tex == null:
			print("FAIL no viewport tex tab ", i)
			continue
		var img: Image = tex.get_image()
		if img == null:
			print("FAIL null image tab ", i)
			continue
		# Ensure exact docs size
		if img.get_width() != W or img.get_height() != H:
			img.resize(W, H, Image.INTERPOLATE_BILINEAR)
		var path := "%s/tab_%d.png" % [OUT, i]
		img.save_png(path)
		print("SHOT ", path, " ", img.get_width(), "x", img.get_height())
	var session = main.get("session")
	if session:
		var zip := "user://editor_drafts/ui_test_bundle.zip"
		print("EXPORT ", session.export_bundle(zip))
		print("IMPORT ", session.import_bundle(zip))
		print("GEN_DEFAULT ", session.generate_tree(TreeGeneratorV7.DEFAULT_SEED), " nodes=", session.tree_doc.nodes.size())
	var docs_abs := ProjectSettings.globalize_path("res://docs/editor_app/screenshots")
	DirAccess.make_dir_recursive_absolute(docs_abs)
	for i in range(tabs.get_tab_count()):
		var src := "%s/tab_%d.png" % [OUT, i]
		var dst := "%s/tab_%d.png" % [docs_abs, i]
		if FileAccess.file_exists(src):
			var img2 := Image.load_from_file(src)
			if img2:
				img2.save_png(dst)
				print("DOC_SHOT ", dst)
	print("EDITOR_UI_TESTS_OK")
	quit(0)


func _find_editor(n: Node) -> Node:
	if n.get_script() != null and str(n.get_script().resource_path).ends_with("editor_main.gd"):
		return n
	for c in n.get_children():
		var f := _find_editor(c)
		if f:
			return f
	return null


func _find_tabs(n: Node) -> TabContainer:
	if n is TabContainer:
		return n
	for c in n.get_children():
		var f := _find_tabs(c)
		if f:
			return f
	return null


func _find_tree_screen(n: Node) -> Node:
	if n == null:
		return null
	if n.get_script() != null and str(n.get_script().resource_path).ends_with("tree_editor_screen.gd"):
		return n
	for c in n.get_children():
		var f := _find_tree_screen(c)
		if f:
			return f
	return null
