## Три стартові класи: стартова зброя й броня (див. Items.STARTER) та місце старту на Древі.
class_name Gear

const CLASS_IDS := ["druzhynnyk", "strilets", "volkhv"]

## Три стартові навички класу (одну з них гравець обирає безкоштовно при першому вході в Древо).
## Гілки: a — по площі (слабша шкода), b — потужний одиночний удар (довге відновлення), c — швидка атака (більше Чару).
const STARTER_SKILLS := {
	"druzhynnyk": ["power_strike", "shield_bash", "triple_slash"],
	"strilets": ["arrow_volley", "piercing_shot", "rapid_shot"],
	"volkhv": ["element_wave", "sun_beam", "ice_shards"],
}

const CLASSES := {
	"druzhynnyk": {
		"name": "Дружинник", "kit": ["sword", "shield_round", "mail"],
		"start_near": "Сили", "region": "str",
		"desc": "Воїн ближнього бою. Бʼє мечем, ховається за щитом.",
	},
	"strilets": {
		"name": "Стрілець", "kit": ["bow", "leather"],
		"start_near": "Спритності", "region": "agi",
		"desc": "Влучний мисливець. Стріляє по найближчому ворогові.",
	},
	"volkhv": {
		"name": "Волхв", "kit": ["staff", "cloth"],
		"start_near": "Віри", "region": "faith",
		"desc": "Заклинач. Магічний снаряд має стихію твого бога.",
	},
}

static func class_def(id: String) -> Dictionary:
	return CLASSES.get(id, {})


static func start_node(class_id: String) -> String:
	return PerkTree.class_start(class_id)


static func kit_text(class_id: String) -> String:
	var c: Dictionary = class_def(class_id)
	var names: Array = []
	for id in c.get("kit", []):
		names.append(str(Items.BASES[id]["name"]))
	return "\n".join(names)
