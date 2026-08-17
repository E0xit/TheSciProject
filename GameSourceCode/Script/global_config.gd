# global_config.gd (Autoload: GlobalConfig)
extends Node

# --- ค่า Default ดั้งเดิม (ใช้สำหรับ Normal) ---
const DEFAULT_TARGET_SCORE: int = 67
const DEFAULT_INITIAL_SPAWN_INTERVAL: float = 3.5
const DEFAULT_MIN_SPAWN_INTERVAL: float = 1.0
const DEFAULT_INTERVAL_DECAY_RATE: float = 0.05
const DEFAULT_INITIAL_MAX_ENEMIES: int = 5
const DEFAULT_MAX_ENEMIES_CAP: int = 18
const DEFAULT_MAX_BURST_COUNT: int = 6
const DEFAULT_ENEMIES_INCREASE_STEP: int = 15
const DEFAULT_SCORE_FOR_MAX_BURST: int = 50

# ตัวแปรใช้งานจริง
var target_score: int
var initial_spawn_interval: float
var min_spawn_interval: float
var interval_decay_rate: float
var initial_max_enemies: int
var max_enemies_cap: int
var max_burst_count: int
var enemies_increase_step: int
var score_for_max_burst: int

func _ready() -> void:
	set_normal_mode() # เริ่มต้นเป็น Normal

# 🟢 Normal: คืนค่าเป็น Default เดิมทั้งหมด
func set_normal_mode() -> void:
	target_score = DEFAULT_TARGET_SCORE
	initial_spawn_interval = DEFAULT_INITIAL_SPAWN_INTERVAL
	min_spawn_interval = DEFAULT_MIN_SPAWN_INTERVAL
	interval_decay_rate = DEFAULT_INTERVAL_DECAY_RATE
	initial_max_enemies = DEFAULT_INITIAL_MAX_ENEMIES
	max_enemies_cap = DEFAULT_MAX_ENEMIES_CAP
	max_burst_count = DEFAULT_MAX_BURST_COUNT
	enemies_increase_step = DEFAULT_ENEMIES_INCREASE_STEP
	score_for_max_burst = DEFAULT_SCORE_FOR_MAX_BURST

# 🔴 Hard: เข้าไปยุ่งและเขียนทับเฉพาะโหมดนี้!
func set_hard_mode() -> void:
	target_score = 125
	initial_spawn_interval = 1
	min_spawn_interval = 0.07
	interval_decay_rate = 0.05
	initial_max_enemies = 10
	max_enemies_cap = 40
	max_burst_count = 10
	enemies_increase_step = 10
	score_for_max_burst = 80