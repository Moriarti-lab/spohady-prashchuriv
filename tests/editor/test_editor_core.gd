extends SceneTree
## Headless checks: default tree, layout, theme, bundle round-trip.

func _init() -> void:
	var failed := 0
	failed += _check_default_tree()
	failed += _check_layout()
	failed += _check_theme()
	failed += _check_bundle()
	failed += _check_session_boot()
	if failed == 0:
		print("EDITOR_TESTS_OK")
		quit(0)
	else:
		print("EDITOR_TESTS_FAILED %d" % failed)
		quit(1)


func _check_default_tree() -> int:
	var d: Dictionary = TreeGeneratorV7.load_default_tree()
	if d.is_empty():
		print("FAIL default tree empty")
		return 1
	var nodes = d.get("nodes", [])
	if typeof(nodes) != TYPE_ARRAY or nodes.size() < 900:
		print("FAIL default nodes=", nodes.size() if typeof(nodes)==TYPE_ARRAY else typeof(nodes))
		return 1
	var tag := str(d.get("meta", {}).get("version_tag", ""))
	if tag != "v7.3":
		print("FAIL expected v7.3 got ", tag)
		return 1
	print("OK default tree ", nodes.size(), " ", tag)
	return 0


func _check_layout() -> int:
	var store := LayoutStore.new()
	store.ensure_defaults()
	var els: Array = store.get_elements("hud")
	if els.size() < 5:
		print("FAIL hud elements")
		return 1
	var err := store.save_draft()
	if err != "":
		print("FAIL layout save ", err)
		return 1
	var store2 := LayoutStore.new()
	err = store2.load_draft()
	if err != "":
		print("FAIL layout load ", err)
		return 1
	if store2.get_elements("hud").size() != els.size():
		print("FAIL layout roundtrip size")
		return 1
	var issues: Array = store.check_screen("hud")
	print("OK layout elements=", els.size(), " issues=", issues.size())
	return 0


func _check_theme() -> int:
	var th := ThemeStore.new()
	th.accent = Color(1, 0, 0)
	var err := th.save_draft()
	if err != "":
		print("FAIL theme save ", err)
		return 1
	var th2 := ThemeStore.new()
	err = th2.load_draft()
	if err != "":
		print("FAIL theme load ", err)
		return 1
	if th2.accent.to_html(false) != th.accent.to_html(false):
		print("FAIL theme roundtrip")
		return 1
	th2.apply_to_palette()
	if ThemeRuntime.accent.to_html(false) != th.accent.to_html(false):
		print("FAIL ThemeRuntime apply")
		return 1
	# Restore defaults so drafts are not left pure-red after CI.
	th2.reset_to_defaults()
	th2.save_draft()
	th2.apply_to_palette()
	print("OK theme")
	return 0


func _check_bundle() -> int:
	var tree: Dictionary = TreeGeneratorV7.load_default_tree()
	var layout := LayoutStore.new()
	layout.ensure_defaults()
	var theme := ThemeStore.new()
	var path := "user://editor_drafts/_test_bundle.zip"
	var err := BundleIO.export_bundle(path, tree, layout.to_dict(), theme.to_dict())
	if err != "":
		print("FAIL export ", err)
		return 1
	var r: Dictionary = BundleIO.import_bundle(path)
	if not r.get("ok", false):
		print("FAIL import ", r.get("error"))
		return 1
	if r["tree"].get("nodes", []).size() != tree.get("nodes", []).size():
		print("FAIL bundle tree size")
		return 1
	err = BundleIO.install_overrides(r["tree"], r["layout"], r["theme"])
	if err != "":
		print("FAIL install ", err)
		return 1
	if not FileAccess.file_exists("user://overrides/tree.json"):
		print("FAIL overrides missing")
		return 1
	print("OK bundle roundtrip")
	return 0


func _check_session_boot() -> int:
	var s := EditorSession.new()
	s.boot()
	if s.tree_doc.nodes.size() < 900:
		print("FAIL session tree ", s.tree_doc.nodes.size())
		return 1
	s.autosave()
	print("OK session boot nodes=", s.tree_doc.nodes.size())
	return 0
