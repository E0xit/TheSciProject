extends EnemyBase

func _ready() -> void:
	super() 
	
	# สุ่มทิศทางตอนเกิด (1 หรือ -1)
	direction = 1 if randf() > 0.5 else -1
	
	if sprite:
		sprite.flip_h = (direction == -1)