## Єдиний формат описів (0.6.0 PoE-стиль): назва → тип → база → вимоги → імпліцити → явні → гнізда → flavour → підказка.
## Текст — BBCode для RichTextLabel. Див. /workspace/next_version/item_tooltips/SPEC.md.
class_name DescFormat

## Data-driven wording: key → template with {n} (already signed, e.g. "+5" / "−2").
const WORDING := {
	"str": "+{n} до Сили",
	"agi": "+{n} до Спритності",
	"faith": "+{n} до Віри",
	"hp": "+{n} до життя",
	"hp_pct": "+{n}% до життя",
	"armor": "+{n} до броні",
	"dmg": "+{n} до шкоди",
	"dmg_pct": "+{n}% до шкоди",
	"atk_speed_pct": "+{n}% до швидкості атаки",
	"crit_pct": "+{n}% до шансу крита",
	"crit_dmg_pct": "+{n}% до шкоди крита",
	"move_pct": "+{n}% до швидкості руху",
	"mana_regen": "+{n} до відновлення чару/с",
	"mana_pct": "+{n}% до чару",
	"mana_regen_pct": "+{n}% до відновлення чару",
	"lifesteal_pct": "{n}% шкоди повертається життям",
	"thorns_pct": "{n}% отриманої шкоди вертається",
	"cdr_pct": "+{n}% до швидкості відновлення вмінь",
	"dr_pct": "{n}% менше отриманої шкоди",
	"gold_pct": "+{n}% до здобичі гривень",
	"drop_pct": "+{n}% до шансу здобичі",
	"xp_pct": "+{n}% до звитяги",
	"hp_regen_pct": "+{n}% життя за секунду",
	"life_on_kill": "+{n} життя за вбивство",
	"mana_on_kill": "+{n} чару за вбивство",
	"dodge_pct": "+{n}% ухилення",
	"block_pct": "+{n}% блоку",
	"block_power_pct": "+{n}% сили блоку",
	"nauz_xp_pct": "+{n}% до росту наузів",
	"aoe_pct": "+{n}% до площі",
	"effect_dur_pct": "+{n}% до тривалості ефектів",
	"skill_cost_pct": "+{n}% до вартості вмінь",
	"double_hit_pct": "+{n}% подвійного удару",
	"proj_speed_pct": "+{n}% швидкості снарядів",
	"armor_pen_pct": "+{n}% пробиття броні",
	"radius_pct": "+{n}% до радіусу",
	"range_pct": "+{n}% до дальності",
	"duration_pct": "+{n}% до тривалості",
	"cd_pct": "+{n}% до часу відновлення",
	"count": "+{n} до кількості",
	"power_pct": "+{n}% сили ефекту",
	"heal_pct": "+{n}% до лікування",
	"stun": "+{n} с оглушення",
	"stun_chance_pct": "+{n}% шансу оглушення",
	"nauz_thread_slots": "+{n} гніздо нитки на наузах",
	"nauz_level": "+{n} до рівня наузів",
	"res_all_pct": "+{n}% опору всім стихіям",
	"res_fire_pct": "+{n}% опору вогню",
	"res_frost_pct": "+{n}% опору морозу",
	"res_thunder_pct": "+{n}% опору грому",
	"res_nature_pct": "+{n}% опору природі",
	"res_light_pct": "+{n}% опору світлу",
	"res_fate_pct": "+{n}% опору долі",
	"pen_all_pct": "+{n}% пробиття всім",
	"pen_fire_pct": "+{n}% пробиття вогню",
	"pen_frost_pct": "+{n}% пробиття морозу",
	"pen_thunder_pct": "+{n}% пробиття грому",
	"pen_nature_pct": "+{n}% пробиття природі",
	"pen_light_pct": "+{n}% пробиття світлу",
	"pen_fate_pct": "+{n}% пробиття долі",
	"thread_power_pct": "+{n}% сили ниток",
	"interval": "{n} с між ударами",
	"range": "+{n} до дальності зброї",
	"arc": "+{n}° дуги",
}

const SEP := "[color=#E0A52666]────────────[/color]"
const UNMET := "D8574B"
const DIM := "B9AE9A"
const LINEN := "F2EBDD"


static func _bb(stat_key: String, text: String) -> String:
	var hex := str(Palette.STAT_BB.get(stat_key, LINEN))
	return "[color=#%s]%s[/color]" % [hex, text]


static func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(round(v)))
	return Strings.num(snappedf(v, 0.1))


static func _signed(v: float) -> String:
	var s := _num(absf(v))
	if v < 0.0:
		return "−" + s
	return "+" + s


static func rarity_name(r: int) -> String:
	return str(Items.rarity(r).get("name", "Звичайний"))


static func rarity_color(r: int) -> Color:
	return Items.rarity(r).get("color", Palette.LINEN) as Color


static func format_stat_line(key: String, value: float, bullet: String = "") -> String:
	var k := str(key)
	var tmpl := str(WORDING.get(k, ""))
	var body: String
	if tmpl == "":
		var legacy := str(PerkTree.STAT_TEXT.get(k, ""))
		if legacy != "":
			body = legacy % _signed(value)
		else:
			body = "RAW_KEY:%s %s" % [k, _signed(value)]
	elif tmpl.begins_with("+{n}"):
		# "+{n} до Сили" → "+5 до Сили" / "−2 до Сили"
		body = tmpl.replace("+{n}", _signed(value))
	elif tmpl.begins_with("{n}"):
		# "{n}% шкоди..." → "5% ..." or "−5% ..."
		body = tmpl.replace("{n}", _num(value) if value >= 0.0 else _signed(value))
	else:
		body = tmpl.replace("{n}", _signed(value))
	var prefix := (bullet + " ") if bullet != "" else ""
	return prefix + _bb(k, body)


static func format_stats_dict(stats: Dictionary, bullet: String = "") -> String:
	var lines: PackedStringArray = []
	for k in PerkTree.STAT_ORDER:
		if stats.has(k) and not is_zero_approx(float(stats[k])):
			lines.append(format_stat_line(str(k), float(stats[k]), bullet))
	for k in stats.keys():
		if str(k) in PerkTree.STAT_ORDER:
			continue
		if is_zero_approx(float(stats[k])):
			continue
		lines.append(format_stat_line(str(k), float(stats[k]), bullet))
	return "\n".join(lines)


## Alias — усі місця мають використовувати item_tooltip.
static func item_bb(item: Dictionary, compare_with: Dictionary = {}, ctx: Dictionary = {}) -> String:
	var c := ctx.duplicate()
	if not compare_with.is_empty():
		c["compare"] = compare_with
	return item_tooltip(item, c)


## ctx: { "where": "bag"|"shop"|"loot"|"nauz"|"editor", "compare": Dictionary, "buy": bool }
static func item_tooltip(item: Dictionary, ctx: Dictionary = {}) -> String:
	if item.is_empty():
		return "[i]Порожньо[/i]"
	if Nauzi.is_nauz(item):
		return _tooltip_nauz(item, ctx)
	if Nauzi.is_thread(item):
		return _tooltip_thread(item, ctx)
	if str(item.get("kind", "")) == "oblivion" or str(item.get("base", "")) == "oblivion_water":
		return _tooltip_consumable(item, ctx, "Вода забуття", "Скидає відкриті вузли Древа (окрім старту), повертає очки перків.")
	if str(item.get("kind", "")).begins_with("potion"):
		var nm := "Зілля життя" if str(item.get("kind", "")) == "potion_hp" else "Зілля чару"
		var fx := "Відновлює життя." if str(item.get("kind", "")) == "potion_hp" else "Відновлює чар."
		return _tooltip_consumable(item, ctx, nm, fx)
	return _tooltip_gear(item, ctx)


static func _sep_if(out: PackedStringArray, need: bool) -> void:
	if need and out.size() > 0:
		out.append(SEP)


static func _type_line(item: Dictionary) -> String:
	var r := int(item.get("rarity", 0))
	var typ := Items.type_of(item)
	var type_ua := str(Items.TYPE_NAMES.get(typ, "Предмет"))
	if Items.is_weapon_type(typ):
		var w := Items.weapon_def(item)
		type_ua = "%s · %s" % [type_ua, Items.kind_name(str(w.get("kind", "")))]
	var ilvl := int(item.get("ilvl", item.get("level", 1)))
	return "[color=#%s]%s · %s · р.%d[/color]" % [DIM, rarity_name(r), type_ua, ilvl]


static func _name_line(item: Dictionary) -> String:
	var name := str(item.get("name", "?"))
	var hex := rarity_color(int(item.get("rarity", 0))).to_html(false)
	return "[b][color=#%s]%s[/color][/b]" % [hex, name]


static func _hint_line(ctx: Dictionary, item: Dictionary) -> String:
	var where := str(ctx.get("where", "bag"))
	match where:
		"shop":
			if bool(ctx.get("buy", true)):
				return "[color=#%s]Купити · %d гривень[/color]" % [DIM, Items.buy_value(item)]
			return "[color=#%s]Продати · %d гривень[/color]" % [DIM, Items.sell_value(item)]
		"loot":
			return "[color=#%s]Підібрати[/color]" % DIM
		"nauz":
			return "[color=#%s]Одягнути / Зняти · нитки — вкладка «Нитки»[/color]" % DIM
		"editor":
			return "[color=#%s]Прев’ю редактора[/color]" % DIM
		_:
			return "[color=#%s]Торкніть «Одягнути» внизу · продаж — у меню «Ще»[/color]" % DIM


static func _price_line(item: Dictionary, ctx: Dictionary) -> String:
	var where := str(ctx.get("where", "bag"))
	if where == "shop" and bool(ctx.get("buy", true)):
		return _bb("gold_pct", "Ціна: %d гривень" % Items.buy_value(item))
	var sell := Items.sell_value(item)
	if sell > 0 and where != "loot":
		return _bb("gold_pct", "Продаж: %d гривень" % sell)
	return ""


static func _tooltip_gear(item: Dictionary, ctx: Dictionary) -> String:
	var out: PackedStringArray = []
	out.append(_name_line(item))
	out.append(_type_line(item))
	var b: Dictionary = Items.base_of(item)
	var typ := Items.type_of(item)
	var base_lines: PackedStringArray = []
	if Items.is_weapon_type(typ):
		var w := Items.weapon_def(item)
		base_lines.append(_bb("dmg_pct", "Шкода  %s" % _num(float(w.get("dmg", 0)))))
		var aps := 0.0
		var iv := float(w.get("interval", 1.0))
		if iv > 0.001:
			aps = 1.0 / iv
		base_lines.append(_bb("atk_speed_pct", "Швидкість атаки  %s уд/с" % _num(snappedf(aps, 0.01))))
		base_lines.append("[color=#%s]Дальність  %s м[/color]" % [LINEN, _num(float(w.get("range", 0)))])
	elif typ in ["shield", "head", "hands", "body", "feet"]:
		var armor_v := float(item.get("stats", {}).get("armor", b.get("armor", 0)))
		# Prefer base armor field; stats.armor may be affix — show base from def if present
		if b.has("armor"):
			armor_v = float(b.get("armor", 0))
			# Include rolled armor from stats if it's the only armor? Keep base here; affix armor goes explicit
		base_lines.append(_bb("armor", "Броня  %s" % _num(armor_v)))
	_sep_if(out, base_lines.size() > 0)
	for ln in base_lines:
		out.append(ln)

	# Requirements — gear currently has none; hide block
	# Implicits = base_stats (not dmg/armor base fields)
	var implicits: Dictionary = {}
	var bs: Variant = b.get("base_stats", {})
	if typeof(bs) == TYPE_DICTIONARY:
		for k in bs:
			if str(k) == "dmg":
				continue
			implicits[str(k)] = float(bs[k])
	# Explicits = item.stats minus implicits keys and weapon dmg
	var explicits: Dictionary = {}
	var st: Variant = item.get("stats", {})
	if typeof(st) == TYPE_DICTIONARY:
		for k in st:
			var ks := str(k)
			if ks == "dmg":
				continue
			if implicits.has(ks) and is_equal_approx(float(st[k]), float(implicits[ks])):
				continue
			# armor on armor pieces: if equals base armor, skip as explicit
			if ks == "armor" and b.has("armor") and is_equal_approx(float(st[k]), float(b["armor"])):
				continue
			explicits[ks] = float(st[k])
	# Don't double-count base_stats values that also appear identical in stats as implicit only
	for k in implicits.keys():
		if explicits.has(k) and is_equal_approx(float(explicits[k]), float(implicits[k])):
			explicits.erase(k)

	_sep_if(out, implicits.size() > 0)
	if implicits.size() > 0:
		out.append(format_stats_dict(implicits, ""))
	_sep_if(out, explicits.size() > 0)
	if explicits.size() > 0:
		out.append(format_stats_dict(explicits, ""))

	var cmp: Dictionary = ctx.get("compare", {})
	if typeof(cmp) == TYPE_DICTIONARY and not cmp.is_empty():
		_sep_if(out, true)
		out.append("[b]Порівняння[/b]")
		out.append(_compare(item, cmp))

	var flavour := str(item.get("flavour", item.get("lore", "")))
	if flavour != "":
		_sep_if(out, true)
		out.append("[i][color=#%s]%s[/color][/i]" % [DIM, flavour])

	var price := _price_line(item, ctx)
	if price != "":
		_sep_if(out, true)
		out.append(price)
	out.append(_hint_line(ctx, item))
	return "\n".join(out)


static func _req_line(label: String, ok: bool, stat_key: String = "") -> String:
	if ok:
		if stat_key != "":
			return "Вимоги: " + _bb(stat_key, label)
		return "[color=#%s]Вимоги: %s[/color]" % [DIM, label]
	return "[color=#%s]Вимоги: %s (не вистачає)[/color]" % [UNMET, label]


static func _tooltip_nauz(item: Dictionary, ctx: Dictionary) -> String:
	var out: PackedStringArray = []
	out.append(_name_line(item))
	var r := int(item.get("rarity", 0))
	var lv := int(item.get("level", 1))
	out.append("[color=#%s]%s · Науз · р.%d[/color]" % [DIM, rarity_name(r), lv])
	_sep_if(out, true)
	out.append("[color=#%s]Рівень науза %d / %d · звитяга %d[/color]" % [LINEN, lv, Nauzi.MAX_LEVEL, int(item.get("xp", 0))])
	out.append("[color=#%s]Сила науза %d[/color]" % [LINEN, Nauzi.power_level(item)])
	var sk := str(item.get("skill", ""))
	var req: Dictionary = Nauzi.requirements(sk, lv)
	_sep_if(out, true)
	var need_lvl := int(req.get("hero_level", 1))
	var lvl_ok := GameState.level >= need_lvl
	out.append(_req_line("рівень героя %d" % need_lvl, lvl_ok))
	var st := str(req.get("stat", "str"))
	var need_stat := int(req.get("stat_min", 1))
	var have := int(HeroStats.stat(st))
	var stat_ok := have >= need_stat
	out.append(_req_line("%s %d" % [Strings.stat_name(st), need_stat], stat_ok, st if stat_ok else ""))
	var reason := Nauzi.can_use(item)
	if reason != "":
		out.append("[color=#%s]%s[/color]" % [UNMET, reason])

	var mods: Dictionary = Nauzi.mods_for_nauz(item)
	_sep_if(out, not mods.is_empty())
	if not mods.is_empty():
		out.append(format_stats_dict(mods, ""))

	_sep_if(out, true)
	var slots := Nauzi.thread_slots(lv)
	var ths: Array = item.get("threads", [])
	if typeof(ths) != TYPE_ARRAY:
		ths = []
	out.append("[b][color=#E0A526]Нитки: %d / %d[/color][/b]" % [ths.size(), slots])
	var unlocks := [1, 8, 15]
	for i in range(3):
		var unlock_at: int = int(unlocks[i]) if i < unlocks.size() else 99
		if i >= slots:
			out.append("[color=#%s]○ порожнє (з р.%d)[/color]" % [DIM, unlock_at])
		elif i < ths.size() and typeof(ths[i]) == TYPE_DICTIONARY:
			var th: Dictionary = ths[i]
			var tnm := str(th.get("name", th.get("thread", "?")))
			var col := str(th.get("color", "white"))
			var sk_col := str(Nauzi.COLOR_STAT.get(col, ""))
			if sk_col == "":
				sk_col = "hp"
			out.append("● " + _bb(sk_col, tnm))
		else:
			out.append("[color=#7CBF5A]○ порожнє[/color]")

	if Skills.has(sk):
		_sep_if(out, true)
		out.append("[i][color=#%s]%s[/color][/i]" % [DIM, Skills.describe(sk, true)])

	var c := ctx.duplicate()
	if str(c.get("where", "")) == "":
		c["where"] = "nauz"
	var price := _price_line(item, c)
	if price != "":
		_sep_if(out, true)
		out.append(price)
	out.append(_hint_line(c, item))
	return "\n".join(out)


static func _tooltip_thread(item: Dictionary, ctx: Dictionary) -> String:
	var out: PackedStringArray = []
	out.append(_name_line(item))
	var r := int(item.get("rarity", 0))
	out.append("[color=#%s]%s · Нитка[/color]" % [DIM, rarity_name(r)])
	_sep_if(out, true)
	var tid := str(item.get("thread", ""))
	var tdef: Dictionary = Nauzi.THREADS.get(tid, {})
	var color := str(item.get("color", "white"))
	var cname := str(Nauzi.COLOR_NAMES.get(color, color))
	var sk := str(Nauzi.COLOR_STAT.get(color, ""))
	if sk != "":
		out.append("Колір: " + _bb(sk, cname))
	else:
		out.append("[color=#%s]Колір: %s[/color]" % [DIM, cname])
	out.append("[color=#%s]Сумісність: %s[/color]" % [DIM, _thread_compat_text(tdef, color)])
	var mods2: Dictionary = tdef.get("mods", {})
	var rmult := 1.0 + 0.1 * float(r)
	var scaled := {}
	for k in mods2:
		scaled[k] = float(mods2[k]) * rmult
	_sep_if(out, not scaled.is_empty())
	if not scaled.is_empty():
		out.append(format_stats_dict(scaled, ""))
	_sep_if(out, true)
	out.append("[color=#%s]Сила від рідкості ×%s[/color]" % [DIM, _num(rmult)])
	var flavour := str(item.get("flavour", ""))
	if flavour != "":
		_sep_if(out, true)
		out.append("[i][color=#%s]%s[/color][/i]" % [DIM, flavour])
	var c := ctx.duplicate()
	if str(c.get("where", "")) == "":
		c["where"] = "bag"
	var price := _price_line(item, c)
	if price != "":
		_sep_if(out, true)
		out.append(price)
	# Thread-specific hint
	if str(c.get("where", "bag")) == "bag":
		out.append("[color=#%s]Вплести у науз — вкладка «Нитки»[/color]" % DIM)
	else:
		out.append(_hint_line(c, item))
	return "\n".join(out)


static func _tooltip_consumable(item: Dictionary, ctx: Dictionary, title: String, effect: String) -> String:
	var out: PackedStringArray = []
	var name := str(item.get("name", title))
	var hex := rarity_color(int(item.get("rarity", 0))).to_html(false)
	out.append("[b][color=#%s]%s[/color][/b]" % [hex, name])
	out.append("[color=#%s]%s · Особливе[/color]" % [DIM, rarity_name(int(item.get("rarity", 0)))])
	_sep_if(out, true)
	out.append("[color=#%s]%s[/color]" % [LINEN, effect])
	var price := _price_line(item, ctx)
	if price != "":
		_sep_if(out, true)
		out.append(price)
	out.append(_hint_line(ctx, item))
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
		lines.append(format_stat_line(str(k), d, "•"))
	return "\n".join(lines) if lines.size() > 0 else "[color=#%s]без змін у числах[/color]" % DIM


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
		"mix", "core":
			return "Рід"
		_:
			return "Рід"


static func node_bb(node_id: String) -> String:
	var d: Dictionary = PerkTree.get_def(node_id)
	if d.is_empty():
		return ""
	var out: PackedStringArray = []
	var typ_ua := node_type_ua(str(d.get("type", "small")))
	var reg_ua := region_ua(str(d.get("region", "")))
	out.append("[color=#%s]%s · %s[/color]" % [DIM, typ_ua, reg_ua])
	var stats: Dictionary = d.get("stats", {})
	if typeof(stats) == TYPE_DICTIONARY and not stats.is_empty():
		out.append("")
		out.append("[b]Властивості[/b]")
		out.append(format_stats_dict(stats, ""))
	var desc := str(d.get("description", ""))
	if desc != "":
		out.append("")
		out.append("[i]%s[/i]" % desc)
	return "\n".join(out)


static func make_rich(_parent: Node = null) -> RichTextLabel:
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.add_theme_color_override("default_color", Palette.LINEN)
	rt.add_theme_font_size_override("normal_font_size", 19)
	return rt


## Повертає "" якщо все гаразд, інакше перший сирий ключ / RAW_KEY.
static func validate_tooltip(item: Dictionary) -> String:
	var bb := item_tooltip(item, {"where": "bag"})
	if "RAW_KEY:" in bb:
		var i := bb.find("RAW_KEY:")
		return bb.substr(i, mini(40, bb.length() - i))
	# no bare english key leftovers like " str " as standalone — soft check
	return ""
