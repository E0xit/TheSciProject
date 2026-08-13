extends EnemyBase

@onready var anim_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	super()
	direction = 1 if randf() > 0.5 else -1
	_update_sprite_direction()
	
	if anim_sprite:
		anim_sprite.play("running")

func _physics_process(delta: float) -> void:
	var old_dir = direction
	super(delta) # ให้เบสคลาสคิดฟิสิกส์และสลับ direction ถ้าชนกำแพง
	
	# ถ้าทิศทางเปลี่ยน (ชนกำแพงมา) ให้กลับด้านสไปร์ท
	if direction != old_dir:
		_update_sprite_direction()

func _update_sprite_direction() -> void:
	if anim_sprite:
		anim_sprite.flip_h = (direction == -1)