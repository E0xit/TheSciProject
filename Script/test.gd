extends Node2D

@onready var joystick = 

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	var input_direction : Vector2 = Input.get_vector('left','right','down','up'); 
	print(input_direction)
