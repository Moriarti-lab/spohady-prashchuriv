extends SceneTree
## Відкриває editor_main, перемикає вкладки, зберігає скріншоти.

const OUT := "user://editor_drafts/screenshots"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	call_deferred("_run")


func _run() -> void:
	var err := change_scene_to_file("res://scenes/editor_app/editor_main.tscn")
	if err != OK:
		print("FAIL change_scene ", err)
		quit(1)
		return
	await create_timer(0.35).timeout
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
	print("TABS ", tabs.get_tab_count())
	if tabs.get_tab_count() != 7:
		print("FAIL expected 7 tabs got ", tabs.get_tab_count())
		quit(1)
		return
	for i in range(tabs.get_tab_count()):
		tabs.current_tab = i
		await create_timer(0.2).timeout
		var tex := tree_root.get_viewport().get_texture()
		if tex == null:
			print("FAIL no viewport tex tab ", i)
			continue
		var img: Image = tex.get_image()
		var path := "%s/tab_%d.png" % [OUT, i]
		img.save_png(path)
		print("SHOT ", path, " ", img.get_width(), "x", img.get_height())
	var session = main.get("session")
	if session:
		var zip := "user://editor_drafts/ui_test_bundle.zip"
		print("EXPORT ", session.export_bundle(zip))
		print("IMPORT ", session.import_bundle(zip))
		print("GEN_DEFAULT ", session.generate_tree(424242), " nodes=", session.tree_doc.nodes.size())
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
