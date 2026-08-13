extends Area2D

@export var speed: float = 400.0
@export var lifetime: float = 3.0
@export var sprite: Sprite2D

var direction: int = 1

func _ready() -> void:
	add_to_group("enemy_projectile")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position.x += direction * speed * delta
	sprite.flip_h = 1 != direction
	

func _on_area_entered(area: Area2D) -> void:
	# 💡 เช็กเฉพาะ Hurtbox ของ Player เท่านั้น (เมิน player_attack โกงไม่ลงแล้วนะ!)
	if area.is_in_group("player_body"):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	# ชนกำแพง (Layer 1) แล้วค่อยหายไป
	if body.get_collision_layer_value(1):
		queue_free()