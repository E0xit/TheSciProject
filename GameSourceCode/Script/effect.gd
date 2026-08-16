extends Node2D

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var audio_player: AudioStreamPlayer2D = $AudioStreamPlayer2D

func _ready() -> void:
	_play_random_sfx()
	_play_random_animation()

# 🔊 1. สุ่ม Pitch เสียงในย่าน +- 0.5 (ช่วง 0.5 ถึง 1.5)
func _play_random_sfx() -> void:
	if audio_player and audio_player.stream:
		# randf_range(-0.5, 0.5) จะได้ค่าเบี่ยงเบน แล้วเอาไปบวกกับ Base Pitch (1.0)
		var random_pitch = 1.0 + randf_range(-0.2, 0.5)
		
		# ป้องกันกรณีค่า Pitch ต่ำเกินไปจนเสียงกวนหรือเงียบดับ
		audio_player.pitch_scale = max(0.1, random_pitch)
		audio_player.play()

# 🎬 2. สุ่มเลือก Animation ใน SpriteFrames ขึ้นมาเล่น
func _play_random_animation() -> void:
	if anim_sprite and anim_sprite.sprite_frames:
		# เชื่อม Signal เมื่อแอนิเมชันเล่นจบให้ลบตัวเองทิ้ง
		if not anim_sprite.animation_finished.is_connected(_on_animation_finished):
			anim_sprite.animation_finished.connect(_on_animation_finished)
		
		# ดึงรายชื่อ Animation ทั้งหมดที่มีอยู่ใน SpriteFrames ออกมาเป็น Array
		var anim_names = anim_sprite.sprite_frames.get_animation_names()
		
		if anim_names.size() > 0:
			# สุ่มเลือกชื่อแอนิเมชันมา 1 ชื่อ
			var random_anim = anim_names[randi() % anim_names.size()]
			anim_sprite.play(random_anim)
		else:
			queue_free()
	else:
		# กันค้างกรณีไม่มี AnimatedSprite2D
		get_tree().create_timer(0.5).timeout.connect(queue_free)

func _on_animation_finished() -> void:
	# เล่นจบเฟรมสุดท้าย ลบตัวเองทิ้งทันที!
	queue_free()