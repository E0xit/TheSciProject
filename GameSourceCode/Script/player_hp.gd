class_name HeartUI extends Sprite2D

# 💡 ตารางแปลงค่า (Lookup Table) 
# [Index 0 = เลือด 0, Index 1 = เลือด 1, Index 2 = เลือด 2, Index 3 = เลือด 3 (เต็ม)]
const HP_FRAME_MAP: Array[int] = [4, 2, 3, 0]

func _ready() -> void:
	# ค้นหา Player ในฉากเพื่อเชื่อม Signal health_changed
	var player = get_tree().get_first_node_in_group("player_body")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		# ดึง HP ปัจจุบันมาแสดงผลตอนเริ่มเกมทันที
		if "current_health" in player:
			update_heart_display(player.current_health)

func _on_player_health_changed(current_hp: int, _max_hp: int) -> void:
	update_heart_display(current_hp)

func update_heart_display(hp: int) -> void:
	# คุมให้อยู่ในช่วง 0 - 3 ป้องกัน Index Out of Bounds
	var clamped_hp = clamp(hp, 0, 3)
	
	# ดึง Frame ID ตามตารางที่เราแมปไว้มาเปลี่ยนให้ Sprite2D
	frame = HP_FRAME_MAP[clamped_hp]
