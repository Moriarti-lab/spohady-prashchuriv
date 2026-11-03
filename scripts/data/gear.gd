## Три стартові класи: стартова зброя й броня (див. Items.STARTER) та місце старту на Древі.
class_name Gear

const CLASS_IDS := ["druzhynnyk", "strilets", "volkhv"]

const CLASSES := {
	"druzhynnyk": {
		"name": "Дружинник", "weapon": "sword", "offhand": "Щит", "armor": "plate",
		"start_near": "Сили", "region": "str",
		"desc": "Воїн ближнього бою. Бʼє мечем, ховається за щитом.",
	},
	"strilets": {
		"name": "Стрілець", "weapon": "bow", "offhand": "Сагайдак", "armor": "mail",
		"start_near": "Спритності", "region": "agi",
		"desc": "Влучний мисливець. Стріляє по найближчому ворогові.",
	},
	"volkhv": {
		"name": "Волхв", "weapon": "staff", "offhand": "", "armor": "cloth",
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
	var w: Dictionary = Items.BASES[c["weapon"]]
	var a: Dictionary = Items.BASES[c["armor"]]
	var s: String = w["name"]
	if c["offhand"] != "":
		s += " + " + str(c["offhand"]).to_lower()
	return s + "\n" + a["name"]
