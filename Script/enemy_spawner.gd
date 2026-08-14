class_name EnemySpawner extends Node2D

@export_group("Enemy Scenes & Ratios")
@export var roamer_scene: PackedScene
@export var shooter_scene: PackedScene
@export var jumper_scene: PackedScene

@export var roamer_weight: float = 35.0  
@export var shooter_weight: float = 30.0 
@export var jumper_weight: float = 35.0  

@export_group("Floor Y Configuration")
@export var floor_y_positions: Array[float] = [-325.0, -100.0, 100.0, 325.0]
@export var spawn_x_min: float = -835.0
@export var spawn_x_max: float = 835.0

@export_group("Spawn Safety & Restrictions")
@export var player_safe_distance_x: float = 200.0
@export var enemy_safe_radius: float = 80.0

@export_group("Progressive Scaling (ยิงสู้นาน ยิ่งเดือด!)")
@export var initial_spawn_interval: float = 3.5
@export var min_spawn_interval: float = 1.0
@export var interval_decay_rate: float = 0.05

@export var initial_max_enemies: int = 5
@export var max_enemies_cap: int = 18
@export var enemies_increase_step: int = 15

@export_group("Burst Spawn Configuration (สปอว์นพร้อมกัน)")
@export var max_burst_count: int = 6        
@export var score_for_max_burst: int = 50     

var current_spawn_interval: float
var spawn_timer: Timer
var player: CharacterBody2D
var is_spawning: bool = true # 💡 เพิ่ม Flag คุมสถานะการทำงาน

func _ready() -> void:
	add_to_group("enemy_spawner") # 💡 [FIXED] ใส่กลุ่มให้ Spawner เพื่อให้ค้นหาเจอ!
	current_spawn_interval = initial_spawn_interval
	
	player = get_tree().get_first_node_in_group("player_body") as CharacterBody2D
	if not player:
		player = get_tree().current_scene.find_child("Player", true, false)

	_setup_spawn_timer()

# 💡 [NEW] ฟังก์ชันสั่งหยุดเสก และทำลายตัวเองทันที
func stop_spawning() -> void:
	is_spawning = false
	if spawn_timer:
		spawn_timer.stop()
	queue_free()

func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = current_spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_try_spawn_enemy)
	add_child(spawn_timer)

func _try_spawn_enemy() -> void:
	if not is_spawning:
		return

	var current_score = 0
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager and "score" in manager:
		current_score = manager.score

	var dynamic_max_enemies = min(
		initial_max_enemies + int(current_score / float(enemies_increase_step)),
		max_enemies_cap
	)

	var active_enemies = get_tree().get_nodes_in_group("enemy_hitbox")
	var current_count = active_enemies.size()
	
	if current_count >= dynamic_max_enemies:
		return

	var score_progress: float = clamp(float(current_score) / float(score_for_max_burst), 0.0, 1.0)
	var target_burst: int = int(lerp(1.0, float(max_burst_count), score_progress))
	var spawn_amount: int = randi_range(3, target_burst)

	for i in range(spawn_amount):
		if not is_spawning:
			break

		active_enemies = get_tree().get_nodes_in_group("enemy_hitbox")
		if active_enemies.size() >= dynamic_max_enemies:
			break

		var spawn_pos = _find_valid_spawn_position()
		if spawn_pos == Vector2.ZERO:
			continue

		var selected_scene = _get_weighted_random_enemy()
		if not selected_scene:
			continue

		var enemy_instance = selected_scene.instantiate() as Node2D
		enemy_instance.global_position = spawn_pos
		get_tree().current_scene.add_child(enemy_instance)

	current_spawn_interval = max(min_spawn_interval, current_spawn_interval - interval_decay_rate)
	spawn_timer.wait_time = current_spawn_interval

func _find_valid_spawn_position() -> Vector2:
	var max_attempts = 20
	
	for i in range(max_attempts):
		var random_y = floor_y_positions.pick_random()
		var random_x = randf_range(spawn_x_min, spawn_x_max)
		var candidate_pos = Vector2(random_x, random_y)

		# 🛑 เช็กเงื่อนไขระยะห่างจากผู้เล่น
		if player and is_instance_valid(player):
			# 💡 1. ปรับระยะ X ให้กว้างขึ้นตามสปีดผู้เล่น (เช่น 350px)
			var close_x = abs(player.global_position.x - candidate_pos.x) < 350.0
			
			# 💡 2. เช็กว่าผู้เล่นอยู่ใกล้ชั้น Y นี้หรือไม่ (ขยายช่วงเป็น 150px คลุมช่วงกระโดด)
			var near_this_floor = abs(player.global_position.y - candidate_pos.y) < 150.0
			
			if near_this_floor and close_x:
				continue # ปลอดภัยแน่นอน ทั้งจังหวะวิ่งและจังหวะกระโดด!

		# 🛑 เช็กเงื่อนไขห้ามเกิดซ้อนกับศัตรูตัวอื่น
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