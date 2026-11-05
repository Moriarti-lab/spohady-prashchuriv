## Єдиний формат описів (t60): назва → рідкість·тип·рівень → вимоги → властивості → примітки.
## Текст — BBCode для RichTextLabel.
class_name DescFormat

static func _bb(stat_key: String, text: String) -> String:
	var hex := str(Palette.STAT_BB.get(stat_key, "F2EBDD"))
	return "[color=#%s]%s[/color]" % [hex, text]


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(round(v)))
	return Strings.num(snappedf(v, 0.1))


static func _signed(v: float) -> String:
	var s := _num(v)
	return ("+" + s) if v >= 0.0 else s


static func rarity_name(r: int) -> String:
	var names := ["Звичайний", "Незвичайний", "Рідкісний", "Легендарний"]
	return names[clampi(r, 0, names.size() - 1)]


static func rarity_color(r: int) -> Color:
	match clampi(r, 0, 3):
		1: return Color("7CBF5A")
		2: return Color("5B8DEF")
		3: return Color("E08A4B")
		_: return Palette.LINEN


static func format_stat_line(key: String, value: float) -> String:
	var tmpl := str(PerkTree.STAT_TEXT.get(key, "%s до «" + key + "»"))
	var body := tmpl % _signed(value)
	return "• " + _bb(key, body)


static func format_stats_dict(stats: Dictionary) -> String:
	var lines: PackedStringArray = []
	for k in PerkTree.STAT_ORDER:
		if stats.has(k):
			lines.append(format_stat_line(str(k), float(stats[k])))
	for k in stats.keys():
		if not (str(k) in PerkTree.STAT_ORDER):
			lines.append(format_stat_line(str(k), float(stats[k])))
	return "\n".join(lines)


static func item_bb(item: Dictionary, compare_with: Dictionary = {}) -> String:
	if item.is_empty():
		return "[i]Порожньо[/i]"
	var name := str(item.get("name", "?"))
	var r := int(item.get("rarity", 0))
	var rc := rarity_color(r)
	var hex := rc.to_html(false)
	var typ := Items.type_of(item)
	var type_ua := "Предмет"
	if Nauzi.is_nauz(item):
		type_ua = "Науз"
	elif Nauzi.is_thread(item):
		type_ua = "Нитка"
	elif str(item.get("kind", "")) == "oblivion" or str(item.get("base", "")) == "oblivion_water":
		type_ua = "Особливе"
	elif typ in ["potion", "consumable"] or str(item.get("kind", "")).begins_with("potion"):
		type_ua = "Зілля"
	else:
		type_ua = Items.kind_name(str(item.get("kind", typ)))
	var ilvl := int(item.get("ilvl", item.get("level", 1)))
	var out: PackedStringArray = []
	out.append("[b][color=#%s]%s[/color][/b]" % [hex, name])
	out.append("[color=#B9AE9A]%s · %s · р.%d[/color]" % [rarity_name(r), type_ua, ilvl])
	# requirements / meta for nauz
	if Nauzi.is_nauz(item):
		var sk := str(item.get("skill", ""))
		var req: Dictionary = Nauzi.requirements(sk, int(item.get("level", 1)))
		var st := str(req.get("stat", "str"))
		var st_name := Strings.stat_name(st)
		out.append("Вимоги: рівень героя %d · %s %s" % [
			int(req.get("hero_level", 1)),
			_bb(st, st_name),
			_bb(st, str(int(req.get("stat_min", 1))))
		])
		var reason := Nauzi.can_use(item)
		if reason != "":
			out.append("[color=#D8574B]%s[/color]" % reason)
		out.append("Рівень науза: %d / %d · звитяга %d" % [int(item.get("level", 1)), Nauzi.MAX_LEVEL, int(item.get("xp", 0))])
		var slots := Nauzi.thread_slots(int(item.get("level", 1)))
		var ths: Array = item.get("threads", [])
		out.append("Нитки: %d / %d" % [ths.size(), 3])
		for i in range(3):
			var unlocks := [1, 8, 15]
			var unlock_at: int = int(unlocks[i])
			if i >= slots:
				out.append("[color=#B9AE9A]  гніздо %d — закрите (з р.%d)[/color]" % [i + 1, unlock_at])
			elif i < ths.size() and typeof(ths[i]) == TYPE_DICTIONARY:
				var th: Dictionary = ths[i]
				out.append("  гніздо %d: %s" % [i + 1, str(th.get("name", th.get("thread", "?")))])
			else:
				out.append("[color=#7CBF5A]  гніздо %d — порожнє[/color]" % [i + 1])
		var mods: Dictionary = Nauzi.mods_for_nauz(item)
		if not mods.is_empty():
			out.append("")
			out.append("[b]Властивості вміння[/b]")
			out.append(format_stats_dict(mods))
		if Skills.has(sk):
			out.append("")
			out.append("[i]%s[/i]" % Skills.describe(sk, true))
	elif Nauzi.is_thread(item):
		var tid := str(item.get("thread", ""))
		var tdef: Dictionary = Nauzi.THREADS.get(tid, {})
		var color := str(item.get("color", "white"))
		var cname := str(Nauzi.COLOR_NAMES.get(color, color))
		out.append("Колір: %s · сумісність: %s" % [cname, _thread_compat_text(tdef, color)])
		var mods2: Dictionary = tdef.get("mods", {})
		var rmult := 1.0 + 0.1 * float(r)
		var scaled := {}
		for k in mods2:
			scaled[k] = float(mods2[k]) * rmult
		out.append("")
		out.append("[b]Властивості[/b]")
		out.append(format_stats_dict(scaled))
		out.append("[color=#B9AE9A]Сила від рідкості ×%s[/color]" % _num(rmult))
	else:
		var stats: Dictionary = item.get("stats", {})
		if typeof(stats) == TYPE_DICTIONARY and not stats.is_empty():
			out.append("")
			out.append("[b]Властивості[/b]")
			out.append(format_stats_dict(stats))
		for line in Items.stat_lines(item):
			# avoid duplicating if already covered
			pass
		var lines: Array = Items.stat_lines(item)
		if lines.size() > 0 and (typeof(stats) != TYPE_DICTIONARY or stats.is_empty()):
			out.append("")
			out.append("[b]Властивості[/b]")
			for line2 in lines:
				out.append("• " + str(line2))
		if not compare_with.is_empty():
			out.append("")
			out.append("[b]Порівняння з одягненим[/b]")
			out.append(_compare(item, compare_with))
	var sell := Items.sell_value(item)
	if sell > 0:
		out.append("")
		out.append(_bb("gold_pct", "Продаж: %d гривень" % sell))
	return "\n".join(out)


static func _thread_compat_text(tdef: Dictionary, color: String) -> String:
	var tags: Array = tdef.get("tags", [])
	var parts: PackedStringArray = []
	if color == "white":
		parts.append("будь-який науз")
	else:
		var st := str(Nauzi.COLOR_STAT.get(color, ""))
		if st != "":
			parts.append(Strings.stat_name(st))
	if tags.is_empty():
		parts.append("усі бойові теги")
	else:
		var tag_s: PackedStringArray = []
		for x in tags:
			tag_s.append(str(x))
		parts.append("теги: " + ", ".join(tag_s))
	return ", ".join(parts)


static func _compare(a: Dictionary, b: Dictionary) -> String:
	var sa: Dictionary = a.get("stats", {})
	var sb: Dictionary = b.get("stats", {})
	var keys := {}
	for k in sa:
		keys[k] = true
	for k in sb:
		keys[k] = true
	var lines: PackedStringArray = []
	for k in keys:
		var va := float(sa.get(k, 0))
		var vb := float(sb.get(k, 0))
		var d := va - vb
		if is_zero_approx(d):
			continue
		var sign := "+" if d > 0.0 else ""
		lines.append("• " + _bb(str(k), str(PerkTree.STAT_TEXT.get(str(k), "%s «" + str(k) + "»")) % (sign + _num(d))))
	return "\n".join(lines) if lines.size() > 0 else "[color=#B9AE9A]без змін у числах[/color]"


static func node_type_ua(typ: String) -> String:
	match typ:
		"small":
			return "Малий вузол"
		"notable":
			return "Плід"
		"keystone":
			return "Ключовий вузол"
		"start":
			return "Корінь"
		"core":
			return "Серце роду"
		"skill":
			return "Навичка"
		_:
			return "Вузол"


static func region_ua(region: String) -> String:
	match region:
		"str":
			return "Сила"
		"agi":
			return "Спритність"
		"faith":
			return "Віра"
		"mix":
			return "Рід"
		"core":
			return "Рід"
		_:
			return "Рід"


static func node_bb(node_id: String) -> String:
	var d: Dictionary = PerkTree.get_def(node_id)
	if d.is_empty():
		return ""
	var out: PackedStringArray = []
	# назва вже в заголовку панелі — тут лише тип · регіон
	var typ_ua := node_type_ua(str(d.get("type", "small")))
	var reg_ua := region_ua(str(d.get("region", "")))
	out.append("[color=#B9AE9A]%s · %s[/color]" % [typ_ua, reg_ua])
	var stats: Dictionary = d.get("stats", {})
	if typeof(stats) == TYPE_DICTIONARY and not stats.is_empty():
		out.append("")
		out.append("[b]Властивості[/b]")
		out.append(format_stats_dict(stats))
	var desc := str(d.get("description", ""))
	if desc != "":
		out.append("")
		out.append("[i]%s[/i]" % desc)
	return "\n".join(out)


static func make_rich(parent: Node = null) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_color_override("default_color", Palette.LINEN)
	rt.add_theme_font_size_override("normal_font_size", 19)
	return rt
