extends EnemyBase

@export_group("Jumper Config")
@export var jump_cooldown: float = 1.5
@export var jump_force_x: float = 350.0
@export var jump_force_y: float = -650.0
@export var drop_force_y: float = 200.0

@export_group("Floor Limits")
@export var restrict_top_floor_jump: bool = true
@export var top_floor_y_threshold: float = -200.0
@export var restrict_bottom_floor_drop: bool = true
@export var bottom_floor_y_threshold: float = 225.0

var can_jump: bool = true

func _ready() -> void:
	super()
	speed = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# ยืนนิ่งสนิทบนพื้น ตัดความเร็ว X เป็น 0 ทันที ไม่เดินแน่นอน!
		velocity.x = 0.0
		if can_jump:
			_perform_jump()

	# ชนกำแพงกลางอากาศ -> สะท้อนแรงพุ่งกลับฝั่งตรงข้าม
	if is_on_wall() and wall_bounce_cooldown <= 0:
		direction *= -1
		velocity.x = direction * jump_force_x
		wall_bounce_cooldown = 0.15
		if sprite:
			sprite.flip_h = (direction == -1)

	move_and_slide()

func _perform_jump() -> void:
	can_jump = false
	
	var is_on_top = restrict_top_floor_jump and (global_position.y < top_floor_y_threshold)
	var is_on_bottom = restrict_bottom_floor_drop and (global_position.y > bottom_floor_y_threshold)

	# สุ่มทิศทางซ้าย/ขวา
	direction = 1 if randf() > 0.5 else -1
	if sprite:
		sprite.flip_h = (direction == -1)

	# สุ่มตัดสินใจว่าจะ "กระโดดขึ้น" หรือ "มุดลง"
	var wants_to_jump_up = randf() > 0.5

	if is_on_top:
		wants_to_jump_up = false
	elif is_on_bottom:
		wants_to_jump_up = true

	# ออกแรงกระโดด
	if wants_to_jump_up:
		velocity.y = jump_force_y
		velocity.x = direction * jump_force_x
	else:
		_drop_down()

	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

func _drop_down() -> void:
	velocity.y = drop_force_y
	velocity.x = direction * jump_force_x
	
	set_collision_mask_value(3, false)
	await get_tree().create_timer(0.25).timeout
	set_collision_mask_value(3, true)