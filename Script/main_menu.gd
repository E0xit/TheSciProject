extends Node2D
@export var setting_menu: Panel
@onready var next_scene: String = 'res://Scene/story.tscn'

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func _on_setting_pressed() -> void:
	setting_menu.visible = true

func _on_start_pressed() -> void:
	get_tree().call_deferred("change_scene_to_file", next_scene)


func _on_setting_back_pressed() -> void:
	setting_menu.visible = false
