extends EnemyBase

@export_group("Jumper Config")
@export var jump_cooldown: float = 2.0
@export var charge_time: float = 0.5
@export var jump_force_x: float = 1000.0
@export var jump_force_y: float = -650.0
@export var drop_force_y: float = 200.0

@export_group("Floor Limits")
@export var restrict_top_floor_jump: bool = true
@export var top_floor_y_threshold: float = -200.0
@export var restrict_bottom_floor_drop: bool = true
@export var bottom_floor_y_threshold: float = 225.0

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var can_jump: bool = true
var _is_charging: bool = false
var _is_dropping: bool = false

func _ready() -> void:
	super()
	speed = 0.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# 💡 แก้ไข: ถ้าลอยลงมาแตะพื้นแล้ว และไม่ได้อยู่ในช่วงชาร์จ/กระโดด ค่อยตัดความเร็ว X เป็น 0
		if not _is_charging and can_jump:
			velocity.x = 0.0
			_start_jump_sequence()

	if is_on_wall() and wall_bounce_cooldown <= 0:
		direction *= -1
		velocity.x = direction * jump_force_x
		wall_bounce_cooldown = 0.15
		if anim_sprite:
			anim_sprite.flip_h = (direction == -1)

	# Animation Priority
	if _is_charging:
		_play_animation("charge")
	elif _is_dropping:
		_play_animation("jumping")
	elif not is_on_floor():
		_play_animation("jumping" if velocity.y < 0 else "jumping")
	else:
		_play_animation("idle")

	move_and_slide()

func _start_jump_sequence() -> void:
	can_jump = false
	_is_charging = true
	_play_animation("charge")
	
	await get_tree().create_timer(charge_time).timeout
	
	_is_charging = false
	_perform_jump()

func _perform_jump() -> void:
	var is_on_top = restrict_top_floor_jump and (global_position.y < top_floor_y_threshold)
	var is_on_bottom = restrict_bottom_floor_drop and (global_position.y > bottom_floor_y_threshold)

	direction = 1 if randf() > 0.5 else -1
	if anim_sprite:
		anim_sprite.flip_h = (direction == -1)

	var wants_to_jump_up = randf() > 0.5

	if is_on_top:
		wants_to_jump_up = false
	elif is_on_bottom:
		wants_to_jump_up = true

	if wants_to_jump_up:
		velocity.y = jump_force_y
		velocity.x = direction * jump_force_x
	else:
		_drop_down()

	await get_tree().create_timer(jump_cooldown).timeout
	can_jump = true

func _drop_down() -> void:
	_is_dropping = true
	velocity.y = drop_force_y
	velocity.x = direction * jump_force_x
	
	set_collision_mask_value(3, false)
	await get_tree().create_timer(0.25).timeout
	set_collision_mask_value(3, true)
	_is_dropping = false

func _play_animation(anim_name: String) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)