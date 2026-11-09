## Вкладка «Древо»: повний TreeEditorScreen на спільному doc сесії.
class_name EditorTabTree
extends Control

var session: EditorSession
var _screen: TreeEditorScreen


func setup(s: EditorSession) -> void:
	session = s
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true

	_screen = TreeEditorScreen.new()
	_screen.bind_session(session)
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_screen)

	visibility_changed.connect(func():
		if visible and _screen and _screen._view:
			_screen.call_deferred("_fit_when_sized"))
