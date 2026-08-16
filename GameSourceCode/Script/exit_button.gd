extends Button
@onready var scene_path: String = 'res://Scene/main_menu.tscn'

func _on_pressed() -> void:
	pass # Replace with function body.
	get_tree().call_deferred("change_scene_to_file", scene_path)