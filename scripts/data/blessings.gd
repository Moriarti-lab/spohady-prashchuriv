## Шість благословень богів-покровителів («пробуджена кров»).
## Значення взято з дизайн-документа v0.5.
class_name Blessings

const IDS := ["perun", "veles", "stribog", "dazhbog", "mokosh", "svarog"]

const DATA := {
	"perun": {
		"name": "Пробуджена кров Перуна", "god": "Перун", "style": "Дружинник-громовержець",
		"legend": "Громова кров: ти відчуваєш грім ще до бурі, а в бою на руках спалахують білі іскри.",
		"main": "str", "main_bonus": 1.0, "sub": "agi", "sub_bonus": 0.5,
		"element": "Грім", "bolt": "Громова іскра", "color": Color("F6E27A"),
		"skill": "perun_mark", "skill_name": "Громова мітка", "skill_kind": "passive",
		"skill_desc": "Кожен 5-й удар додатково б'є блискавкою на 50% шкоди.",
	},
	"veles": {
		"name": "Пробуджена кров Велеса", "god": "Велес", "style": "Стрілець-розвідник",
		"legend": "Кров лісу й звірів: ти чуєш кроки по землі й відчуваєш, де ховається здобич.",
		"main": "agi", "main_bonus": 1.0, "sub": "str", "sub_bonus": 0.5,
		"element": "Природа", "bolt": "Лісовий шип", "color": Color("78C24E"),
		"skill": "veles_nose", "skill_name": "Звіриний нюх", "skill_kind": "passive",
		"skill_desc": "+10% швидкості руху поза боєм. (Бачити крізь перешкоди додамо пізніше.)",
	},
	"stribog": {
		"name": "Пробуджена кров Стрибога", "god": "Стрибог", "style": "Рухливий стрілець або волхв",
		"legend": "Кров вітру: ти легкий на ногу, а кроки ніби підхоплює подих степу.",
		"main": "agi", "main_bonus": 1.0, "sub": "faith", "sub_bonus": 0.5,
		"element": "Вітер", "bolt": "Вітряний серп", "color": Color("9FE3E0"),
		"skill": "stribog_dash", "skill_name": "Подих Стрибога", "skill_kind": "active",
		"skill_desc": "Ривок на 6 м; вітер відкидає ворогів поруч. Перезарядка 30 с.",
	},
	"dazhbog": {
		"name": "Пробуджена кров Дажбога", "god": "Дажбог", "style": "Волхв-цілитель або воїн світла",
		"legend": "Кров сонця: поруч із тобою тепліше, а на чолі інколи проступає знак сонячного кола.",
		"main": "faith", "main_bonus": 1.0, "sub": "str", "sub_bonus": 0.5,
		"element": "Світло", "bolt": "Сонячна стріла", "color": Color("FFD65A"),
		"skill": "dazhbog_sun", "skill_name": "Сонячне благословення", "skill_kind": "passive",
		"skill_desc": "Усе лікування діє на 20% сильніше.",
	},
	"mokosh": {
		"name": "Пробуджена кров Мокоші", "god": "Мокош", "style": "Заклинач зі швидкими навичками",
		"legend": "Кров долі: ти бачиш нитки подій, а візерунки на твоїй сорочці ніби ворушаться.",
		"main": "faith", "main_bonus": 1.0, "sub": "agi", "sub_bonus": 0.5,
		"element": "Доля", "bolt": "Сяйна нитка", "color": Color("D7A8FF"),
		"skill": "mokosh_thread", "skill_name": "Нитка долі", "skill_kind": "passive",
		"skill_desc": "10% шанс, що навичка не піде на перезарядку.",
	},
	"svarog": {
		"name": "Пробуджена кров Сварога", "god": "Сварог", "style": "Важкий дружинник",
		"legend": "Кров небесного коваля: руки гартуються у вогні, а на плечах інколи спалахують іскри.",
		"main": "str", "main_bonus": 1.0, "sub": "faith", "sub_bonus": 0.5,
		"element": "Вогонь", "bolt": "Іскра горна", "color": Color("FF8A3D"),
		"skill": "svarog_steel", "skill_name": "Гартована сталь", "skill_kind": "passive",
		"skill_desc": "Уся броня на тобі +10%, шкода зброї +5%.",
	},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})

## Короткий опис бонусів: «+1 Сила, +0,5 Спритність за рівень»
static func bonus_text(id: String) -> String:
	var d: Dictionary = get_def(id)
	if d.is_empty():
		return ""
	return "+%s %s, +%s %s за рівень" % [
		Strings.num(d["main_bonus"]), Strings.stat_name(d["main"]),
		Strings.num(d["sub_bonus"]), Strings.stat_name(d["sub"])]
