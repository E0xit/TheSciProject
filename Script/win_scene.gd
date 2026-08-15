extends Node2D

@onready var main_menu: String = 'res://Scene/main_menu.tscn'
@onready var gamplay: String = 'res://Scene/main.tscn'


func _on_back_main_menu_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", main_menu)

func _on_restart_button_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", gamplay)
