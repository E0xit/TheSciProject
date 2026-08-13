extends CharacterBody2D

signal health_changed(current_hp, max_hp)
signal player_died


@export_group("Player Stats")
@export var max_health: int = 3
@export var invincibility_time: float = 3.0

@export_group("Player Physics")
@export var speed: float = 550.0
@export var gravity_multiplier: float = 1
@export var jump_velocity: float = -650.0

@export_group("Floor Limits")
@export var restrict_top_floor_jump: bool = true
@export var top_floor_y_threshold: float = -200.0
@export var restrict_bottom_floor_drop: bool = true
@export var bottom_floor_y_threshold: float = 225.0 # ปรับค่า Y ของ Floor 1 ใน Inspector ตามจริง

@export_group("Swipe Controls")
@export var min_swipe_distance: float = 50.0 # ระยะห่างขั้นต่ำที่ถือว่าเป็นการ "ปัด" ไม่ใช่แค่ "แตะ"

var _swipe_start_pos: Vector2

@export_group("Debug Options")
@export var enable_logs: bool = true
@export var show_debug_draw: bool = true

var current_health: int
var is_invincible: bool = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var target_direction: int = 1
var is_stopped_at_wall: bool = false
var flashlight_initial_x_offset: float = 35.0
var _is_dropping_down: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D # 💡 เปลี่ยนเป็น AnimatedSprite2D
@onready var flashlight_hitbox: Area2D = $FlashlightHitbox
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	current_health = max_health
	
	if flashlight_hitbox:
		flashlight_initial_x_offset = abs(flashlight_hitbox.position.x)
		if flashlight_initial_x_offset == 0:
			flashlight_initial_x_offset = 10.0
			flashlight_hitbox.position.x = flashlight_initial_x_offset
			
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		
	# ปิด Stomp Hitbox ไว้ตั้งแต่เริ่มต้น
		
	_verify_nodes()


func _physics_process(delta: float) -> void:
	handle_direction_input()
	handle_lane_switching()

	# 1. Gravity Logic (คิดแรงโน้มถ่วงอย่างเดียว ยังไม่สั่งเล่น Animation ตรงนี้)
	if not is_on_floor():
		if _is_dropping_down:
			velocity.y += gravity * gravity_multiplier * 2.5 * delta
		else:
			velocity.y += gravity * gravity_multiplier * delta

	# 2. Wall Movement Logic (คำนวณตำแหน่งและอัปเดตสถานะ is_stopped_at_wall ให้เสร็จสรรพ)
	if is_on_wall():
		var wall_normal = get_wall_normal()
		var pushing_wall = (wall_normal.x < -0.5 and target_direction == 1) or (wall_normal.x > 0.5 and target_direction == -1)

		var is_real_wall = false
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			if collision and collision.get_collider():
				if collision.get_collider().get_collision_layer_value(1):
					is_real_wall = true
					break

		if pushing_wall and is_real_wall :
			if not is_stopped_at_wall:
				is_stopped_at_wall = true
				log_msg("🧱 [WALL STOP] Waiting for direction change...")
			
			velocity.x = 0.0
		else:
			is_stopped_at_wall = false
	else:
		is_stopped_at_wall = false
		velocity.x =  target_direction * speed

	# 3. Animation Logic (สลับแอนิเมชันตรงนี้ หลังรู้ค่า is_stopped_at_wall ที่ถูกต้องแล้ว!)
	if not is_on_floor():
		_play_animation("jumping" if velocity.y < 0 else "dropping")
	else:
		_play_animation("idle" if is_stopped_at_wall else "running")

	move_and_slide()

	if show_debug_draw:
		queue_redraw()

func _drop_through_platform() -> void:
	_is_dropping_down = true

	set_collision_mask_value(3, false)
	await get_tree().create_timer(0.25).timeout
	set_collision_mask_value(3, true)

		
	_is_dropping_down = false


func handle_direction_input() -> void:
	if Input.is_action_just_pressed("right") and target_direction != 1:
		change_direction(1)
	elif Input.is_action_just_pressed("left") and target_direction != -1:
		change_direction(-1)


func change_direction(new_dir: int) -> void:
	target_direction = new_dir
	if sprite:
		sprite.flip_h = (target_direction == -1)
    
    # ย้ายตำแหน่ง + รีเซ็ต Physics State เล็กน้อยกันบั๊กวาร์ปชน
	if flashlight_hitbox:
		flashlight_hitbox.position.x = flashlight_initial_x_offset * target_direction


func handle_lane_switching() -> void:
	if Input.is_action_just_pressed("up"):
		_execute_jump()
	elif Input.is_action_just_pressed("down"):
		_execute_stomp()

# 💡 แยก Logic กระโดดออกมา
func _execute_jump() -> void:
	var is_on_top_floor = restrict_top_floor_jump and (global_position.y < top_floor_y_threshold)
	if is_on_floor() and not is_on_top_floor:
		velocity.y = jump_velocity
		log_msg("⬆️ [JUMP] Action Triggered!")
	elif is_on_top_floor:
		log_msg("🚫 [JUMP REJECTED] Reached Top Floor!")

# 💡 แยก Logic มุดลงออกมา
func _execute_stomp() -> void:
	var is_on_bottom_floor = restrict_bottom_floor_drop and (global_position.y > bottom_floor_y_threshold)
	if is_on_floor() and not _is_dropping_down and not is_on_bottom_floor:
		log_msg("🔨 [STOMP] Action Triggered!")
		_drop_through_platform()
	elif is_on_bottom_floor:
		log_msg("🚫 [DROP REJECTED] Reached Bottom Floor!")


# ==========================================
# 🩸 Health & Damage Mechanics
# ==========================================
func take_damage(amount: int = 1) -> void:
	if is_invincible or current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	log_msg("💔 [DAMAGE] Player took %d damage! Current HP: %d/%d" % [amount, current_health, max_health])

	if current_health <= 0:
		die()
	else:
		_trigger_invincibility()


func heal(amount: int = 1) -> void:
	if current_health <= 0:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	log_msg("💚 [HEAL] Player healed %d HP! Current HP: %d/%d" % [amount, current_health, max_health])


func die() -> void:
	log_msg("💀 [PLAYER DIED] Game Over triggered!")
	player_died.emit()
	set_physics_process(false)


func _trigger_invincibility() -> void:
	is_invincible = true
	var tween = create_tween().set_loops(int(invincibility_time / 0.1))
	tween.tween_property(sprite, "modulate:a", 0.2, 0.05)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.05)

	await get_tree().create_timer(invincibility_time).timeout
	is_invincible = false
	sprite.modulate.a = 1.0


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox") or area.is_in_group("enemy_projectile"):
		take_damage(1)


# ==========================================
# 🛠️ Helpers & Debug
# ==========================================
func log_msg(text: String) -> void:
	if enable_logs:
		print_rich("[color=cyan][%s][/color] [b][Player][/b] %s" % [Time.get_time_string_from_system(), text])


func _play_animation(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		# 1. สั่งเล่นเฉพาะตอนที่ชื่อเปลี่ยนไปจากเดิม หรือ อนิเมชันมันหยุดรันอยู่
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)
			log_msg("🎬 [ANIM START] Switched to -> " + anim_name)
			
		# 2. Print Debug เช็กสถานะแบบ Real-time (ทำงานทุกเฟรม)
		if enable_logs:
			print("🔍 [Anim Debug] Request: %s | Playing: %s | Frame: %d | is_playing: %s" % [
				anim_name,
				sprite.animation,
				sprite.frame,
				str(sprite.is_playing())
			])
func _verify_nodes() -> void:
	# 💡 ลบการเช็ก anim_player ออก
	if not sprite or not flashlight_hitbox or not hurtbox:
		log_msg("❌ [ERROR] Missing required child nodes!")


func _draw() -> void:
	if not show_debug_draw: return
	draw_line(Vector2.ZERO, velocity * 0.2, Color.GREEN, 3.0)
	draw_circle(Vector2.ZERO, 4.0, Color.RED)
	var debug_info = "HP: %d/%d | Stopped: %s\nDir: %d | Vel: (%.1f, %.1f)" % [current_health, max_health, is_stopped_at_wall, target_direction, velocity.x, velocity.y]
	draw_string(ThemeDB.fallback_font, Vector2(-50, -50), debug_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)


# ==========================================
# 📱 Swipe Control Mechanics
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	# ตรวจจับการแตะหน้าจอ (หรือคลิกเมาส์)
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_pos = event.position # บันทึกจุดที่เริ่มแตะ
		else:
			_calculate_swipe(_swipe_start_pos, event.position) # คำนวณตอนปล่อยนิ้ว

func _calculate_swipe(start_pos: Vector2, end_pos: Vector2) -> void:
	var swipe_vector = end_pos - start_pos
	
	# ถ้าลากสั้นกว่า 50 พิกเซล ให้ถือว่าเป็นการแตะ (Tap) ไม่ใช่ปัด
	if swipe_vector.length() < min_swipe_distance:
		return 

	# เช็กว่าปัดแกน X (แนวนอน) หรือ แกน Y (แนวตั้ง) แรงกว่ากัน
	if abs(swipe_vector.x) > abs(swipe_vector.y):
		# ➡️ แนวนอน: สลับทิศทางวิ่ง
		if swipe_vector.x > 0 and target_direction != 1:
			change_direction(1) # ปัดขวา
		elif swipe_vector.x < 0 and target_direction != -1:
			change_direction(-1) # ปัดซ้าย
	else:
		# ⬆️ แนวตั้ง: กระโดด หรือ มุด
		if swipe_vector.y < 0:
			_execute_jump() # ปัดขึ้น (Y ติดลบคือขึ้น)
		else:
			_execute_stomp() # ปัดลง (Y เป็นบวกคือลง)