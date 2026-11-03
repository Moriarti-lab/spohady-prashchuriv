## Активні навички (кнопки С1 і С2). Значення стартові, легко міняти.
class_name Skills

const DATA := {
	"stribog_dash": {
		"name": "Подих Стрибога", "mana": 10.0, "cd": 30.0, "stat": "agi",
		"desc": "Ривок на 6 м, вітер відкидає ворогів поруч.", "short": "Ривок", "color": Color("9FE3E0"),
	},
	"power_strike": {
		"name": "Могутній удар", "mana": 15.0, "cd": 6.0, "stat": "str",
		"desc": "Удар по землі: шкода всім навколо, ворогів відкидає.", "short": "Удар", "color": Color("D8574B"),
		"base": 30.0, "radius": 4.2,
	},
	"arrow_volley": {
		"name": "Град стріл", "mana": 12.0, "cd": 5.0, "stat": "agi",
		"desc": "Віяло з п'яти стріл по напрямку атаки.", "short": "Стріли", "color": Color("7CBF5A"),
		"base": 11.0, "count": 5,
	},
	"element_wave": {
		"name": "Хвиля стихії", "mana": 20.0, "cd": 7.0, "stat": "faith",
		"desc": "Хвиля стихії твого бога розходиться колом.", "short": "Хвиля", "color": Color("3FB9B3"),
		"base": 26.0, "radius": 6.0,
	},
}

static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})
