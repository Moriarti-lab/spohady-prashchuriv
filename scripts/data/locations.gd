## Локації: селище Липівка (безпечне) і три бойові місця зі зростанням рівня ворогів.
## Усі локації — кругові долини в кільці скель; виходи — браму в скелях (angle_deg) з'єднано шляхом.
class_name Locations

const START := "village"
const MAP_RADIUS_MAX := 46.0

const DATA := {
	"village": {
		"name": "Липівка", "title": "Селище Липівка", "safe": true, "radius": 34.0,
		"levels": [1, 1], "enemies": {},
		"base": Color("5C7A4B"), "earth": Color("85785F"), "path": Color("8A7B5C"), "edge": Color("2C3A2E"),
		"fog": Color("30403A"), "bg": Color("22302B"),
		"trees": 26, "rocks": 6, "grass": 260, "tree_mix": [0.30, 0.30, 0.40, 0.0],
		"exits": [{"id": "to_forest", "angle_deg": 225.0, "to": "forest", "label": "До Темного лісу"}],
		"houses": [
			{"pos": [-16.0, -4.0], "yaw": 70.0, "kind": "home"},
			{"pos": [15.0, -9.0], "yaw": -60.0, "kind": "home"},
			{"pos": [14.0, 11.0], "yaw": -120.0, "kind": "home"},
			{"pos": [-14.0, 13.0], "yaw": 130.0, "kind": "home"},
			{"pos": [-5.0, -18.0], "yaw": 0.0, "kind": "elder"},
		],
		"npcs": [
			{"id": "merchant", "name": "Радим", "role": "Торговець", "pos": [-7.5, 2.5], "color": "#B8742E"},
			{"id": "herbalist", "name": "Зоряна", "role": "Травниця", "pos": [8.0, 3.0], "color": "#5FA05A"},
			{"id": "elder", "name": "Богдан", "role": "Старійшина", "pos": [-5.0, -14.5], "color": "#CFC6B0"},
		],
		"roads": [
			[[0.0, 0.0], [-7.0, 4.5]],
			[[0.0, 0.0], [8.0, 5.0]],
			[[0.0, 0.0], [-3.0, -9.0], [-5.0, -14.0]],
		],
	},
	"forest": {
		"name": "Темний ліс", "title": "Темний ліс", "safe": false, "radius": 42.0,
		"levels": [1, 4], "enemies": {"novice": 6, "werewolf": 3, "hound": 3},
		"base": Color("456B3D"), "earth": Color("6F6650"), "path": Color("77694F"), "edge": Color("22301F"),
		"fog": Color("24332A"), "bg": Color("18231D"),
		"trees": 70, "rocks": 14, "grass": 200, "tree_mix": [0.40, 0.32, 0.18, 0.10],
		"exits": [
			{"id": "to_village", "angle_deg": 45.0, "to": "village", "label": "До Липівки"},
			{"id": "to_swamp", "angle_deg": 290.0, "to": "swamp", "label": "До Гнилої топі"},
		],
		"houses": [{"pos": [-19.0, 12.0], "yaw": 20.0, "kind": "abandoned", "id": "forest_house", "name": "Покинута хата лісника"}],
		"chests": [{"id": "forest_house_chest", "pos": [-19.0, 14.6], "house": "forest_house", "quest_item": "rushnyk", "loot_level": 2}],
		"herbs": 9,
		"boss": {"id": "alpha", "kind": "werewolf", "name": "Вовкулака-ватажок", "pos": [-24.0, -16.0], "level": 5, "scale": 1.75},
		"roads": [
			[[26.0, 26.0], [10.0, 10.0], [0.0, 0.0], [-8.0, 4.0], [-19.0, 11.0]],
			[[0.0, 0.0], [8.0, -14.0], [16.0, -34.0]],
		],
	},
	"swamp": {
		"name": "Гнила топь", "title": "Гнила топь", "safe": false, "radius": 42.0,
		"levels": [4, 8], "enemies": {"wraith": 5, "novice": 3, "archer": 3, "hound": 2},
		"base": Color("52603F"), "earth": Color("6B6048"), "path": Color("6F6247"), "edge": Color("1F2A24"),
		"fog": Color("2A3A33"), "bg": Color("17211D"),
		"trees": 44, "rocks": 12, "grass": 120, "tree_mix": [0.05, 0.05, 0.10, 0.80], "puddles": 16,
		"exits": [
			{"id": "to_forest", "angle_deg": 110.0, "to": "forest", "label": "До Темного лісу"},
			{"id": "to_ruins", "angle_deg": 315.0, "to": "ruins", "label": "До Руїн застави"},
		],
		"houses": [{"pos": [14.0, -17.0], "yaw": 200.0, "kind": "abandoned", "id": "swamp_house", "name": "Покинута хатина мисливця"}],
		"chests": [{"id": "swamp_house_chest", "pos": [14.0, -14.6], "house": "swamp_house", "quest_item": "letter", "loot_level": 5}],
		"boss": {"id": "wraith_giant", "kind": "wraith", "name": "Болотний велетень", "pos": [-18.0, 20.0], "level": 9, "scale": 1.9, "hp_mult": 1.5},
		"roads": [
			[[-14.0, 38.0], [-6.0, 14.0], [0.0, 0.0], [8.0, -8.0], [14.0, -15.0]],
			[[8.0, -8.0], [20.0, -22.0], [30.0, -30.0]],
		],
	},
	"ruins": {
		"name": "Руїни застави", "title": "Руїни застави", "safe": false, "radius": 42.0,
		"levels": [8, 12], "enemies": {"brute": 4, "archer": 4, "werewolf": 3, "wraith": 3},
		"base": Color("6A6E58"), "earth": Color("7D7869"), "path": Color("837D6B"), "edge": Color("2A2E27"),
		"fog": Color("343B35"), "bg": Color("1D231F"),
		"trees": 24, "rocks": 30, "grass": 90, "tree_mix": [0.05, 0.05, 0.05, 0.85], "ruin_walls": 18,
		"exits": [{"id": "to_swamp", "angle_deg": 135.0, "to": "swamp", "label": "До Гнилої топі"}],
		"houses": [],
		"boss": {"id": "inquisitor", "kind": "novice", "name": "Великий інквізитор", "pos": [-12.0, -22.0], "level": 13, "scale": 1.7, "hp_mult": 1.3},
		"roads": [[[-26.0, 26.0], [-12.0, 12.0], [0.0, 0.0], [-6.0, -12.0], [-12.0, -20.0]]],
	},
}

const IDS := ["village", "forest", "swamp", "ruins"]


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, DATA[START])


static func has(id: String) -> bool:
	return DATA.has(id)


static func is_safe(id: String) -> bool:
	return bool(get_def(id).get("safe", false))


static func exit_dir(loc: String, i: int) -> Vector2:
	var a := deg_to_rad(float(get_def(loc)["exits"][i]["angle_deg"]))
	return Vector2(cos(a), sin(a))


## Номер виходу в локації `loc`, що веде в локацію `to`. -1, якщо немає.
static func exit_to(loc: String, to: String) -> int:
	var ex: Array = get_def(loc)["exits"]
	for i in range(ex.size()):
		if str(ex[i]["to"]) == to:
			return i
	return -1


## Назви рівнів ворогів для карти: «рів. 1–4».
static func level_text(id: String) -> String:
	var d := get_def(id)
	if bool(d.get("safe", false)):
		return "безпечно"
	return "рів. %d–%d" % [int(d["levels"][0]), int(d["levels"][1])]
