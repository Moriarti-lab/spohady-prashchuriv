## Локації: селище Липівка (безпечне) і три бойові місця зі зростанням рівня ворогів.
## Усі локації — кругові долини в кільці скель; виходи — браму в скелях (angle_deg) з'єднано шляхом.
class_name Locations

const START := "village"
const MAP_RADIUS_MAX := 60.0

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
		"name": "Темний ліс", "title": "Темний ліс", "safe": false, "radius": 56.0,
		"levels": [1, 4], "enemies": {"novice": 9, "werewolf": 4, "hound": 4},
		"base": Color("456B3D"), "earth": Color("6F6650"), "path": Color("77694F"), "edge": Color("22301F"),
		"fog": Color("24332A"), "bg": Color("18231D"),
		"trees": 105, "rocks": 21, "grass": 200, "tree_mix": [0.40, 0.32, 0.18, 0.10],
		"exits": [
			{"id": "to_village", "angle_deg": 45.0, "to": "village", "label": "До Липівки"},
			{"id": "to_swamp", "angle_deg": 290.0, "to": "swamp", "label": "До Гнилої твані"},
		],
		"houses": [{"pos": [-25.3, 16.0], "yaw": 20.0, "kind": "abandoned", "id": "forest_house", "name": "Покинута хата лісника"}],
		"chests": [{"id": "forest_house_chest", "pos": [-25.3, 19.5], "house": "forest_house", "quest_item": "rushnyk", "loot_level": 2}],
		"herbs": 9,
		"boss": {"id": "alpha", "kind": "werewolf", "name": "Вовкулака-ватажок", "pos": [-32.0, -21.3], "level": 5, "scale": 1.75},
		"roads": [
			[[34.7, 34.7], [13.3, 13.3], [0.0, 0.0], [-10.7, 5.3], [-25.3, 14.7]],
			[[0.0, 0.0], [10.7, -18.7], [21.3, -45.3]],
		],
	},
	"swamp": {
		"name": "Гнила твань", "title": "Гнила твань", "safe": false, "radius": 56.0,
		"levels": [4, 8], "enemies": {"wraith": 8, "novice": 4, "archer": 4, "hound": 3},
		"base": Color("52603F"), "earth": Color("6B6048"), "path": Color("6F6247"), "edge": Color("1F2A24"),
		"fog": Color("2A3A33"), "bg": Color("17211D"),
		"trees": 66, "rocks": 18, "grass": 120, "tree_mix": [0.05, 0.05, 0.10, 0.80], "puddles": 16,
		"exits": [
			{"id": "to_forest", "angle_deg": 110.0, "to": "forest", "label": "До Темного лісу"},
			{"id": "to_ruins", "angle_deg": 315.0, "to": "ruins", "label": "До Руїн застави"},
		],
		"houses": [{"pos": [18.7, -22.7], "yaw": 200.0, "kind": "abandoned", "id": "swamp_house", "name": "Покинута хатина мисливця"}],
		"chests": [{"id": "swamp_house_chest", "pos": [18.7, -19.5], "house": "swamp_house", "quest_item": "letter", "loot_level": 5}],
		"boss": {"id": "wraith_giant", "kind": "wraith", "name": "Болотний велетень", "pos": [-24.0, 26.7], "level": 9, "scale": 1.9, "hp_mult": 1.5},
		"roads": [
			[[-18.7, 50.7], [-8.0, 18.7], [0.0, 0.0], [10.7, -10.7], [18.7, -20.0]],
			[[10.7, -10.7], [26.7, -29.3], [40.0, -40.0]],
		],
	},
	"ruins": {
		"name": "Руїни застави", "title": "Руїни застави", "safe": false, "radius": 56.0,
		"levels": [8, 12], "enemies": {"brute": 6, "archer": 6, "werewolf": 4, "wraith": 4},
		"base": Color("6A6E58"), "earth": Color("7D7869"), "path": Color("837D6B"), "edge": Color("2A2E27"),
		"fog": Color("343B35"), "bg": Color("1D231F"),
		"trees": 36, "rocks": 45, "grass": 90, "tree_mix": [0.05, 0.05, 0.05, 0.85], "ruin_walls": 18,
		"exits": [
			{"id": "to_swamp", "angle_deg": 135.0, "to": "swamp", "label": "До Гнилої твані"},
			{"id": "to_steppe", "angle_deg": 330.0, "to": "steppe", "label": "До Дикого поля"},
		],
		"houses": [],
		"boss": {"id": "inquisitor", "kind": "novice", "name": "Великий інквізитор", "pos": [-16.0, -29.3], "level": 13, "scale": 1.7, "hp_mult": 1.3},
		"roads": [[[-34.7, 34.7], [-16.0, 16.0], [0.0, 0.0], [-8.0, -16.0], [-16.0, -26.7]], [[0.0, 0.0], [20.0, -11.0], [46.0, -26.5]]],
	},
	"steppe": {
		"name": "Дике поле", "title": "Дике поле", "safe": false, "radius": 58.0,
		"levels": [12, 16], "enemies": {"brute": 5, "archer": 5, "hound": 6, "werewolf": 4},
		"base": Color("8A8A4E"), "earth": Color("9A8A62"), "path": Color("A08E64"), "edge": Color("3A3A26"),
		"fog": Color("4A4A3A"), "bg": Color("2A2A20"), "amb": "steppe",
		"trees": 18, "rocks": 26, "grass": 320, "tree_mix": [0.10, 0.50, 0.40, 0.0],
		"exits": [
			{"id": "to_ruins", "angle_deg": 150.0, "to": "ruins", "label": "До Руїн застави"},
			{"id": "to_kurgan", "angle_deg": 300.0, "to": "kurgan", "label": "До Чорних курганів"},
		],
		"houses": [{"pos": [22.0, 18.0], "yaw": 40.0, "kind": "abandoned", "id": "steppe_house", "name": "Спалений хутір"}],
		"chests": [{"id": "steppe_house_chest", "pos": [22.0, 20.6], "house": "steppe_house", "loot_level": 14}],
		"herbs": 8,
		"boss": {"id": "solovei", "kind": "brute", "name": "Соловей-Розбійник", "pos": [-20.0, -26.0], "level": 17, "scale": 1.8, "hp_mult": 1.6},
		"roads": [
			[[-44.0, 26.0], [-20.0, 10.0], [0.0, 0.0], [12.0, -20.0], [26.0, -46.0]],
			[[0.0, 0.0], [12.0, 10.0], [22.0, 17.0]],
		],
	},
	"kurgan": {
		"name": "Чорні кургани", "title": "Чорні кургани", "safe": false, "radius": 56.0,
		"levels": [16, 20], "enemies": {"skel_minion": 8, "skel_warrior": 5, "skel_rogue": 4, "skel_mage": 3, "wraith": 3},
		"base": Color("4E5546"), "earth": Color("5E5A4C"), "path": Color("6A6450"), "edge": Color("1E221C"),
		"fog": Color("2C3230"), "bg": Color("15191A"), "amb": "ruins",
		"trees": 20, "rocks": 40, "grass": 80, "tree_mix": [0.0, 0.10, 0.10, 0.80], "ruin_walls": 14,
		"exits": [{"id": "to_steppe", "angle_deg": 120.0, "to": "steppe", "label": "До Дикого поля"}],
		"houses": [],
		"boss": {"id": "chornoknyzhnyk", "kind": "skel_mage", "name": "Чорнокнижник", "pos": [16.0, -24.0], "level": 21, "scale": 1.9, "hp_mult": 1.7},
		"roads": [[[-28.0, 48.0], [-12.0, 20.0], [0.0, 0.0], [10.0, -14.0], [16.0, -22.0]]],
	},
	"cave": {
		"name": "Печера", "title": "Печера Кощія", "safe": false, "radius": 30.0, "cave": true,
		"levels": [1, 1], "enemies": {"skel_minion": 6, "skel_warrior": 3, "skel_rogue": 2, "skel_mage": 2},
		"base": Color("3A3632"), "earth": Color("4A4238"), "path": Color("554C40"), "edge": Color("0E0D0C"),
		"fog": Color("141A1E"), "bg": Color("07090B"), "amb": "cave",
		"trees": 0, "rocks": 46, "grass": 0, "tree_mix": [0.0, 0.0, 0.0, 1.0], "ruin_walls": 8,
		"exits": [{"id": "to_surface", "angle_deg": 90.0, "to": "@back", "label": "Назовні"}],
		"houses": [],
		"boss": {"id": "koshchii", "kind": "skel_warrior", "name": "Кощій Безсмертний", "pos": [0.0, -18.0], "level": 1, "scale": 2.3, "hp_mult": 3.0, "cave": true},
		"roads": [[[0.0, 26.0], [0.0, 0.0], [0.0, -16.0]]],
	},
}

const IDS := ["village", "forest", "swamp", "ruins", "steppe", "kurgan"]
## Локації, де можуть з'являтися входи до печер.
const CAVE_HOSTS := ["forest", "swamp", "ruins", "steppe", "kurgan"]


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
