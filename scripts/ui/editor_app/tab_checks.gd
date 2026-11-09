## Вкладка «Перевірки»: метрики Древа + розкладка HUD під палець.
class_name EditorTabChecks
extends ScrollContainer

var session: EditorSession
var _out: RichTextLabel


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(body)
	add_child(margin)

	body.add_child(EditorChrome.make_label("Перевірки", 30, Palette.GOLD))
	var run := EditorChrome.make_btn("Запустити всі перевірки", Color("2E7D32"))
	run.pressed.connect(refresh)
	body.add_child(run)

	_out = RichTextLabel.new()
	_out.bbcode_enabled = true
	_out.fit_content = true
	_out.scroll_active = false
	_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_out.custom_minimum_size = Vector2(0, 400)
	_out.add_theme_font_size_override("normal_font_size", 18)
	body.add_child(_out)
	session.tree_changed.connect(refresh)
	session.layout_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if session == null:
		return
	var lines: PackedStringArray = PackedStringArray()
	lines.append("[b]Древо[/b]")
	var doc := session.tree_doc
	var n: int = doc.nodes.size()
	var l: int = doc.links.size()
	lines.append("Вузлів: %d · зв’язків: %d" % [n, l])
	if n < 100:
		lines.append("[color=#E0A526]⚠ Замало вузлів для повного Древа.[/color]")
	# connectivity from class starts
	var starts: Array = []
	for k in doc.class_starts.keys():
		starts.append(str(doc.class_starts[k]))
	var adj: Dictionary = {}
	for link in doc.links:
		var a := str(link[0]); var b := str(link[1])
		if not adj.has(a): adj[a] = []
		if not adj.has(b): adj[b] = []
		adj[a].append(b); adj[b].append(a)
	var orphans := 0
	for id in doc.nodes.keys():
		if not adj.has(id) and str(id) not in starts:
			orphans += 1
	if orphans > 0:
		lines.append("[color=#B3261E]✖ Ізольованих вузлів без зв’язків: %d[/color]" % orphans)
	else:
		lines.append("[color=#7CBF5A]✓ Немає повністю ізольованих вузлів[/color]")
	# validation from doc if any
	if doc.has_method("validate"):
		var verrs: Array = doc.validate()
		for e in verrs:
			lines.append("[color=#E0A526]⚠ %s[/color]" % str(e))
		if verrs.is_empty():
			lines.append("[color=#7CBF5A]✓ Перевірка документа без зауважень[/color]")

	lines.append("")
	lines.append("[b]Розкладка HUD[/b]")
	var issues: Array = session.layout.check_screen("hud")
	if issues.is_empty():
		lines.append("[color=#7CBF5A]✓ Немає попереджень по HUD[/color]")
	else:
		for it in issues:
			var col := "#E0A526" if it.get("level") == "warn" else "#B9AE9A"
			lines.append("[color=%s]• %s[/color]" % [col, it.get("msg")])

	lines.append("")
	lines.append("[b]Тема[/b]")
	lines.append("Панель %s · акцент %s · HP %s · чар %s" % [
		session.theme.panel.to_html(false), session.theme.accent.to_html(false),
		session.theme.hp.to_html(false), session.theme.mana.to_html(false)])

	_out.text = "\n".join(lines)
