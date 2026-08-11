class_name EnemyBase extends CharacterBody2D

@export var speed: float = 150.0
@export var death_effect: PackedScene 

var direction: int = 1
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var wall_bounce_cooldown: float = 0.0 # ตัวแปรป้องกันสลับทิศรัวๆ

@onready var sprite: Sprite2D = $Sprite2D
@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)

func _physics_process(delta: float) -> void:
	# ลดเวลา Cooldown การชนกำแพง
	if wall_bounce_cooldown > 0:
		wall_bounce_cooldown -= delta

	if not is_on_floor():
		velocity.y += gravity * delta

	velocity.x = direction * speed

	# ชนกำแพงสลับทิศ + เช็ก Cooldown
	if is_on_wall() and wall_bounce_cooldown <= 0:
		direction *= -1
		wall_bounce_cooldown = 0.15 # ล็อกไว้ 0.15 วินาที
		
		if sprite:
			sprite.flip_h = (direction == -1)

	move_and_slide()

func die() -> void:
	if death_effect:
		var fx = death_effect.instantiate()
		fx.global_position = global_position
		get_tree().current_scene.add_child(fx)
		
	queue_free()

func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		die()