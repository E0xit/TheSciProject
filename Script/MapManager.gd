extends Node2D

@export var ColFloor: Array[CollisionShape2D] = []
@export var player: CharacterBody2D

# ⏱️ ตัวแปรช่วยเช็กว่ากำลังอยู่ในช่วง "ทะลุพื้นลงข้างล่าง" อยู่หรือเปล่า
var is_dropping: bool = false

func _process(delta: float) -> void:
	# 1. เช็กว่ากดปุ่ม 'down' + ไม่อยู่ในระหว่างร่วง + ***ต้องไม่อยู่ใน Floor4***
	if Input.is_action_just_pressed("down") and not is_dropping and player.current_floor != player.Floor.four and player.is_on_floor():
		drop_down()
		return

	# 2. ถ้ากำลังอยู่ในช่วงร่วงลงล่าง ข้ามการอัปเดตฟิสิกส์ปกติไปก่อน
	if is_dropping:
		return

	# 3. ลูปเปิด/ปิด Collision ตามชั้นปกติ (ถ้าไม่ได้กดร่วง)
	var current_index: int = player.current_floor
	for i in range(ColFloor.size()):
		if ColFloor[i]:
			ColFloor[i].set_deferred("disabled", i != current_index)


# 🕳️ ฟังก์ชันสั่งให้ร่วงทะลุพื้นลงล่าง
func drop_down() -> void:
	var current_index: int = player.current_floor
	
	# ถ้ามีพื้นชั้นปัจจุบันอยู่ สั่ง Disable มันทันที!
	if current_index < ColFloor.size() and ColFloor[current_index]:
		is_dropping = true
		ColFloor[current_index].set_deferred("disabled", true)
		
		# ⏳ หน่วงเวลา 0.25 วินาที รอให้ตัวละครร่วงพ้นระดับพื้นเดิม
		await get_tree().create_timer(0.25).timeout
		is_dropping = false