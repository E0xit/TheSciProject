extends EnemyBase

@export var projectile_scene: PackedScene
@export var shoot_interval: float = 2.0

func _ready() -> void:
	super()
	speed = 0.0 # ยืนนิ่งๆ เป็นป้อมยิง
	_setup_timer()

func _setup_timer() -> void:
	var timer = Timer.new()
	timer.wait_time = shoot_interval
	timer.autostart = true
	timer.timeout.connect(_shoot_dual)
	add_child(timer)

func _shoot_dual() -> void:
	if not projectile_scene:
		return
		
	# เสกกระสุนพุ่งไปขวา (1) และซ้าย (-1) พร้อมกัน!
	for dir in [1, -1]:
		var bullet = projectile_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		get_tree().current_scene.add_child(bullet)