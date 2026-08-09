extends CharacterBody2D

# ==========================================
# ⚙️ ตัวแปรตั้งค่า (Config & Tweaks)
# ==========================================
@export_group("Player Physics")
@export var speed: float = 750.0
@export var jump_velocity: float = -1000.0

@export_group("Debug Options")
@export var enable_logs: bool = true
@export var show_debug_draw: bool = true

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# 🧭 ทิศทางเป้าหมายที่ผู้เล่นเลือก (1 = ขวา, -1 = ซ้าย)
var target_direction: int = 1
# 🛑 สถานะติดกำแพงหรือไม่
var is_stopped_at_wall: bool = false

var flashlight_initial_x_offset: float = 35.0
var _is_dropping_down: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var flashlight_hitbox: Area2D = $FlashlightHitbox
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	log_msg("🚀 [PLAYER READY] New Manual-Direction Auto-Run Control Active!")
	
	if flashlight_hitbox:
		flashlight_initial_x_offset = abs(flashlight_hitbox.position.x)
		if flashlight_initial_x_offset == 0:
			flashlight_initial_x_offset = 35.0
			flashlight_hitbox.position.x = flashlight_initial_x_offset
			
	_verify_nodes()


func _physics_process(delta: float) -> void:
	# 1. อ่าน Input กำหนดทิศทางการเดินจากผู้เล่น (กด Left/Right)
	handle_direction_input()

	# 2. Gravity & Animation Management
	# 1. ระบบดึงลงพื้น (Gravity)
	if not is_on_floor():
		# 💡 HOTFIX: ถ้ากำลังกดมุดชั้นล่าง ให้เพิ่มแรงร่วงเร็วขึ้น ไม่ให้ติดขัด
		if _is_dropping_down:
			velocity.y += gravity * 1.5 * delta
		else:
			velocity.y += gravity * delta

		if velocity.y < 0:
			_play_animation("jump")
		else:
			_play_animation("fall")
	else:
		if is_stopped_at_wall:
			_play_animation("idle")
		else:
			_play_animation("run")


	# 3. คำนวณความเร็ว X ตามสถานะกำแพง
	if is_on_wall():
		var wall_normal = get_wall_normal()
		var pushing_right_wall = (wall_normal.x < -0.5 and target_direction == 1)
		var pushing_left_wall = (wall_normal.x > 0.5 and target_direction == -1)

		if pushing_right_wall or pushing_left_wall:
			if not is_stopped_at_wall:
				is_stopped_at_wall = true
				log_msg("🧱 [WALL STOP] Hit wall! Waiting for opposite direction input...")
			
			# 💡 HOTFIX: ถ้านิ่งติดกำแพง แต่กำลัง "มุดลงชั้น" (_is_dropping_down) 
			# ให้ตัด velocity.x = 0 ทันที เพื่อไม่ให้ดันอัดเข้าหากำแพงตอนร่วง!
			if _is_dropping_down:
				velocity.x = 0
			else:
				velocity.x = target_direction * 1.0
		else:
			is_stopped_at_wall = false
			velocity.x = target_direction * speed
	else:
		is_stopped_at_wall = false
		velocity.x = target_direction * speed

	# 4. Lane Switching (Jump / Drop)
	handle_lane_switching()

	move_and_slide()

	if show_debug_draw:
		queue_redraw()


# ==========================================
# 🎮 การรับค่า Input ทิศทางจากผู้เล่น
# ==========================================
func handle_direction_input() -> void:
	if Input.is_action_just_pressed("ui_right") and target_direction != 1:
		change_direction(1)
	elif Input.is_action_just_pressed("ui_left") and target_direction != -1:
		change_direction(-1)


func change_direction(new_dir: int) -> void:
	var old_dir = target_direction
	target_direction = new_dir
	
	# ปรับภาพ Sprite และ Offset ของไฟฉาย
	sprite.flip_h = (target_direction == -1)
	flashlight_hitbox.position.x = flashlight_initial_x_offset * target_direction

	log_msg("🧭 [INPUT] Direction Changed: %d -> %d | Flashlight Offset X: %.2f" % [old_dir, target_direction, flashlight_hitbox.position.x])


# ==========================================
# ↕️ การเปลี่ยนชั้น
# ==========================================
func handle_lane_switching() -> void:
	if Input.is_action_just_pressed("ui_up"):
		if is_on_floor():
			velocity.y = jump_velocity
			log_msg("⬆️ [ACTION] JUMP executed!")
		
	elif Input.is_action_just_pressed("ui_down"):
		if is_on_floor() and not _is_dropping_down:
			log_msg("⬇️ [ACTION] DROPDOWN executed!")
			_drop_through_platform()


func _drop_through_platform() -> void:
	_is_dropping_down = true
	set_collision_mask_value(2, false)
	
	await get_tree().create_timer(0.25).timeout
	
	set_collision_mask_value(2, true)
	_is_dropping_down = false


# ==========================================
# 🛠️ HELPER & DEBUG
# ==========================================
func log_msg(text: String) -> void:
	if enable_logs:
		var time_str = Time.get_time_string_from_system()
		print_rich("[color=cyan][%s][/color] [b][Player][/b] %s" % [time_str, text])


func _play_animation(anim_name: String) -> void:
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)


func _verify_nodes() -> void:
	if not sprite: log_msg("❌ [MISSING NODE] Sprite2D is missing!")
	if not anim_player: log_msg("❌ [MISSING NODE] AnimationPlayer is missing!")
	if not flashlight_hitbox: log_msg("❌ [MISSING NODE] FlashlightHitbox (Area2D) is missing!")
	if not hurtbox: log_msg("❌ [MISSING NODE] Hurtbox (Area2D) is missing!")


func _draw() -> void:
	if not show_debug_draw:
		return
	draw_line(Vector2.ZERO, velocity * 0.2, Color.GREEN, 3.0)
	draw_circle(Vector2.ZERO, 4.0, Color.RED)
	var debug_info = "Stopped: %s\nDir: %d | Vel: (%.1f, %.1f)" % [is_stopped_at_wall, target_direction, velocity.x, velocity.y]
	draw_string(ThemeDB.fallback_font, Vector2(-50, -50), debug_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)