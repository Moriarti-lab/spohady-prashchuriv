## Клавіші для перевірки на комп'ютері (на телефоні діють сенсорні кнопки).
class_name InputSetup

static func ensure() -> void:
	_add("move_left", [KEY_A, KEY_LEFT])
	_add("move_right", [KEY_D, KEY_RIGHT])
	_add("move_up", [KEY_W, KEY_UP])
	_add("move_down", [KEY_S, KEY_DOWN])
	_add("attack", [KEY_SPACE, KEY_J])
	_add("skill_1", [KEY_K, KEY_1])
	_add("skill_2", [KEY_L, KEY_2])
	_add("perk_screen", [KEY_P, KEY_TAB])


static func _add(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
