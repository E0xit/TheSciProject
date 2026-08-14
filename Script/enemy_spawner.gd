class_name EnemySpawner extends Node2D

@export_group("Enemy Scenes & Ratios")
@export var roamer_scene: PackedScene
@export var shooter_scene: PackedScene
@export var jumper_scene: PackedScene

# ค่าน้ำหนักสัดส่วนการเกิด
@export var roamer_weight: float = 35.0  # เกิดง่ายสุด
@export var shooter_weight: float = 30.0 # ปานกลาง
@export var jumper_weight: float = 35.0  # สายป่วน

@export_group("Floor Y Configuration")
@export var floor_y_positions: Array[float] = [-325.0, -100.0, 100.0, 325.0]
@export var spawn_x_min: float = -835.0
@export var spawn_x_max: float = 835.0

@export_group("Spawn Safety & Restrictions")
@export var player_safe_distance_x: float = 200.0
@export var enemy_safe_radius: float = 80.0

@export_group("Progressive Scaling (ยิงสู้นาน ยิ่งเดือด!)")
@export var initial_spawn_interval: float = 3.5
@export var min_spawn_interval: float = 1 # ปรับเวลารอไม่ให้ถี่เกินไปเพราะตอนนี้เกิดทีเป็นกลุ่มแล้ว
@export var interval_decay_rate: float = 0.05

@export var initial_max_enemies: int = 5
@export var max_enemies_cap: int = 18
@export var enemies_increase_step: int = 15

@export_group("Burst Spawn Configuration (สปอว์นพร้อมกัน)")
@export var max_burst_count: int = 6        # จำนวนสปอว์นพร้อมกันสูงสุด
@export var score_for_max_burst: int = 50     # คะแนนที่เริ่มสปอว์นทีละ 4 ตัวแบบเต็มสปีด

var current_spawn_interval: float
var spawn_timer: Timer
var player: CharacterBody2D

func _ready() -> void:
	current_spawn_interval = initial_spawn_interval
	
	player = get_tree().get_first_node_in_group("player_body") as CharacterBody2D
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)

	_setup_spawn_timer()

func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = current_spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_try_spawn_enemy)
	add_child(spawn_timer)

func _try_spawn_enemy() -> void:
	# 1. ดึง Score ปัจจุบัน
	var current_score = 0
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager and "score" in manager:
		current_score = manager.score

	# 2. คำนวณ Cap จำนวนศัตรูสูงสุดในแมพ
	var dynamic_max_enemies = min(
		initial_max_enemies + int(current_score / float(enemies_increase_step)),
		max_enemies_cap
	)

	# 3. เช็กจำนวนศัตรูที่มีอยู่ในแมพตอนนี้
	var active_enemies = get_tree().get_nodes_in_group("enemy_hitbox")
	var current_count = active_enemies.size()
	
	if current_count >= dynamic_max_enemies:
		return

	# 4. 💡 คำนวณขนาด Burst (สปอว์นพร้อมกันกี่ตัวรอบนี้?)
	# คำนวณจาก Score: เริ่มต้น 1 ตัว -> ค่อยๆ เพิ่มตาม Progress สู่ max_burst_count (4 ตัว)
	var score_progress: float = clamp(float(current_score) / float(score_for_max_burst), 0.0, 1.0)
	var target_burst: int = int(lerp(1.0, float(max_burst_count), score_progress))
	# สุ่มเล็กน้อยให้ดูธรรมชาติ (เช่น สุ่มระหว่าง 1 ถึง target_burst)
	var spawn_amount: int = randi_range(3, target_burst)

	# 5. วน Loop สปอว์นศัตรูตามจำนวน spawn_amount
	for i in range(spawn_amount):
		# Re-check ว่าเต็ม Cap แล้วหรือยังในแต่ละรอบของการเสก
		active_enemies = get_tree().get_nodes_in_group("enemy_hitbox")
		if active_enemies.size() >= dynamic_max_enemies:
			break

		var spawn_pos = _find_valid_spawn_position()
		if spawn_pos == Vector2.ZERO:
			continue # หาจุดว่างไม่ได้ข้ามไปลองตัวถัดไป

		var selected_scene = _get_weighted_random_enemy()
		if not selected_scene:
			continue

		var enemy_instance = selected_scene.instantiate() as Node2D
		enemy_instance.global_position = spawn_pos
		get_tree().current_scene.add_child(enemy_instance)

	# 6. เร่งสปีดคูลดาวน์ให้เกิดถี่ขึ้นเรื่อยๆ
	current_spawn_interval = max(min_spawn_interval, current_spawn_interval - interval_decay_rate)
	spawn_timer.wait_time = current_spawn_interval

func _find_valid_spawn_position() -> Vector2:
	var max_attempts = 15
	
	for i in range(max_attempts):
		var random_y = floor_y_positions.pick_random()
		var random_x = randf_range(spawn_x_min, spawn_x_max)
		var candidate_pos = Vector2(random_x, random_y)

		# 🛑 เงื่อนไขที่ 1: ห้ามเกิดใกล้ผู้เล่นแกน X ในชั้นเดียวกัน
		if player and is_instance_valid(player):
			var same_floor = abs(player.global_position.y - candidate_pos.y) < 50.0
			var close_x = abs(player.global_position.x - candidate_pos.x) < player_safe_distance_x
			if same_floor and close_x:
				continue

		# 🛑 เงื่อนไขที่ 2: ห้ามเกิดซ้อนศัตรูตัวอื่น
		var overlaps_enemy = false
		for node in get_tree().current_scene.get_children():
			if node is EnemyBase and is_instance_valid(node):
				if node.global_position.distance_to(candidate_pos) < enemy_safe_radius:
					overlaps_enemy = true
					break
		
		if overlaps_enemy:
			continue

		return candidate_pos

	return Vector2.ZERO

func _get_weighted_random_enemy() -> PackedScene:
	var total_weight = roamer_weight + shooter_weight + jumper_weight
	if total_weight <= 0:
		return null

	var random_roll = randf_range(0.0, total_weight)
	
	if random_roll < roamer_weight:
		return roamer_scene
	elif random_roll < roamer_weight + shooter_weight:
		return shooter_scene
	else:
		return jumper_scene
