extends CharacterBody2D

@export var zone_areas: Array[Area2D] = []

const SPEED = 700.0
const JUMP_VELOCITY = -2700.0

enum Floor {one, two, three, four}

# 🧭 ทิศทางวิ่งอัตโนมัติ (1 = วิ่งไปทางขวา, -1 = วิ่งไปทางซ้าย)
var auto_direction: int = 1

# 🦘 ตัวแปรสำหรับควบคุมระบบกระโดด (ปิดไว้ตามที่โบ๊ตซามะสั่งเจ้าค่ะ!)
var can_jump: bool = false

var current_zone: Area2D = null
var current_floor: Floor = Floor.one

# 🌍 ดึงค่าแรงโน้มถ่วงเริ่มต้นของโปรเจกต์มาใช้ (ค่า Default มักจะอยู่ที่ 980)
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta * 7
    if Input.is_action_just_pressed("up") and is_on_floor() and current_floor != Floor.one:
        velocity.y = JUMP_VELOCITY

    if auto_direction != 0:
        velocity.x = auto_direction * SPEED
    else:
        velocity.x = move_toward(velocity.x, 0, SPEED)

    if Input.is_action_just_pressed('left'):
        auto_direction = -1
    if Input.is_action_just_pressed('right'):
        auto_direction = 1
    move_and_slide()


func _on_floor_detector_area_entered(area: Area2D) -> void:
    if area in zone_areas:
		# 2. เช็กว่าไม่ใช่ Area เดิมที่ยืนอยู่ใช่ไหม? (ถ้าไม่เหมือนเดิม = คือโซนใหม่!)
        if area != current_zone:
            current_zone = area
            print("📍 ย้ายมาโซนใหม่แล้วเจ้าค่ะ! ชื่อ Node: ", current_zone.name)
            match current_zone.name:
                'Floor1':
                    current_floor = Floor.one
                'Floor2':
                    current_floor = Floor.two
                'Floor3':
                    current_floor = Floor.three
                'Floor4':
                    current_floor = Floor.four