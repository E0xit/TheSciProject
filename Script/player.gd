extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal player_died

@export_group("Player Stats")
@export var max_health: int = 3
@export var invincibility_time: float = 3.0

@export_group("Player Physics")
@export var speed: float = 550.0
@export var gravity_multiplier: float = 1.0
@export var jump_velocity: float = -650.0

@export_group("Floor Limits")
@export var restrict_top_floor_jump: bool = true
@export var top_floor_y_threshold: float = -200.0
@export var restrict_bottom_floor_drop: bool = true
@export var bottom_floor_y_threshold: float = 225.0

@export_group("Swipe Controls")
@export var min_swipe_distance: float = 50.0

@export_group("Player Audio SFX")
@export var sfx_jump: AudioStream
@export var sfx_stomp: AudioStream
@export var sfx_hurt: AudioStream
@export var sfx_die: AudioStream

@export_group("Game Over Config")
@export var lose_scene_path: String = "res://Scene/win_scene.tscn"

@export_group("Debug Options")
@export var enable_logs: bool = true
@export var show_debug_draw: bool = true

var current_health: int
var is_invincible: bool = false
var is_dead: bool = false
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var target_direction: int = 1
var is_stopped_at_wall: bool = false
var flashlight_initial_x_offset: float = 45.0
var _is_dropping_down: bool = false
var _swipe_start_pos: Vector2

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var flashlight_hitbox: Area2D = $FlashlightHitbox
@onready var hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	current_health = max_health
	
	if flashlight_hitbox:
		flashlight_initial_x_offset = abs(flashlight_hitbox.position.x)
		if flashlight_initial_x_offset == 0:
			flashlight_initial_x_offset = 10.0
		flashlight_hitbox.position.x = flashlight_initial_x_offset * target_direction
			
	if hurtbox:
		hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		
	_verify_nodes()
	add_to_group("player_body")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	handle_direction_input()
	handle_lane_switching()

	# Gravity Logic
	if not is_on_floor():
		var mult = gravity_multiplier * (2.5 if _is_dropping_down else 1.0)
		velocity.y += gravity * mult * delta

	# Wall Movement Logic
	if is_on_wall():
		var wall_normal = get_wall_normal()
		var pushing_wall = (wall_normal.x < -0.5 and target_direction == 1) or (wall_normal.x > 0.5 and target_direction == -1)
		
		if pushing_wall:
			if not is_stopped_at_wall:
				is_stopped_at_wall = true
				log_msg("🧱 [WALL STOP] Stopped at wall.")
			velocity.x = 0.0
		else:
			is_stopped_at_wall = false
			velocity.x = target_direction * speed
	else:
		is_stopped_at_wall = false
		velocity.x = target_direction * speed

	# Animation Logic (ยกเลิกการใช้ idle เล่น running ตลอดเมื่ออยู่บนพื้น)
	if not is_on_floor():
		_play_animation("jumping" if velocity.y < 0 else "dropping")
	else:
		_play_animation("running")

	move_and_slide()

	if show_debug_draw:
		queue_redraw()


# ==========================================
# 🏃 Movement Actions
# ==========================================
func handle_direction_input() -> void:
	if Input.is_action_just_pressed("right") and target_direction != 1:
		change_direction(1)
	elif Input.is_action_just_pressed("left") and target_direction != -1:
		change_direction(-1)


func change_direction(new_dir: int) -> void:
	target_direction = new_dir
	if sprite:
		sprite.flip_h = (target_direction == -1)
	if flashlight_hitbox:
		flashlight_hitbox.position.x = flashlight_initial_x_offset * target_direction


func handle_lane_switching() -> void:
	if Input.is_action_just_pressed("up"):
		_execute_jump()
	elif Input.is_action_just_pressed("down"):
		_execute_stomp()


func _execute_jump() -> void:
	var is_on_top = restrict_top_floor_jump and (global_position.y < top_floor_y_threshold)
	if is_on_floor() and not is_on_top:
		velocity.y = jump_velocity
		play_sfx(sfx_jump)
		log_msg("⬆️ [JUMP] Action Triggered!")
	elif is_on_top:
		log_msg("🚫 [JUMP REJECTED] Top Floor!")


func _execute_stomp() -> void:
	var is_on_bottom = restrict_bottom_floor_drop and (global_position.y > bottom_floor_y_threshold)
	if is_on_floor() and not _is_dropping_down and not is_on_bottom:
		log_msg("🔨 [STOMP] Action Triggered!")
		_drop_through_platform()
	elif is_on_bottom:
		log_msg("🚫 [DROP REJECTED] Bottom Floor!")


func _drop_through_platform() -> void:
	_is_dropping_down = true
	play_sfx(sfx_stomp if sfx_stomp else sfx_jump)
	set_collision_mask_value(3, false)
	await get_tree().create_timer(0.25).timeout
	set_collision_mask_value(3, true)
	_is_dropping_down = false


# ==========================================
# 🩸 Health & Damage Mechanics
# ==========================================
func take_damage(amount: int = 1) -> void:
	if is_invincible or is_dead or current_health <= 0:
		return

	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	log_msg("💔 [DAMAGE] Took %d damage! HP: %d/%d" % [amount, current_health, max_health])

	if current_health <= 0:
		die()
	else:
		play_sfx(sfx_hurt)
		_trigger_invincibility()


func heal(amount: int = 1) -> void:
	if is_dead or current_health <= 0:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
	log_msg("💚 [HEAL] Healed %d HP! HP: %d/%d" % [amount, current_health, max_health])


func die() -> void:
	if is_dead:
		return
		
	is_dead = true
	log_msg("💀 [PLAYER DIED] Sequence Started!")
	player_died.emit()
	
	disable_controls()
	play_sfx(sfx_die)
	
	# 💡 [FIXED] สั่งปิด Spawner ทันทีเมื่อตาย
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if spawner:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
		else:
			spawner.queue_free()

	_clear_all_enemies_silent()
	_play_animation("death")

	await get_tree().create_timer(5.0).timeout

	if ResourceLoader.exists(lose_scene_path):
		get_tree().call_deferred("change_scene_to_file", lose_scene_path)
	else:
		log_msg("❌ [ERROR] Lose Scene Path invalid: " + lose_scene_path)


func _clear_all_enemies_silent() -> void:
	for child in get_tree().current_scene.get_children():
		if child is EnemyBase:
			if child.death_effect:
				var fx = child.death_effect.instantiate()
				fx.global_position = child.global_position
				get_tree().current_scene.add_child(fx)
			child.queue_free()


func disable_controls() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process_unhandled_input(false)
	
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	if flashlight_hitbox:
		flashlight_hitbox.set_deferred("monitoring", false)
		flashlight_hitbox.set_deferred("monitorable", false)


func _trigger_invincibility() -> void:
	is_invincible = true
	
	# 💡 คำนวณจำนวนรอบการกระพริบ (เวลาอมตะทั้งหมด / รวมเวลา 1 ลูปกระพริบ)
	var flash_interval: float = 0.07
	var loop_count: int = int(invincibility_time / (flash_interval * 2))
	
	var tween = create_tween().set_loops(loop_count)
	
	# 1. ปรับค่า Alpha เป็น 0 (หายตัวไปเลย) ใช้เวลาเปลี่ยน 0.07 วินาที
	tween.tween_property(sprite, "modulate:a", 0.0, flash_interval)
	# 2. ปรับค่า Alpha กลับเป็น 1.0 (ปรากฏตัวขึ้นมา) ใช้เวลาเปลี่ยน 0.07 วินาที
	tween.tween_property(sprite, "modulate:a", 1.0, flash_interval)

	# รอกระพริบจนหมดเวลาอมตะ
	await get_tree().create_timer(invincibility_time).timeout
	
	# คืนค่าทุกอย่างให้กลับมาปกติ
	is_invincible = false
	if sprite:
		sprite.modulate.a = 1.0


func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox") or area.is_in_group("enemy_projectile"):
		take_damage(1)


# ==========================================
# 📱 Swipe Controls
# ==========================================
func _unhandled_input(event: InputEvent) -> void:
	if is_dead: 
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_swipe_start_pos = event.position
		else:
			_calculate_swipe(_swipe_start_pos, event.position)


func _calculate_swipe(start_pos: Vector2, end_pos: Vector2) -> void:
	var swipe_vector = end_pos - start_pos
	if swipe_vector.length() < min_swipe_distance:
		return 

	if abs(swipe_vector.x) > abs(swipe_vector.y):
		if swipe_vector.x > 0 and target_direction != 1:
			change_direction(1)
		elif swipe_vector.x < 0 and target_direction != -1:
			change_direction(-1)
	else:
		if swipe_vector.y < 0:
			_execute_jump()
		else:
			_execute_stomp()


# ==========================================
# 🔊 Audio & Helpers
# ==========================================
func play_sfx(stream: AudioStream, pitch_randomness: float = 0.1) -> void:
	if not stream: 
		return
	var fx_player = AudioStreamPlayer2D.new()
	fx_player.stream = stream
	fx_player.pitch_scale = 1.0 + randf_range(-pitch_randomness, pitch_randomness)
	add_child(fx_player)
	fx_player.play()
	fx_player.finished.connect(fx_player.queue_free)


func log_msg(text: String) -> void:
	if enable_logs:
		print_rich("[color=cyan][%s][/color] [b][Player][/b] %s" % [Time.get_time_string_from_system(), text])


func _play_animation(anim_name: String) -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name or not sprite.is_playing():
			sprite.play(anim_name)


func _verify_nodes() -> void:
	if not sprite or not flashlight_hitbox or not hurtbox:
		log_msg("❌ [ERROR] Missing required child nodes!")


func _draw() -> void:
	if not show_debug_draw: 
		return
	draw_line(Vector2.ZERO, velocity * 0.2, Color.GREEN, 3.0)
	draw_circle(Vector2.ZERO, 4.0, Color.RED)
	var debug_info = "HP: %d/%d | Dead: %s\nDir: %d | Vel: (%.1f, %.1f)" % [current_health, max_health, is_dead, target_direction, velocity.x, velocity.y]
	draw_string(ThemeDB.fallback_font, Vector2(-50, -50), debug_info, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.YELLOW)