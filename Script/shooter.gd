extends EnemyBase

@export var projectile_scene: PackedScene
@export var shoot_interval: float = 0.2 # เวลารอหลังยิงเสร็จ
@export var charge_time: float = 0.1    # เวลาเตือนชาร์จก่อนยิง

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_charging: bool = false

func _ready() -> void:
	super()
	speed = 0.0 # ยืนนิ่งๆ เป็นป้อมยิง
	
	# เล่นแอนิเมชัน idle ทันทีตอนเกิด
	_play_animation("idle")
	
	# เริ่มลูปการยิงอนุกรม (ทำทีละขั้นตอนอย่างเป็นระเบียบ)
	_start_shooting_loop()

func _physics_process(delta: float) -> void:
	# เรียกฟิสิกส์คลาสแม่แค่อย่างเดียว พอศัตรูนิ่งอยู่กับที่แล้ว ไม่ต้องไปสั่ง _play_animation ในนี้ทุกเฟรม!
	super(delta)

# 💡 ลูปการยิงแบบ Async คุมเวลาทีละ Step เป๊ะๆ ไม่มียิงรัวซ้ำซ้อนแน่นอน!
func _start_shooting_loop() -> void:
	while is_instance_valid(this_or_self()):
		# 1. พักรอตามเวลา shoot_interval (เช่น 3 วินาที)
		_is_charging = false
		_play_animation("idle")
		await get_tree().create_timer(shoot_interval).timeout
		
		if not is_instance_valid(self):
			break

		# 2. เริ่มชาร์จเตือนผู้เล่นตาม charge_time (เช่น 1 วินาที)
		if projectile_scene:
			_is_charging = true
			_play_animation("charge")
			await get_tree().create_timer(charge_time).timeout
			
			if not is_instance_valid(self):
				break

			# 3. ยิงกระสุนออก 2 ทาง
			_shoot_dual()

func _shoot_dual() -> void:
	if not projectile_scene:
		return
		
	for dir in [1, -1]:
		var bullet = projectile_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		get_tree().current_scene.add_child(bullet)

func _play_animation(anim_name: String) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name or not anim_sprite.is_playing():
			anim_sprite.play(anim_name)

# Helper กันงอแงเรื่อง self
func this_or_self() -> Object:
	return self