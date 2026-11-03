## Активні навички (чотири швидкі слоти). Значення стартові, легко міняти.
class_name Skills

const DATA := {
	"stribog_dash": {
		"name": "Подих Стрибога", "mana": 10.0, "cd": 30.0, "stat": "agi",
		"desc": "Ривок на 6 м, вітер відкидає ворогів поруч.", "short": "Ривок", "color": Color("9FE3E0"),
	},
	"power_strike": {
		"name": "Могутній удар", "mana": 15.0, "cd": 6.0, "stat": "str",
		"desc": "Удар по землі: шкода всім навколо, ворогів відкидає.", "short": "Удар", "color": Color("D8574B"),
		"base": 38.0, "radius": 4.2,
	},
	"arrow_volley": {
		"name": "Град стріл", "mana": 12.0, "cd": 5.0, "stat": "agi",
		"desc": "Віяло з п'яти стріл по напрямку атаки.", "short": "Стріли", "color": Color("7CBF5A"),
		"base": 14.0, "count": 5,
	},
	"element_wave": {
		"name": "Хвиля стихії", "mana": 20.0, "cd": 7.0, "stat": "faith",
		"desc": "Хвиля стихії твого бога розходиться колом.", "short": "Хвиля", "color": Color("3FB9B3"),
		"base": 32.0, "radius": 6.0,
	},
	"whirlwind": {
		"name": "Вихор лез", "mana": 16.0, "cd": 8.0, "stat": "str",
		"desc": "Крутишся із зброєю: чотири удари поспіль по всіх навколо.", "short": "Вихор", "color": Color("E08A4B"),
		"base": 15.0, "radius": 3.3, "ticks": 4,
	},
	"piercing_shot": {
		"name": "Влучний постріл", "mana": 12.0, "cd": 7.0, "stat": "agi",
		"desc": "Сильна стріла, що пробиває всіх ворогів на шляху.", "short": "Постріл", "color": Color("B7E07A"),
		"base": 46.0,
	},
	"ancestral_heal": {
		"name": "Поклик пращурів", "mana": 22.0, "cd": 14.0, "stat": "faith",
		"desc": "Пращури лікують тебе: частина життя й трохи від Віри.", "short": "Поклик", "color": Color("F2D58A"),
		"heal_pct": 0.30,
	},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})


## Значок навички (res://art/icons/skills/...). Для «Хвилі стихії» залежить від благословення.
static func icon_path(id: String, blessing: String = "") -> String:
	var name := id
	if id == "element_wave" and blessing != "":
		name = "element_wave_" + blessing
	if id == "element_wave_stribog" or (id == "element_wave" and blessing == "stribog"):
		name = "stribog_dash"
	return "res://art/icons/skills/%s.png" % name
