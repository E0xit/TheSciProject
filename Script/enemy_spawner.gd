class_name EnemySpawner extends Node2D

@export_group("Enemy Scenes & Ratios")
@export var roamer_scene: PackedScene
@export var shooter_scene: PackedScene
@export var jumper_scene: PackedScene

# ค่าน้ำหนักสัดส่วนการเกิด (ปรับเพิ่ม/ลดใน Inspector ได้ตามใจชอบ)
@export var roamer_weight: float = 50.0  # เกิดง่ายสุด
@export var shooter_weight: float = 10.0 # ปานกลาง
@export var jumper_weight: float = 40.0  # สายป่วน

@export_group("Floor Y Configuration")
# พิกัด Y คงที่ของทั้ง 4 ชั้นในเกม
@export var floor_y_positions: Array[float] = [-325.0, -100.0, 100.0, 325.0]
@export var spawn_x_min: float = -835.0  # ขอบซ้ายสุดของแมพ
@export var spawn_x_max: float = 835.0   # ขอบขวาสุดของแมพ

@export_group("Spawn Safety & Restrictions")
@export var player_safe_distance_x: float = 200.0 # ระยะห่างแกน X จากตัวผู้เล่น
@export var enemy_safe_radius: float = 80.0       # รัศมีป้องกันไม่ให้ศัตรูเกิดซ้อนกัน

@export_group("Progressive Scaling (ยิงสู้นาน ยิ่งเดือด!)")
@export var initial_spawn_interval: float = 3.5  # ระยะเวลาเกิดเริ่มแรก (วินาที)
@export var min_spawn_interval: float = 0.8      # เกิดเร็วสุดได้เท่านี้
@export var interval_decay_rate: float = 0.05    # ทุกๆ การเกิด จะลดเวลารอลงเท่าไหร่

@export var initial_max_enemies: int = 5         # จำนวนศัตรูสูงสุดช่วงเริ่มเกม
@export var max_enemies_cap: int = 18            # จำนวนศัตรูสูงสุดเต็มเพดานฉาก
@export var enemies_increase_step: int = 15      # จัดการศัตรูได้ครบทุกๆ กี่ตัว จะขยาย Cap ศัตรูเพิ่ม 1 ตัว

var current_spawn_interval: float
var spawn_timer: Timer
var player: CharacterBody2D

func _ready() -> void:
	current_spawn_interval = initial_spawn_interval
	
	# ค้นหา Player ใน Scene
	player = get_tree().get_first_node_in_group("player_body") as CharacterBody2D
	if not player:
		# สำรองกรณีไม่ได้ตั้ง group ไว้ ให้ลองหา Node ชื่อ Player
		player = get_tree().current_scene.find_child("Player", true, false)

	_setup_spawn_timer()

func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = current_spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_try_spawn_enemy)
	add_child(spawn_timer)

func _try_spawn_enemy() -> void:
	# 1. คำนวณ Cap จำนวนศัตรูสูงสุดปัจจุบันตาม Score
	var current_score = 0
	var manager = get_tree().get_first_node_in_group("game_manager")
	if manager and "score" in manager:
		current_score = manager.score

	var dynamic_max_enemies = min(
		initial_max_enemies + int(current_score / float(enemies_increase_step)),
		max_enemies_cap
	)

	# 2. เช็กว่าศัตรูเต็มแมพหรือยัง (ใช้ size() จาก get_nodes_in_group ได้เลย!)
	# 💡 หมายเหตุ: ต้องแน่ใจว่า EnemyBase ทุกตัวมี Node/Area ที่แอดเข้า group "enemy_hitbox" หรือสร้าง group "enemies" ไว้เจ้าค่ะ
	var active_enemies = get_tree().get_nodes_in_group("enemy_hitbox")
	if active_enemies.size() >= dynamic_max_enemies:
		return # ศัตรูแน่นแมพแล้ว รอให้ผู้เล่นกำจัดก่อน

	# 3. สุ่มหาพิกัดปลอดภัย (Safe Position)
	var spawn_pos = _find_valid_spawn_position()
	if spawn_pos == Vector2.ZERO:
		return # สุ่มหาพิกัดที่ปลอดภัยในเฟรมนี้ไม่ได้ ยกยอดไปรอบหน้า

	# 4. สุ่มเลือกประเภทศัตรูตาม Weights
	var selected_scene = _get_weighted_random_enemy()
	if not selected_scene:
		return

	# 5. เสกศัตรูลงฉาก
	var enemy_instance = selected_scene.instantiate() as Node2D
	enemy_instance.global_position = spawn_pos
	get_tree().current_scene.add_child(enemy_instance)

	# 6. เร่งสปีดคูลดาวน์ให้เกิดถี่ขึ้นเรื่อยๆ
	current_spawn_interval = max(min_spawn_interval, current_spawn_interval - interval_decay_rate)
	spawn_timer.wait_time = current_spawn_interval

func _find_valid_spawn_position() -> Vector2:
	var max_attempts = 15 # สุ่มหาตำแหน่งสูงสุด 15 ครั้งต่อเฟรมเพื่อไม่ให้เกมกระตุก
	
	for i in range(max_attempts):
		# สุ่มชั้น (Floor Y)
		var random_y = floor_y_positions.pick_random()
		# สุ่มตำแหน่ง X
		var random_x = randf_range(spawn_x_min, spawn_x_max)
		var candidate_pos = Vector2(random_x, random_y)

		# 🛑 เช็กเงื่อนไขที่ 1: ห้ามเกิดใกล้ผู้เล่นในแกน X ถ้อยู่ชั้นเดียวกัน
		if player and is_instance_valid(player):
			var same_floor = abs(player.global_position.y - candidate_pos.y) < 50.0
			var close_x = abs(player.global_position.x - candidate_pos.x) < player_safe_distance_x
			if same_floor and close_x:
				continue # อยู่ใกล้ผู้เล่นเกินไป สุ่มใหม่!

		# 🛑 เช็กเงื่อนไขที่ 2: ห้ามเกิดซ้อนกับศัตรูตัวอื่น[cite: 12]
		var overlaps_enemy = false
		for node in get_tree().current_scene.get_children():
			if node is EnemyBase and is_instance_valid(node):
				if node.global_position.distance_to(candidate_pos) < enemy_safe_radius:
					overlaps_enemy = true
					break
		
		if overlaps_enemy:
			continue # เกิดซ้อนตัวอื่น สุ่มใหม่!

		# ผ่านทุกเงื่อนไข ได้พิกัดปลอดภัย!
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