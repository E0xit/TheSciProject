class_name EnemyBase extends CharacterBody2D

@export var speed: float = 150.0
@export var death_effect: PackedScene 
@export var spawn_grace_period: float = 0.2 # 💡 ปรับระยะเวลาปลอดภัยตอนเพิ่งเกิดใน Inspector ได้

var direction: int = 1
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var wall_bounce_cooldown: float = 0.0

@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_entered)
		
	# 💡 สั่งปิด Hitbox ทำดาเมจชั่วคราวตอนเพิ่งเกิด 0.2 วินาที
	_apply_spawn_protection()

func _physics_process(delta: float) -> void:
	if wall_bounce_cooldown > 0:
		wall_bounce_cooldown -= delta

	if not is_on_floor():
		velocity.y += gravity * delta

	velocity.x = direction * speed

	# ชนกำแพงสลับทิศ
	if is_on_wall() and wall_bounce_cooldown <= 0:
		direction *= -1
		wall_bounce_cooldown = 0.15

	move_and_slide()

# 🛡️ ระบบปิด Hitbox ป้องกันการชนผู้เล่นทันทีที่เกิด
func _apply_spawn_protection() -> void:
	# ค้นหา Node "Hitbox" (Area2D ที่ทำหน้าที่ชนผู้เล่น)
	var attack_box: Area2D = find_child("Hitbox", true, false) as Area2D
	
	if attack_box:
		# ปิดการตรวจจับการชนของ Hitbox
		attack_box.set_deferred("monitoring", false)
		attack_box.set_deferred("monitorable", false)
		
		# (Optional) ปรับตัวจางลงครึ่งนึง เพื่อเป็น Visual Feedback บอกผู้เล่นว่ากำลังวาร์ปมา
		modulate.a = 0.5 
		
		await get_tree().create_timer(spawn_grace_period).timeout
		
		# เช็กว่าศัตรูยังไม่โดนทำลายไปก่อนหมดเวลา
		if is_instance_valid(self):
			# เปิดการทำงานของ Hitbox กลับมาเป็นปกติ
			attack_box.set_deferred("monitoring", true)
			attack_box.set_deferred("monitorable", true)
			modulate.a = 1.0 # คืนค่าความเข้มสีปกติ

func die() -> void:
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager and manager.has_method("add_score"):
		manager.add_score(1)

	if death_effect:
		var fx = death_effect.instantiate()
		fx.global_position = global_position
		get_tree().current_scene.add_child(fx)
		
	queue_free()

func _on_hurtbox_entered(area: Area2D) -> void:
	if area.is_in_group("player_attack"):
		die()