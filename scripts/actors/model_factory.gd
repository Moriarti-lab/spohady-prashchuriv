## Прості low-poly моделі героя й ворогів, зібрані з примітивів (плейсхолдери).
## Пізніше їх можна замінити готовими CC0-моделями, не чіпаючи решти коду.
## Усі моделі дивляться в бік −Z, початок координат — біля ніг.
class_name ModelFactory

const SKIN := Color("E3B58C")
const HAIR := Color("5A3B26")
const PANTS := Color("5E4A36")
const LEATHER := Color("3E2C20")
const STEEL_LIGHT := Color("A9B0BA")
const STEEL_DARK := Color("6F7782")
const WOOD := Color("7A5532")
const CLOTH_BLUE := Color("2F5E78")


static func _v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


# =====================================================================
#  ГЕРОЙ
# =====================================================================

const HERO_RIGS := {"druzhynnyk": "Knight", "strilets": "Rogue_Hooded", "volkhv": "Mage"}
## Основа предмета → меш із KayKit Fantasy Weapons Bits (CC0).
const WEAPON_MESH := {
	"sword": "sword_A", "axe": "axe_A", "dagger": "dagger_A", "mace": "hammer_C", "hammer": "hammer_A",
	"wand": "wand_A", "spear": "spear_A", "greatsword": "sword_E", "greataxe": "axe_D",
	"bow": "bow_A_withString", "longbow": "bow_B_withString", "crossbow": "bow_C_withString",
	"staff": "staff_A", "magic_staff": "staff_C",
	"shield_round": "shield_A", "shield_kite": "shield_C", "shield_sun": "shield_D",
}
static var use_rigs := true
static var _weapon_scenes := {}


static func weapon_mesh(base_id: String) -> Node3D:
	if not WEAPON_MESH.has(base_id):
		return null
	var path := "res://models/weapons/%s.gltf" % WEAPON_MESH[base_id]
	if not _weapon_scenes.has(path):
		_weapon_scenes[path] = load(path) if ResourceLoader.exists(path) else null
	if _weapon_scenes[path] == null:
		return null
	return (_weapon_scenes[path] as PackedScene).instantiate()


## Герой на анімованій моделі KayKit; зброя й щит із предметів — у руках.
static func hero_rig(class_id: String, accent: Color, weapon_base: String, off_base: String) -> Node3D:
	var r := RigModel.create(str(HERO_RIGS.get(class_id, "Knight")), 0.78)
	if r == null:
		return null
	var wp := Node3D.new()
	wp.name = "WeaponPivot"
	var kind := ""
	if Items.BASES.has(weapon_base) and Items.BASES[weapon_base].has("kind"):
		kind = str(Items.BASES[weapon_base]["kind"])
	wp.set_meta("kind", kind)
	wp.set_meta("rig", true)
	var hand := r.left_hand if kind == "arrow" else r.right_hand
	hand.add_child(wp)
	var w := weapon_mesh(weapon_base)
	if w != null:
		wp.add_child(w)
		if kind == "magic":
			var top := 1.0 if weapon_base == "wand" else 1.9
			var orb := LowPoly.glow_instance(LowPoly.ball(0.1, _v(0, top, 0), accent, 6), accent, 2.5)
			orb.name = "Orb"
			wp.add_child(orb)
	var two := Items.BASES.has(weapon_base) and str(Items.BASES[weapon_base]["type"]) == "hand2"
	r.set_meta("two_handed", two)
	if two and kind == "melee":
		r.idle_anim = "2H_Melee_Idle"
	if Items.BASES.has(off_base) and kind != "arrow":
		var o := weapon_mesh(off_base)
		if o == null and str(Items.BASES[off_base]["type"]) == "hand1":
			o = weapon_mesh(off_base)
		if o != null:
			r.left_hand.add_child(o)
	return r


static func hero(class_id: String, accent: Color, weapon_base: String = "", off_base: String = "") -> Node3D:
	if use_rigs:
		var rig := hero_rig(class_id, accent, weapon_base, off_base)
		if rig != null:
			return rig
	var root := Node3D.new()
	root.name = "Model"
	var body: Array = []
	var shirt: Color = Palette.LINEN
	if class_id == "strilets":
		shirt = Color("7C8A94")
	elif class_id == "volkhv":
		shirt = CLOTH_BLUE
	# ноги й чоботи
	body.append(LowPoly.box(_v(0.17, 0.72, 0.22), _v(-0.13, 0.36, 0), PANTS))
	body.append(LowPoly.box(_v(0.17, 0.72, 0.22), _v(0.13, 0.36, 0), PANTS))
	body.append(LowPoly.box(_v(0.2, 0.14, 0.32), _v(-0.13, 0.07, -0.04), LEATHER))
	body.append(LowPoly.box(_v(0.2, 0.14, 0.32), _v(0.13, 0.07, -0.04), LEATHER))
	# сорочка з вишивкою
	body.append(LowPoly.cyl(0.24, 0.28, 0.66, _v(0, 1.05, 0), shirt))
	body.append(LowPoly.cyl(0.285, 0.285, 0.09, _v(0, 0.76, 0), Palette.EMBROIDERY))
	body.append(LowPoly.cyl(0.25, 0.25, 0.06, _v(0, 1.37, 0), Palette.EMBROIDERY))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		body.append(LowPoly.box(_v(0.05, 0.05, 0.02), _v(sin(a) * 0.255, 1.37, -cos(a) * 0.255), Palette.GOLD, _v(0, -rad_to_deg(a), 0)))
	# голова
	body.append(LowPoly.ball(0.21, _v(0, 1.58, 0), SKIN, 7))
	body.append(LowPoly.box(_v(0.05, 0.05, 0.05), _v(0, 1.55, -0.2), SKIN))
	body.append(LowPoly.box(_v(0.04, 0.05, 0.02), _v(-0.08, 1.6, -0.2), Palette.NIGHT))
	body.append(LowPoly.box(_v(0.04, 0.05, 0.02), _v(0.08, 1.6, -0.2), Palette.NIGHT))
	# руки (рукави)
	var sleeve: Color = shirt
	body.append(LowPoly.box(_v(0.13, 0.5, 0.13), _v(-0.37, 1.08, -0.1), sleeve, _v(-25, 0, 8)))
	body.append(LowPoly.box(_v(0.13, 0.5, 0.13), _v(0.37, 1.08, -0.12), sleeve, _v(-35, 0, -8)))
	body.append(LowPoly.ball(0.07, _v(-0.42, 0.86, -0.27), SKIN, 5))
	body.append(LowPoly.ball(0.07, _v(0.42, 0.87, -0.32), SKIN, 5))

	var wp := Node3D.new()
	wp.name = "WeaponPivot"
	root.add_child(wp)

	match class_id:
		"druzhynnyk":
			body.append(LowPoly.cyl(0.27, 0.31, 0.5, _v(0, 1.08, 0), STEEL_DARK, 8))
			body.append(LowPoly.cyl(0.3, 0.3, 0.07, _v(0, 0.8, 0), Palette.GOLD, 8))
			body.append(LowPoly.ball(0.16, _v(-0.39, 1.32, 0), STEEL_LIGHT, 6))
			body.append(LowPoly.ball(0.16, _v(0.39, 1.32, 0), STEEL_LIGHT, 6))
			body.append(LowPoly.cyl(0.04, 0.23, 0.26, _v(0, 1.78, 0), STEEL_LIGHT, 8))
			body.append(LowPoly.cyl(0.25, 0.25, 0.05, _v(0, 1.66, 0), STEEL_DARK, 8))
			body.append(LowPoly.box(_v(0.04, 0.16, 0.04), _v(0, 1.97, 0), Palette.EMBROIDERY))
		"strilets":
			body.append(LowPoly.cyl(0.26, 0.3, 0.55, _v(0, 1.05, 0), Color("8E99A3"), 8))  # кольчуга
			body.append(LowPoly.ball(0.25, _v(0, 1.62, 0.02), Color("8E99A3"), 7, _v(1, 0.8, 1)))  # каптур
			body.append(LowPoly.box(_v(0.62, 0.95, 0.05), _v(0, 1.0, 0.22), Palette.LEAF, _v(8, 0, 0)))  # плащ
			body.append(LowPoly.cyl(0.08, 0.08, 0.55, _v(0.16, 1.2, 0.3), WOOD, 6, _v(0, 0, 14)))  # сагайдак
			for i in range(3):
				body.append(LowPoly.box(_v(0.03, 0.12, 0.03), _v(0.2 + i * 0.03, 1.5, 0.3), Palette.LINEN))
		_:  # волхв
			body.append(LowPoly.cyl(0.22, 0.48, 1.05, _v(0, 0.58, 0), CLOTH_BLUE, 8))   # балахон
			body.append(LowPoly.cyl(0.49, 0.49, 0.1, _v(0, 0.08, 0), Palette.EMBROIDERY, 8))
			for i in range(8):
				var a2 := TAU * float(i) / 8.0
				body.append(LowPoly.box(_v(0.07, 0.07, 0.025), _v(sin(a2) * 0.5, 0.1, -cos(a2) * 0.5), Palette.GOLD, _v(0, -rad_to_deg(a2), 0)))
			body.append(LowPoly.cyl(0.215, 0.215, 0.06, _v(0, 1.68, 0), Palette.EMBROIDERY, 8))  # очіпок-пов'язка
			body.append(LowPoly.cone(0.13, 0.42, _v(0, 1.32, -0.15), Color("D9D6CF"), 5))       # борода
			body.append(LowPoly.box(_v(0.4, 0.5, 0.06), _v(0, 1.4, 0.2), Color("CFCBC2")))      # довге волосся
	_add_weapon(wp, weapon_base, class_id, accent)
	_add_offhand(root, body, off_base)
	# амулет благословення на грудях
	body.append(LowPoly.cyl(0.075, 0.075, 0.03, _v(0, 1.2, -0.285), Palette.GOLD, 8, _v(90, 0, 0)))
	root.add_child(LowPoly.instance(body))
	var gem := LowPoly.glow_instance(LowPoly.ball(0.05, _v(0, 1.2, -0.31), accent, 5), accent, 3.0)
	root.add_child(gem)
	return root


## Зброя в руці героя за ідентифікатором основи (sword, axe, bow, longbow, staff, wand).
## Порожній id — без зброї (голі руки).
## Ліва рука: щит або друга зброя. body — масив примітивів тулуба.
static func _add_offhand(root: Node3D, body: Array, off_base: String) -> void:
	if not Items.BASES.has(off_base):
		return
	var b: Dictionary = Items.BASES[off_base]
	if str(b["type"]) == "shield":
		var col: Color = Palette.EMBROIDERY if off_base != "shield_sun" else Palette.GOLD
		body.append(LowPoly.cyl(0.32, 0.32, 0.07, _v(-0.5, 1.0, -0.3), col, 8, _v(90, 0, 0)))
		body.append(LowPoly.cyl(0.34, 0.34, 0.04, _v(-0.5, 1.0, -0.26), Palette.GOLD if off_base != "shield_sun" else Palette.EMBROIDERY, 8, _v(90, 0, 0)))
		body.append(LowPoly.ball(0.1, _v(-0.5, 1.0, -0.38), Palette.GOLD, 5))
	elif str(b["type"]) == "hand1":
		var blade: Color = STEEL_LIGHT
		body.append(LowPoly.box(_v(0.06, 0.8, 0.025), _v(-0.46, 1.25, -0.5), blade, _v(-55, 0, 0)))
		body.append(LowPoly.box(_v(0.24, 0.05, 0.05), _v(-0.46, 0.96, -0.36), Palette.GOLD, _v(-55, 0, 0)))


static func _add_weapon(wp: Node3D, base_id: String, class_id: String, accent: Color) -> void:
	var kind := ""
	if Items.BASES.has(base_id) and Items.BASES[base_id].has("kind"):
		kind = str(Items.BASES[base_id]["kind"])
	wp.set_meta("kind", kind)
	match kind:
		"melee":
			wp.position = _v(0.42, 0.9, -0.35)
			wp.rotation_degrees = _v(-15, 0, 0)
			var sw: Array = []
			if base_id == "axe" or base_id == "greataxe":
				var big := 1.25 if base_id == "greataxe" else 1.0
				sw.append(LowPoly.box(_v(0.05, 0.9 * big, 0.05), _v(0, 0.5 * big, 0), WOOD))
				sw.append(LowPoly.box(_v(0.06, 0.34 * big, 0.3 * big), _v(0, 0.92 * big, -0.1), STEEL_LIGHT))
				sw.append(LowPoly.prism(_v(0.06, 0.2, 0.14), _v(0, 0.92 * big, -0.32 * big), STEEL_LIGHT, _v(0, 0, 0)))
				sw.append(LowPoly.box(_v(0.07, 0.18, 0.07), _v(0, -0.02, 0), LEATHER))
			elif base_id == "mace" or base_id == "hammer":
				var hs := 1.0 if base_id == "mace" else 1.4
				sw.append(LowPoly.box(_v(0.05, 0.85, 0.05), _v(0, 0.45, 0), WOOD))
				sw.append(LowPoly.box(_v(0.16 * hs, 0.16 * hs, 0.16 * hs), _v(0, 0.92, 0), STEEL_DARK))
				sw.append(LowPoly.box(_v(0.07, 0.18, 0.07), _v(0, -0.02, 0), LEATHER))
			elif base_id == "spear":
				sw.append(LowPoly.box(_v(0.04, 1.9, 0.04), _v(0, 0.8, 0), WOOD))
				sw.append(LowPoly.prism(_v(0.08, 0.3, 0.03), _v(0, 1.9, 0), STEEL_LIGHT))
			elif base_id == "dagger":
				sw.append(LowPoly.box(_v(0.05, 0.4, 0.02), _v(0, 0.3, 0), STEEL_LIGHT))
				sw.append(LowPoly.prism(_v(0.05, 0.1, 0.02), _v(0, 0.55, 0), STEEL_LIGHT))
				sw.append(LowPoly.box(_v(0.18, 0.04, 0.05), _v(0, 0.1, 0), Palette.GOLD))
				sw.append(LowPoly.box(_v(0.05, 0.14, 0.05), _v(0, -0.01, 0), LEATHER))
			else:
				var ln := 1.25 if base_id == "greatsword" else 1.0
				sw.append(LowPoly.box(_v(0.07 * ln, 0.95 * ln, 0.025), _v(0, 0.62 * ln, 0), STEEL_LIGHT))
				sw.append(LowPoly.prism(_v(0.07 * ln, 0.15, 0.025), _v(0, 0.62 * ln + 0.55 * ln, 0), STEEL_LIGHT))
				sw.append(LowPoly.box(_v(0.3, 0.05, 0.06), _v(0, 0.12, 0), Palette.GOLD))
				sw.append(LowPoly.box(_v(0.06, 0.2, 0.06), _v(0, -0.02, 0), LEATHER))
			wp.add_child(LowPoly.instance(sw))
		"arrow":
			var k := 1.0 if base_id == "bow" else 1.2
			wp.position = _v(-0.45, 1.05, -0.4)
			wp.rotation_degrees = Vector3.ZERO
			var bow: Array = []
			bow.append(LowPoly.box(_v(0.06, 0.22, 0.06), _v(0, 0, 0), WOOD))
			bow.append(LowPoly.box(_v(0.05, 0.55 * k, 0.05), _v(0, 0.36 * k, 0.08), WOOD, _v(18, 0, 0)))
			bow.append(LowPoly.box(_v(0.05, 0.55 * k, 0.05), _v(0, -0.36 * k, 0.08), WOOD, _v(-18, 0, 0)))
			bow.append(LowPoly.box(_v(0.012, 1.15 * k, 0.012), _v(0, 0, 0.19), Palette.LINEN))
			if base_id == "longbow":
				bow.append(LowPoly.box(_v(0.07, 0.1, 0.07), _v(0, 0, 0), Palette.GOLD))
			wp.add_child(LowPoly.instance(bow))
		"magic":
			wp.position = _v(0.46, 0.9, -0.3)
			wp.rotation_degrees = _v(-8, 0, 0)
			var staff: Array = []
			if base_id == "wand":
				staff.append(LowPoly.cyl(0.03, 0.04, 0.9, _v(0, 0.4, 0), WOOD, 6))
				staff.append(LowPoly.ball(0.07, _v(0, 0.9, 0), Palette.GOLD, 5))
				wp.add_child(LowPoly.instance(staff))
				var orb2 := LowPoly.glow_instance(LowPoly.ball(0.09, _v(0, 1.0, 0), accent, 6), accent, 2.5)
				orb2.name = "Orb"
				wp.add_child(orb2)
			else:
				staff.append(LowPoly.cyl(0.035, 0.045, 1.95, _v(0, 0.62, 0), WOOD, 6))
				staff.append(LowPoly.ball(0.1, _v(0, 1.62, 0), Palette.GOLD, 5))
				wp.add_child(LowPoly.instance(staff))
				var orb := LowPoly.glow_instance(LowPoly.ball(0.13, _v(0, 1.8, 0), accent, 6), accent, 2.5)
				orb.name = "Orb"
				wp.add_child(orb)
		_:
			wp.position = _v(0.42, 0.9, -0.35)


# =====================================================================
#  ВОРОГИ ОРДЕНУ
# =====================================================================

static var _enemy_cache := {}


## Модель ворога. Перша збірка кладеться в кеш, далі повертаються копії зі спільними мешами
## (щоб поява ворога не гальмувала гру).
const ENEMY_RIGS := {
	"novice": ["Rogue", 0.74, ["Rogue_Cape"]], "archer": ["Rogue_Hooded", 0.74, []], "brute": ["Barbarian", 0.95, []],
	"wraith": ["Skeleton_Mage", 0.78, []], "skel_minion": ["Skeleton_Minion", 0.76, []],
	"skel_warrior": ["Skeleton_Warrior", 0.82, []], "skel_rogue": ["Skeleton_Rogue", 0.76, []], "skel_mage": ["Skeleton_Mage", 0.78, []],
}
## Зброя в руках анімованих ворогів.
const ENEMY_WEAPONS := {
	"novice": ["dagger", ""], "archer": ["", "bow"], "brute": ["greataxe", ""], "wraith": ["staff", ""],
	"skel_minion": ["sword", ""], "skel_warrior": ["axe", "shield_round"], "skel_rogue": ["", "bow"], "skel_mage": ["magic_staff", ""],
}


static func enemy(kind: String) -> Node3D:
	if use_rigs and ENEMY_RIGS.has(kind):
		var e: Array = ENEMY_RIGS[kind]
		var r := RigModel.create(str(e[0]), float(e[1]))
		if r != null:
			r.hide_parts(e[2])
			var w: Array = ENEMY_WEAPONS.get(kind, ["", ""])
			var mw := weapon_mesh(str(w[0]))
			if mw != null:
				r.right_hand.add_child(mw)
			var lw := weapon_mesh(str(w[1]))
			if lw != null:
				r.left_hand.add_child(lw)
			if kind.begins_with("skel") or kind == "wraith":
				r.walk_anim = "Walking_D_Skeletons"
				r.idle_anim = "Idle_Combat" if kind == "skel_warrior" else "Idle"
			if kind == "wraith":
				_ghostify(r)
			return r
	if not _enemy_cache.has(kind):
		var t: Node3D = null
		match kind:
			"novice":
				t = _novice()
			"werewolf":
				t = _werewolf_human()
			"wraith":
				t = _wraith()
			"beast":
				t = werewolf_beast_build()
			"hound":
				t = _hound()
			"archer":
				t = _archer()
			"brute":
				t = _brute()
			_:
				t = Node3D.new()
		_enemy_cache[kind] = t
	return (_enemy_cache[kind] as Node3D).duplicate()


static func werewolf_beast() -> Node3D:
	return enemy("beast")


static func _novice() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var cloak := Palette.ASH.darkened(0.25)
	var hood := Palette.STEEL.darkened(0.2)
	var p: Array = []
	p.append(LowPoly.cyl(0.18, 0.52, 1.75, _v(0, 0.88, 0), cloak, 7))
	p.append(LowPoly.cyl(0.54, 0.54, 0.06, _v(0, 0.05, 0), cloak.darkened(0.3), 7))
	p.append(LowPoly.ball(0.27, _v(0, 1.82, 0.02), hood, 7, _v(1, 1.25, 1)))
	p.append(LowPoly.cone(0.2, 0.4, _v(0, 2.15, 0.1), hood, 7))
	p.append(LowPoly.box(_v(0.09, 0.8, 0.09), _v(-0.34, 1.25, -0.3), cloak, _v(-60, 0, 8)))
	p.append(LowPoly.box(_v(0.09, 0.8, 0.09), _v(0.34, 1.25, -0.3), cloak, _v(-60, 0, -8)))
	p.append(LowPoly.ball(0.07, _v(-0.38, 1.0, -0.62), Color("C9C2B5"), 5))
	p.append(LowPoly.ball(0.07, _v(0.38, 1.0, -0.62), Color("C9C2B5"), 5))
	p.append(LowPoly.box(_v(0.6, 0.06, 0.06), _v(0, 1.05, -0.02), Palette.BLOOD.darkened(0.2)))
	root.add_child(LowPoly.instance(p))
	# безлике обличчя: порожнє біле коло (знак Ордену)
	var face := LowPoly.glow_instance(LowPoly.cyl(0.15, 0.15, 0.03, _v(0, 1.8, -0.27), Color("F4F4F0"), 12, _v(90, 0, 0)), Color("F4F4F0"), 0.8)
	root.add_child(face)
	var chest := LowPoly.glow_instance(LowPoly.cyl(0.1, 0.1, 0.02, _v(0, 1.3, -0.3), Color("F4F4F0"), 12, _v(90, 0, 0)), Color("F4F4F0"), 0.6)
	root.add_child(chest)
	return root


static func _werewolf_human() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var fur := Color("4A4038")
	var p: Array = []
	p.append(LowPoly.box(_v(0.17, 0.8, 0.2), _v(-0.15, 0.4, 0), Color("3A322C")))
	p.append(LowPoly.box(_v(0.17, 0.8, 0.2), _v(0.15, 0.4, 0), Color("3A322C")))
	p.append(LowPoly.cyl(0.3, 0.26, 0.8, _v(0, 1.15, -0.06), fur, 6, _v(-18, 0, 0)))  # згорблений тулуб
	p.append(LowPoly.ball(0.22, _v(0, 1.62, -0.28), Color("6E5E50"), 6))
	p.append(LowPoly.box(_v(0.16, 0.14, 0.2), _v(0, 1.54, -0.46), Color("6E5E50")))
	p.append(LowPoly.prism(_v(0.1, 0.16, 0.06), _v(-0.12, 1.84, -0.26), fur))
	p.append(LowPoly.prism(_v(0.1, 0.16, 0.06), _v(0.12, 1.84, -0.26), fur))
	p.append(LowPoly.box(_v(0.1, 0.95, 0.1), _v(-0.4, 1.0, -0.2), fur, _v(-15, 0, 6)))
	p.append(LowPoly.box(_v(0.1, 0.95, 0.1), _v(0.4, 1.0, -0.2), fur, _v(-15, 0, -6)))
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.05, 0.04, 0.02), _v(-0.08, 1.66, -0.5), Color("FFD23F"), Vector3.ZERO), Color("FFD23F"), 3.0))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.05, 0.04, 0.02), _v(0.08, 1.66, -0.5), Color("FFD23F"), Vector3.ZERO), Color("FFD23F"), 3.0))
	return root


static func werewolf_beast_build() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var fur := Color("3B3B45")
	var p: Array = []
	p.append(LowPoly.box(_v(0.65, 0.6, 1.2), _v(0, 0.85, 0.05), fur, _v(-6, 0, 0)))
	p.append(LowPoly.box(_v(0.5, 0.5, 0.5), _v(0, 1.0, -0.7), fur.lightened(0.1)))
	p.append(LowPoly.box(_v(0.26, 0.24, 0.45), _v(0, 0.93, -1.08), fur.lightened(0.15)))
	p.append(LowPoly.prism(_v(0.14, 0.24, 0.08), _v(-0.17, 1.38, -0.62), fur))
	p.append(LowPoly.prism(_v(0.14, 0.24, 0.08), _v(0.17, 1.38, -0.62), fur))
	p.append(LowPoly.box(_v(0.14, 0.7, 0.16), _v(-0.28, 0.42, -0.45), fur))
	p.append(LowPoly.box(_v(0.14, 0.7, 0.16), _v(0.28, 0.42, -0.45), fur))
	p.append(LowPoly.box(_v(0.16, 0.7, 0.18), _v(-0.28, 0.42, 0.5), fur))
	p.append(LowPoly.box(_v(0.16, 0.7, 0.18), _v(0.28, 0.42, 0.5), fur))
	p.append(LowPoly.cone(0.1, 0.8, _v(0, 0.95, 0.85), fur, 5))
	for sx in [-1.0, 1.0]:
		for i in range(3):
			p.append(LowPoly.box(_v(0.03, 0.03, 0.14), _v(0.28 * sx + (i - 1) * 0.04 * sx, 0.04, -0.58), Palette.LINEN))
	p.append(LowPoly.box(_v(0.2, 0.04, 0.1), _v(0, 0.8, -1.25), Palette.BLOOD))  # паща
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.07, 0.05, 0.03), _v(-0.13, 1.1, -0.96), Color("FFD23F")), Color("FFD23F"), 3.5))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.07, 0.05, 0.03), _v(0.13, 1.1, -0.96), Color("FFD23F")), Color("FFD23F"), 3.5))
	root.scale = Vector3.ONE * 1.1
	return root


static func _hound() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var fur := Color("5A4A3C")
	var p: Array = []
	p.append(LowPoly.box(_v(0.4, 0.38, 0.9), _v(0, 0.58, 0.05), fur))
	p.append(LowPoly.box(_v(0.32, 0.32, 0.36), _v(0, 0.7, -0.55), fur.lightened(0.08)))
	p.append(LowPoly.box(_v(0.18, 0.16, 0.3), _v(0, 0.62, -0.82), fur.lightened(0.14)))
	p.append(LowPoly.prism(_v(0.1, 0.16, 0.05), _v(-0.12, 0.96, -0.5), fur))
	p.append(LowPoly.prism(_v(0.1, 0.16, 0.05), _v(0.12, 0.96, -0.5), fur))
	for sx in [-1.0, 1.0]:
		p.append(LowPoly.box(_v(0.1, 0.45, 0.12), _v(0.15 * sx, 0.24, -0.3), fur.darkened(0.1)))
		p.append(LowPoly.box(_v(0.1, 0.45, 0.12), _v(0.15 * sx, 0.24, 0.4), fur.darkened(0.1)))
	p.append(LowPoly.cone(0.06, 0.5, _v(0, 0.75, 0.62), fur, 4))
	p.append(LowPoly.box(_v(0.36, 0.08, 0.08), _v(0, 0.5, -0.4), Color("8A2A2A")))   # нашийник
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.05, 0.04, 0.02), _v(-0.08, 0.76, -0.72), Color("FF5A3A")), Color("FF5A3A"), 3.0))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.05, 0.04, 0.02), _v(0.08, 0.76, -0.72), Color("FF5A3A")), Color("FF5A3A"), 3.0))
	return root


static func _archer() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var cloak := Color("5A5348")
	var p: Array = []
	p.append(LowPoly.box(_v(0.16, 0.75, 0.2), _v(-0.13, 0.38, 0), Color("3A3530")))
	p.append(LowPoly.box(_v(0.16, 0.75, 0.2), _v(0.13, 0.38, 0), Color("3A3530")))
	p.append(LowPoly.cyl(0.26, 0.32, 0.9, _v(0, 1.15, 0), cloak, 7))
	p.append(LowPoly.ball(0.22, _v(0, 1.8, 0), Color("D9D2C0"), 7))
	p.append(LowPoly.cone(0.26, 0.4, _v(0, 2.0, 0.03), Color("3E3A34"), 7))
	p.append(LowPoly.box(_v(0.5, 0.06, 0.06), _v(0, 1.4, -0.1), Palette.BLOOD.darkened(0.2)))
	# лук
	var bow: Array = []
	for i in range(7):
		var a := lerpf(-PI * 0.4, PI * 0.4, float(i) / 6.0)
		bow.append(LowPoly.box(_v(0.06, 0.28, 0.06), _v(-0.42, 1.25 + sin(a) * 0.55, -0.35 - (cos(a) - 1.0) * 0.4), Color("6B4A2E"), _v(rad_to_deg(a) * 0.6, 0, 0)))
	p.append_array(bow)
	p.append(LowPoly.box(_v(0.015, 1.15, 0.015), _v(-0.42, 1.25, -0.3), Palette.LINEN))
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.cyl(0.12, 0.12, 0.03, _v(0, 1.8, -0.2), Color("F4F4F0"), 12, _v(90, 0, 0)), Color("F4F4F0"), 0.8))
	return root


static func _brute() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var skin := Color("6E4A44")
	var p: Array = []
	p.append(LowPoly.box(_v(0.28, 0.95, 0.3), _v(-0.22, 0.48, 0), Color("2E2A27")))
	p.append(LowPoly.box(_v(0.28, 0.95, 0.3), _v(0.22, 0.48, 0), Color("2E2A27")))
	p.append(LowPoly.cyl(0.5, 0.42, 1.0, _v(0, 1.45, 0), Color("3A3633"), 7))
	p.append(LowPoly.cyl(0.52, 0.52, 0.12, _v(0, 1.0, 0), Palette.BLOOD.darkened(0.3), 7))
	p.append(LowPoly.ball(0.3, _v(0, 2.2, 0), skin, 7))
	p.append(LowPoly.cone(0.34, 0.5, _v(0, 2.55, 0.02), Color("1E1B19"), 6))   # каптур ката
	p.append(LowPoly.box(_v(0.2, 0.9, 0.2), _v(-0.65, 1.5, -0.1), skin, _v(-10, 0, 12)))
	p.append(LowPoly.box(_v(0.2, 0.9, 0.2), _v(0.65, 1.5, -0.1), skin, _v(-10, 0, -12)))
	# сокира
	p.append(LowPoly.box(_v(0.1, 1.9, 0.1), _v(0.75, 1.5, -0.55), Color("5A3F2A"), _v(-25, 0, 0)))
	p.append(LowPoly.box(_v(0.9, 0.5, 0.1), _v(0.75, 2.2, -0.95), STEEL_LIGHT, _v(-25, 0, 0)))
	root.add_child(LowPoly.instance(p))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.12, 0.05, 0.02), _v(-0.1, 2.22, -0.28), Color("FF7A3A")), Color("FF7A3A"), 3.0))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.12, 0.05, 0.02), _v(0.1, 2.22, -0.28), Color("FF7A3A")), Color("FF7A3A"), 3.0))
	return root


static func _wraith() -> Node3D:
	var root := Node3D.new()
	root.name = "Model"
	var col := Color(0.62, 0.78, 0.72, 0.55)
	var dark := Color(0.30, 0.42, 0.40, 0.7)
	var p: Array = []
	p.append(LowPoly.cyl(0.14, 0.44, 1.5, _v(0, 1.05, 0), col, 7))
	for i in range(6):
		var a := TAU * float(i) / 6.0
		p.append(LowPoly.cone(0.13, 0.55, _v(sin(a) * 0.34, 0.25, cos(a) * 0.34), col, 4))
	p.append(LowPoly.ball(0.25, _v(0, 1.88, 0), dark, 7, _v(1, 1.2, 1)))
	p.append(LowPoly.cone(0.18, 0.38, _v(0, 2.2, 0.05), dark, 6))
	p.append(LowPoly.box(_v(0.07, 0.8, 0.07), _v(-0.3, 1.3, -0.35), col, _v(-55, 0, 10)))
	p.append(LowPoly.box(_v(0.07, 0.8, 0.07), _v(0.3, 1.3, -0.35), col, _v(-55, 0, -10)))
	var mi := LowPoly.instance(p, LowPoly.vc_material(true))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	var eye_c := Color("A8F0FF")
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.07, 0.11, 0.02), _v(-0.09, 1.9, -0.24), eye_c), eye_c, 3.5))
	root.add_child(LowPoly.glow_instance(LowPoly.box(_v(0.07, 0.11, 0.02), _v(0.09, 1.9, -0.24), eye_c), eye_c, 3.5))
	var orb := LowPoly.glow_instance(LowPoly.ball(0.16, _v(0, 1.35, -0.6), eye_c, 6), eye_c, 3.0, 0.85)
	orb.name = "Orb"
	root.add_child(orb)
	return root


# =====================================================================
#  Снаряди
# =====================================================================

static func arrow() -> Node3D:
	var root := Node3D.new()
	var p: Array = []
	p.append(LowPoly.box(_v(0.03, 0.03, 0.8), _v(0, 0, 0), WOOD))
	p.append(LowPoly.prism(_v(0.12, 0.2, 0.05), _v(0, 0, -0.45), STEEL_LIGHT, _v(-90, 0, 0)))
	p.append(LowPoly.box(_v(0.12, 0.02, 0.18), _v(0, 0, 0.36), Palette.LINEN))
	root.add_child(LowPoly.instance(p))
	return root


static func bolt(color: Color, size: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.add_child(LowPoly.glow_instance(LowPoly.ball(0.17 * size, Vector3.ZERO, color, 6), color, 3.0))
	root.add_child(LowPoly.glow_instance(LowPoly.ball(0.3 * size, Vector3.ZERO, color, 6), color, 1.2, 0.35))
	return root


# =====================================================================
#  Позначки
# =====================================================================

## Робить усі меші моделі білими на мить: «влучання».
static func set_flash(node: Node, on: bool) -> void:
	var overlay: Material = null
	if on:
		overlay = LowPoly.glow_material(Color(1, 1, 1), 1.5, 0.55)
	_apply_overlay(node, overlay)


static func _apply_overlay(node: Node, overlay: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = overlay
	for c in node.get_children():
		_apply_overlay(c, overlay)


## Напівпрозора бірюзова «примара» з кістяка.
static func _ghostify(n: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.95, 1.0, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.8, 0.9)
	mat.emission_energy_multiplier = 0.6
	for m in n.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
