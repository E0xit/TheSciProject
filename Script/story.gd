extends Node2D

@export var next_scene: String

func _on_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", next_scene)
