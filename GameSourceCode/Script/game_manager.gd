class_name GameManager extends Node

signal score_changed(current_score: int)

@export var target_score: int = 67
@export var win_scene_path: String = "res://Scene/win_scene.tscn"
@export var score_display: Label

@export_group("Game Events SFX & Audio")
@export var sfx_win: AudioStream

var score: int = 0
var is_game_over: bool = false

func _ready() -> void:
	add_to_group("game_manager")
	score_display.text = "%d" % [target_score - score]

func add_score(amount: int = 1) -> void:
	if is_game_over:
		return
		
	score += amount
	score_changed.emit(score)
	print_rich("[color=yellow][GameManager][/color] 🏆 Score: %d/%d" % [score, target_score])
	score_display.text = "%d" % [target_score - score]
	
	if score >= target_score:
		_trigger_win()

func _trigger_win() -> void:
	if is_game_over:
		return
	is_game_over = true
	
	print_rich("[color=green][GameManager][/color] 🎉 Victory Achieved! Triggering Win Sequence...")
	
	# 1. เล่นเสียงชนะ
	if sfx_win:
		var audio_player = AudioStreamPlayer.new()
		audio_player.stream = sfx_win
		add_child(audio_player)
		audio_player.play()

	# 2. ริบการควบคุม Player
	var player = get_tree().get_first_node_in_group("player_body")
	if player and player.has_method("disable_controls"):
		player.disable_controls()

	# 3. สั่งหยุด Spawner ทันที
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if spawner:
		if spawner.has_method("stop_spawning"):
			spawner.stop_spawning()
		else:
			spawner.queue_free()

	# 4. 🎆 ค่อยๆ ทยอยทำลายศัตรูทีละตัวแบบสุ่ม (รันขนานไปกับช่วงนับถอยหลัง)
	_kill_enemies_gradually()

	# 5. Count Down 5 วินาที
	for i in range(5, 0, -1):
		if score_display:
			score_display.text = "WIN! Next Scene in %d..." % i
		await get_tree().create_timer(1.0).timeout

	# 6. ย้าย Scene
	if ResourceLoader.exists(win_scene_path):
		get_tree().call_deferred("change_scene_to_file", win_scene_path)


# 🍿 ฟังก์ชันสุ่มระเบิดศัตรูทีละตัวแบบมีจังหวะ
func _kill_enemies_gradually() -> void:
	var enemies: Array = []
	
	# ดึงศัตรูทั้งหมดเข้า Array ไม่ให้ซ้ำกัน
	for node in get_tree().get_nodes_in_group("enemy_hitbox"):
		var enemy = node.get_parent()
		if enemy and is_instance_valid(enemy) and not enemies.has(enemy):
			enemies.append(enemy)

	# 🎲 สุ่มลำดับศัตรูใน Array
	enemies.shuffle()

	# 💥 ค่อยๆ สั่ง die() ทีละตัวพร้อมสุ่มเวลาหน่วง
	for enemy in enemies:
		if is_instance_valid(enemy):
			if enemy.has_method("die"):
				enemy.die()
			else:
				enemy.queue_free()
		
		# หน่วงเวลาสุ่มช่วง 0.08 ถึง 0.25 วินาที ให้เหมือนเอฟเฟกต์ป็อบคอร์น
		await get_tree().create_timer(0.25).timeout