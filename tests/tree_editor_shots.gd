extends Node
var out_dir := "/tmp/tree_editor_shots"

func frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(2)
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("shot ", name, " ", img.get_size())

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1024, 473))
	get_viewport().size = Vector2i(1024, 473)
	await frames(3)
	var ed: TreeEditorScreen = load("res://scenes/tree_editor.tscn").instantiate()
	ed.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ed)
	ed.size = Vector2(1024, 473)
	ed.set_deferred("size", Vector2(1024, 473))
	await frames(8)
	ed.size = Vector2(1024, 473)
	var img := Image.new()
	var ierr := img.load("res://tests/fixtures/tree_trace_template.png")
	print("fixture load ", ierr)
	ed.doc.bg_lock = false
	ed.doc.set_background_image(img, "bg.png")
	ed.doc.bg_origin = Vector2(-3000, -1000)
	ed.doc.bg_size = Vector2(12000, 12000)
	ed.doc.bg_opacity = 0.55
	ed.doc.bg_visible = true
	var pick := "trunk_s0"
	if ed.doc.nodes.has(pick):
		ed.doc.select(pick)
		ed._view.focus_on(pick, 0.45)
	ed._rebuild_props()
	ed._set_mode(TreeEditorView.Mode.VIEW)
	await frames(6)
	await shot("editor_1024x473_bg_props")
	# action bar rects
	if ed._action_bar:
		print("rect action_bar ", ed._action_bar.get_global_rect())
	if ed._prop_scroll:
		print("rect prop_scroll ", ed._prop_scroll.get_global_rect())
	ed._set_mode(TreeEditorView.Mode.BG)
	ed.doc.bg_lock = false
	await frames(4)
	await shot("editor_1024x473_bg_mode")
	# move mode with selection
	ed._set_mode(TreeEditorView.Mode.MOVE)
	await frames(3)
	await shot("editor_1024x473_move_selected")
	print("viewport ", get_viewport().get_visible_rect())
	get_tree().quit(0)
