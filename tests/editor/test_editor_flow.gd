extends SceneTree
## generate → edit node → checks → export bundle → import into game (override) → remove → back to v4.

func _init() -> void:
	var failed := 0
	DirAccess.make_dir_recursive_absolute("user://editor_drafts")
	DirAccess.make_dir_recursive_absolute("user://overrides")
	# Clean overrides from prior runs
	_rm("user://overrides/tree.json")
	_rm("user://tree_active/perk_tree.json")

	print("FLOW 1 generate seed 42")
	var core = load("res://scripts/editor/gen/tree_gen_v7_core.gd").new()
	var err: String = str(core.build(42, Callable()))
	var m: Dictionary = core.metrics()
	if err != "" and err != "null":
		print("FAIL gen err ", err); failed += 1
	elif not core.validators_ok(m):
		print("FAIL validators ", m); failed += 1
	else:
		print("  ok gen N=", m.get("N"))

	var tree: Dictionary = core.tree_dict()
	print("FLOW 2 edit node")
	var doc := TreeEditorDoc.new()
	var load_errs: Array = doc.load_from_tree_dict(tree)
	if not load_errs.is_empty():
		print("FAIL load doc ", load_errs); failed += 1
	else:
		var ids: Array = doc.nodes.keys()
		var nid: String = str(ids[mini(5, ids.size() - 1)])
		var n: Dictionary = doc.get_node(nid)
		n["name"] = "Тестовий вузол"
		doc.nodes[nid] = n
		doc.changed.emit()
		if str(doc.get_node(nid).get("name", "")) != "Тестовий вузол":
			print("FAIL edit"); failed += 1
		else:
			print("  ok edited ", nid)

	print("FLOW 3 checks")
	tree = doc.to_tree_dict()
	# Re-validate key counts
	if tree.get("nodes", []).size() < 100:
		print("FAIL checks small"); failed += 1
	else:
		print("  ok checks nodes=", tree.get("nodes", []).size())

	print("FLOW 4 export bundle")
	var bundle_path := "user://editor_drafts/_flow_bundle.zip"
	var layout := LayoutStore.new()
	layout.ensure_defaults()
	var theme := ThemeStore.new()
	theme.reset_to_defaults()
	var berr := BundleIO.export_bundle(bundle_path, tree, layout.to_dict(), theme.to_dict(), {"seed": 42})
	if berr != "":
		print("FAIL export ", berr); failed += 1
	elif not FileAccess.file_exists(bundle_path):
		print("FAIL export missing"); failed += 1
	else:
		print("  ok export")

	print("FLOW 5 import + install override")
	var imp := BundleIO.import_bundle(bundle_path)
	if not imp.get("ok", false):
		print("FAIL import ", imp.get("error")); failed += 1
	else:
		var ierr := BundleIO.install_overrides(imp["tree"], imp["layout"], imp["theme"])
		if ierr != "":
			print("FAIL install ", ierr); failed += 1
		else:
			print("  ok install")

	print("FLOW 6 game sees override")
	PerkTree._loaded = false
	var path := PerkTree.resolve_tree_path()
	if path != PerkTree.OVERRIDE_TREE:
		print("FAIL resolve got ", path); failed += 1
	else:
		var rerr: Array = PerkTree.reload_from_path(path)
		if not rerr.is_empty():
			print("FAIL reload ", rerr); failed += 1
		else:
			var found := false
			var pnodes: Dictionary = PerkTree.nodes()
			for id in pnodes.keys():
				var nn = pnodes[id]
				if typeof(nn) == TYPE_DICTIONARY and str(nn.get("name", "")) == "Тестовий вузол":
					found = true
					break
			var ncount := pnodes.size()
			print("  override nodes=", ncount, " found_edit=", found)
			if ncount < 500:
				print("FAIL override looks like v4"); failed += 1
			else:
				print("  ok game override")

	print("FLOW 7 remove override → v4")
	_rm("user://overrides/tree.json")
	_rm("user://overrides/ui_layout.json")
	_rm("user://overrides/theme.json")
	_rm("user://tree_active/perk_tree.json")
	PerkTree._loaded = false
	var path2 := PerkTree.resolve_tree_path()
	if path2 != PerkTree.TREE_PATH:
		print("FAIL back to shipped got ", path2); failed += 1
	else:
		var r2: Array = PerkTree.reload_from_path(path2)
		var n2 := PerkTree.nodes().size()
		print("  shipped nodes=", n2, " path=", path2)
		# v4 is smaller than v7
		var meta_tag := ""
		# Just ensure we loaded something and not override
		if n2 < 50:
			print("FAIL empty v4"); failed += 1
		else:
			print("  ok back to shipped v4-ish")

	if failed == 0:
		print("EDITOR_FLOW_OK")
		quit(0)
	else:
		print("EDITOR_FLOW_FAILED ", failed)
		quit(1)


func _rm(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
