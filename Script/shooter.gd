extends EnemyBase

@export var projectile_scene: PackedScene
@export var shoot_interval: float = 2.5
@export var charge_time: float = 0.6

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

var _is_charging: bool = false

func _ready() -> void:
	super()
	speed = 0.0
	_setup_timer()
	
	if anim_sprite:
		anim_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float) -> void:
	super(delta)
	if anim_sprite and not _is_charging and anim_sprite.animation != "shooting":
		_play_animation("idle")

func _setup_timer() -> void:
	var timer = Timer.new()
	timer.wait_time = shoot_interval
	timer.autostart = true
	timer.timeout.connect(_start_charge_sequence)
	add_child(timer)

func _start_charge_sequence() -> void:
	if not projectile_scene or _is_charging:
		return
		
	_is_charging = true
	_play_animation("charge")
	
	await get_tree().create_timer(charge_time).timeout
	_shoot_dual()

func _shoot_dual() -> void:
	_is_charging = false
	_play_animation("shooting")
	
	for dir in [1, -1]:
		var bullet = projectile_scene.instantiate()
		bullet.global_position = global_position
		bullet.direction = dir
		get_tree().current_scene.add_child(bullet)

func _on_animation_finished() -> void:
	if anim_sprite and anim_sprite.animation == "shooting":
		_play_animation("idle")

func _play_animation(anim_name: String) -> void:
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)