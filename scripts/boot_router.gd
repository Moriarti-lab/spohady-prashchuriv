## Точка входу: гра або редактор (окремий APK з custom_features=editor_app).
extends Node

func _ready() -> void:
	if _want_editor():
		get_tree().change_scene_to_file.call_deferred("res://scenes/editor_app/editor_main.tscn")
	else:
		get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


func _want_editor() -> bool:
	if OS.has_feature("editor_app"):
		return true
	if OS.get_environment("SPOHADY_EDITOR") == "1":
		return true
	for a in OS.get_cmdline_user_args():
		if a == "--editor_app" or a == "--editor":
			return true
	return false
