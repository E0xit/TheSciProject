class_name GameManager extends Node

signal score_changed(current_score: int)

@export var target_score: int = 100
@export var win_scene_path: String = "res://Scene/win_scene.tscn"
@export var score_display: Label

var score: int = 0

func _ready() -> void:
	# ให้ตัวมันเองเป็น Group เพื่อให้ Node อื่นใน Scene หาเจอง่ายๆ
	add_to_group("game_manager")
	score_display.text = "KILLS: %d / %d" % [score, target_score]

func add_score(amount: int = 1) -> void:
	score += amount
	score_changed.emit(score)
	print_rich("[color=yellow][GameManager][/color] 🏆 Score: %d/%d" % [score, target_score])
	score_display.text = "KILLS: %d / %d" % [score, target_score]
	if score >= target_score:
		_trigger_win()

func _trigger_win() -> void:
	print_rich("[color=green][GameManager][/color] 🎉 Target reached! Loading Win Scene...")
	if ResourceLoader.exists(win_scene_path):
		# 💡 เลื่อนการสลับ Scene ไปทำตอนจบ Physics Frame ป้องกัน Crash/Warning จาก Collision
		get_tree().call_deferred("change_scene_to_file", win_scene_path)
