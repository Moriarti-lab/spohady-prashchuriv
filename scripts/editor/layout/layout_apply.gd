## Застосовує LayoutStore до живих Control за id (метадані / ім’я вузла).
class_name LayoutApply
extends RefCounted

## Мапінг id елемента → шлях або ім’я Control у сцені HUD.
## Універсально: будь-який екран реєструє editable controls через register().
static var _registry: Dictionary = {}  # screen_id -> {element_id -> NodePath or Callable}


static func register(screen_id: String, element_id: String, finder: Callable) -> void:
	if not _registry.has(screen_id):
		_registry[screen_id] = {}
	_registry[screen_id][element_id] = finder


static func clear_screen(screen_id: String) -> void:
	_registry.erase(screen_id)


static func apply_to_hud(hud: Control, store: LayoutStore) -> void:
	if hud == null or store == null:
		return
	var phone := Vector2(store.canvas_w, store.canvas_h)
	# Prefer explicit registry; fall back to named children
	var map := {
		"portrait_panel": hud.get_node_or_null("PortraitPanel"),
		"minimap": hud.get_node_or_null("Minimap"),
		"stick": hud.get_node_or_null("Stick"),
		"attack": hud.get_node_or_null("AttackBtn"),
		"potion_hp": hud.get_node_or_null("PotionHp"),
		"potion_mana": hud.get_node_or_null("PotionMana"),
		"menu": hud.get_node_or_null("MenuBtn"),
	}
	# Also try lowercase / alternate names used in hud.gd
	if map["portrait_panel"] == null:
		map["portrait_panel"] = _find_fuzzy(hud, ["Portrait", "PortraitPanel", "HeroPanel"])
	if map["minimap"] == null:
		map["minimap"] = _find_fuzzy(hud, ["Minimap", "MiniMap", "Map"])
	if map["stick"] == null:
		map["stick"] = _find_fuzzy(hud, ["Stick", "Joystick", "MoveStick"])
	if map["attack"] == null:
		map["attack"] = _find_fuzzy(hud, ["AttackBtn", "Attack", "AttackButton"])
	if map["potion_hp"] == null:
		map["potion_hp"] = _find_fuzzy(hud, ["PotionHp", "HpPotion", "PotionHP"])
	if map["potion_mana"] == null:
		map["potion_mana"] = _find_fuzzy(hud, ["PotionMana", "ManaPotion", "PotionMP"])
	if map["menu"] == null:
		map["menu"] = _find_fuzzy(hud, ["MenuBtn", "Menu", "PauseBtn"])

	for el in store.get_elements("hud"):
		var id := str(el.get("id", ""))
		var node: Control = map.get(id, null) as Control
		if node == null:
			continue
		_place(node, el, phone)
		node.visible = bool(el.get("visible", true))
		node.z_index = int(el.get("z", 0))


static func apply_screen(root: Control, screen_id: String, store: LayoutStore) -> void:
	if root == null or store == null:
		return
	var phone := Vector2(store.canvas_w, store.canvas_h)
	var finders: Dictionary = _registry.get(screen_id, {})
	for el in store.get_elements(screen_id):
		var id := str(el.get("id", ""))
		var node: Control = null
		if finders.has(id):
			var f = finders[id]
			if typeof(f) == TYPE_CALLABLE:
				node = f.call() as Control
			elif typeof(f) == TYPE_NODE_PATH:
				node = root.get_node_or_null(f) as Control
		if node == null:
			node = root.find_child(id, true, false) as Control
		if node == null:
			continue
		_place(node, el, phone)
		node.visible = bool(el.get("visible", true))
		node.z_index = int(el.get("z", 0))


static func _place(node: Control, el: Dictionary, phone: Vector2) -> void:
	var r := LayoutStore.new().element_rect(el, phone.x, phone.y)
	# Recompute with actual store rect helper via temporary
	# (element_rect is instance method; we already have logic — use same)
	var store_tmp := LayoutStore.new()
	r = store_tmp.element_rect(el, phone.x, phone.y)
	node.set_anchors_preset(Control.PRESET_TOP_LEFT)
	node.position = r.position
	node.size = r.size


static func _find_fuzzy(root: Node, names: Array) -> Control:
	for n in names:
		var c := root.find_child(str(n), true, false)
		if c is Control:
			return c
	return null
