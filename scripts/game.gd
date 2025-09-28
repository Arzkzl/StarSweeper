# scripts/Game.gd
extends Node2D

@onready var _video: VideoStreamPlayer = $VideoLayer/VideoRoot/VideoBG
@onready var level_config: LevelConfig = preload("res://levels/Level1.tres")

@export var autoplay_bg_video: bool = false
@export var difficulty_ramp_time: float = 60.0  # kept for get_difficulty_t()
@export var level_label_path: NodePath = ^"../HUD/LevelLabel"  # set in Inspector if needed

var _elapsed: float = 0.0

@onready var star_timer:  Timer = $StarTimer
@onready var debris_timer: Timer = $DebrisTimer

@onready var star_scene:   PackedScene = preload("res://scenes/star.tscn")
@onready var debris_scene: PackedScene = preload("res://scenes/debris.tscn")

const VIDEO_PATH := "res://assets/bg_video/star_burst_2.ogv"

# -------- Level-by-score settings --------
const LEVELS_MAX: int = 10
const SCORE_PER_LEVEL: int = 25

var _current_level: int = 1
var _base_star_wait: float = 0.8      # set from LevelConfig in _ready()
var _base_debris_wait: float = 1.2    # set from timer or default

# Active enemies (stars + debris)
var _enemy_count: int = 0
var _max_enemies_base: int = 10       # set from LevelConfig

func _ready() -> void:
	add_to_group("game_root")

	# --- Background video (optional) ---
	if is_instance_valid(_video):
		_video.stream = preload(VIDEO_PATH)
		_video.expand = true
		_video.autoplay = false
		_video.loop = true
		_video.paused = false
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_video.visible = false
		_video.play()
		_video.visible = true
		_video.play()

	# --- Connect timers ---
	if star_timer and not star_timer.timeout.is_connected(_spawn_star):
		star_timer.timeout.connect(_spawn_star)
	if debris_timer and not debris_timer.timeout.is_connected(_spawn_debris):
		debris_timer.timeout.connect(_spawn_debris)

	# --- Baselines from LevelConfig / scene ---
	_max_enemies_base = max(1, level_config.max_enemies_on_screen)

	var rate: float = max(0.001, level_config.spawn_rate_per_sec) # enemies/sec
	_base_star_wait = 1.0 / rate

	if debris_timer and debris_timer.wait_time > 0.0:
		_base_debris_wait = debris_timer.wait_time
	else:
		_base_debris_wait = 1.2

	# Apply level 1 settings and start timers
	_apply_level_settings()
	if star_timer and star_timer.is_stopped(): star_timer.start()
	if debris_timer and debris_timer.is_stopped(): debris_timer.start()

	# HUD init (high score optional)
	if has_node("../HUD"):
		$"../HUD".set_high_score(ScoreManager.get_high_score())

	_update_level_label()

func _process(delta: float) -> void:
	_elapsed += delta

	# --- Read score safely from Autoload (/root/ScoreManager) ---
	var score_now: int = 0
	var sm := get_node_or_null("/root/ScoreManager")
	if sm and sm.has_method("get_score"):
		score_now = int(sm.get_score())

	# --- Update HUD score (only if HUD exists and has method) ---
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_score"):
		hud.set_score(score_now)

	# --- Level up every 25 points (capped at 10) ---
	var level_steps: int = int(floor(score_now / float(SCORE_PER_LEVEL)))
	var target_level: int = clampi(1 + level_steps, 1, LEVELS_MAX)

	if target_level != _current_level:
		_current_level = target_level
		_apply_level_settings()
		_update_level_label()

# -------- Spawning --------
func _spawn_star() -> void:
	if _enemy_count >= _current_max_enemies():
		return

	var s: Node2D = star_scene.instantiate()
	add_child(s)
	_enemy_count += 1
	s.tree_exited.connect(_on_enemy_exited_tree)

	# Auto-despawn (prevent hard lock if nothing frees them)
	get_tree().create_timer(10.0).timeout.connect(func():
		if is_instance_valid(s):
			s.queue_free()
	)

	var p: Vector2 = _random_edge_position()
	s.global_position = p

	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if s.has_method("nudge_towards"):
		s.nudge_towards(center, level_config.enemy_speed)

func _spawn_debris() -> void:
	if _enemy_count >= _current_max_enemies():
		return

	var d = debris_scene.instantiate()
	d.base_speed = level_config.enemy_speed
	add_child(d)
	_enemy_count += 1
	d.tree_exited.connect(_on_enemy_exited_tree)

	# Auto-despawn
	get_tree().create_timer(12.0).timeout.connect(func():
		if is_instance_valid(d):
			d.queue_free()
	)

	var p := _random_edge_position()
	d.global_position = p

	if has_node("Player") and d.has_method("launch_towards"):
		d.launch_towards($Player.global_position)

# -------- Helpers --------
func _apply_level_settings() -> void:
	# +2 max enemies per level; 10% faster timers per level.
	var level_index: int = _current_level - 1
	var speed_mult: float = pow(0.90, level_index) # smaller wait_time each level

	if star_timer:
		star_timer.wait_time = clamp(_base_star_wait * speed_mult, 0.10, 5.0)
	if debris_timer:
		debris_timer.wait_time = clamp(_base_debris_wait * speed_mult, 0.15, 6.0)

func _current_max_enemies() -> int:
	return min(_max_enemies_base + (_current_level - 1) * 2, 99)

func _update_level_label() -> void:
	var lbl := _get_level_label()
	if lbl:
		lbl.text = "Level %d" % _current_level

func _get_level_label() -> Label:
	# 1) Exported path (Inspector’da ayarlanabilir)
	if level_label_path != NodePath("") and has_node(level_label_path):
		var n := get_node(level_label_path)
		if n is Label: return n
	# 2) Yaygın yollar
	if has_node("../HUD/LevelLabel") and $"../HUD/LevelLabel" is Label:
		return $"../HUD/LevelLabel"
	if has_node("HUD/LevelLabel") and $"HUD/LevelLabel" is Label:
		return $"HUD/LevelLabel"
	# 3) Grup fallback (Label’ı “level_label” grubuna ekleyebilirsin)
	var nodes := get_tree().get_nodes_in_group("level_label")
	if nodes.size() > 0 and nodes[0] is Label:
		return nodes[0]
	return null

func _random_edge_position() -> Vector2:
	var rect := get_viewport().get_visible_rect()
	var side := randi() % 4
	if side == 0:
		return Vector2(randf() * rect.size.x, -10.0)
	elif side == 1:
		return Vector2(rect.size.x + 10.0, randf() * rect.size.y)
	elif side == 2:
		return Vector2(randf() * rect.size.x, rect.size.y + 10.0)
	else:
		return Vector2(-10.0, randf() * rect.size.y)

func _on_enemy_exited_tree() -> void:
	_enemy_count = max(0, _enemy_count - 1)

func get_difficulty_t() -> float:
	return clampf(_elapsed / difficulty_ramp_time, 0.0, 1.0)
