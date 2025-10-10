# scripts/Game.gd
extends Node2D

# --- Tunable settings (edit in Inspector) ---
@export var spawn_rate_per_sec: float = 1.2      # enemies per second (overall tempo)
@export var enemy_speed: float = 120.0           # base speed for stars/debris
@export var max_enemies_on_screen: int = 15      # hard cap on-screen

# --- Scenes ---
@export var debris_ufo_scene: PackedScene
@onready var star_scene:   PackedScene = preload("res://scenes/star.tscn")
@onready var debris_scene: PackedScene = preload("res://scenes/debris.tscn")

# --- UI / timers ---
@export var level_label_path: NodePath = ^"../HUD/LevelLabel"
@onready var star_timer:  Timer = $StarTimer
@onready var debris_timer: Timer = $DebrisTimer

# --- Menu music (AudioStreamPlayer under MenuLayer) ---
@onready var _menu_music: AudioStreamPlayer = $"MenuLayer/MenuMusic"

# --- Optional background video path (kept if you use it) ---
const VIDEO_PATH := "res://assets/bg_video/star_burst_2.ogv"

# --- Level-by-score ---
const LEVELS_MAX: int = 10
const SCORE_PER_LEVEL: int = 25

var _current_level: int = 1
var _base_star_wait: float = 0.8
var _base_debris_wait: float = 1.2
var _enemy_count: int = 0
var _max_enemies_base: int = 15

# ---------------- Menu music helpers ----------------
func _menu_music_play() -> void:
	if _menu_music and not _menu_music.playing:
		_menu_music.play()

func _menu_music_stop() -> void:
	if _menu_music and _menu_music.playing:
		_menu_music.stop()

# ---------------- Lifecycle ----------------
func _ready() -> void:
	add_to_group("game_root")

	# Background video (optional)
	var v := get_node_or_null("VideoLayer/VideoRoot/VideoBG")
	if v:
		v.stream = preload(VIDEO_PATH)
		v.autoplay = true
		v.loop = true
		v.visible = true
		v.play()

	# Connect timers
	if star_timer and not star_timer.timeout.is_connected(_spawn_star):
		star_timer.timeout.connect(_spawn_star)
	if debris_timer and not debris_timer.timeout.is_connected(_spawn_debris):
		debris_timer.timeout.connect(_spawn_debris)

	# Baselines from local settings
	_max_enemies_base = max(1, max_enemies_on_screen)

	var rate: float = max(0.001, spawn_rate_per_sec) # enemies/sec
	_base_star_wait = 1.0 / rate

	if debris_timer and debris_timer.wait_time > 0.0:
		_base_debris_wait = debris_timer.wait_time
	else:
		_base_debris_wait = 0.8

	# Apply settings and start timers
	_apply_level_settings()
	if star_timer and star_timer.is_stopped(): star_timer.start()
	if debris_timer and debris_timer.is_stopped(): debris_timer.start()

	# HUD init
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_high_score"):
		hud.set_high_score(ScoreManager.get_high_score())
	_update_level_label()

	# Hook Player "game_overed" (if you added that signal)
	var p := get_node_or_null("Player")
	if p and p.has_signal("game_overed") and not p.game_overed.is_connected(_on_player_game_over):
		p.game_overed.connect(_on_player_game_over)

	# Main Menu on startup
	if has_node("MenuLayer"):
		$MenuLayer.visible = true
	_menu_set_title("Star Sweeper")
	_menu_music_play()
	get_tree().paused = true

func _process(_delta: float) -> void:
	# Read score
	var score_now: int = 0
	var sm := get_node_or_null("/root/ScoreManager")
	if sm and sm.has_method("get_score"):
		score_now = int(sm.get_score())

	# Update HUD score
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_score"):
		hud.set_score(score_now)

	# Level up every 25 points, never go down
	var level_steps: int = int(floor(score_now / float(SCORE_PER_LEVEL)))
	var target_level: int = max(_current_level, clampi(1 + level_steps, 1, LEVELS_MAX))
	if target_level != _current_level:
		_current_level = target_level
		_apply_level_settings()
		_update_level_label()

# ---------------- Spawning ----------------
func _spawn_star() -> void:
	if _enemy_count >= _current_max_enemies():
		return

	var s: Node2D = star_scene.instantiate()
	add_child(s)
	_enemy_count += 1
	s.tree_exited.connect(_on_enemy_exited_tree)

	# Auto-despawn after 10s (child Timer, no lambdas)
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 10.0
	s.add_child(t)
	t.timeout.connect(Callable(s, "queue_free"))
	t.start()

	s.global_position = _random_edge_position()

	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if s.has_method("nudge_towards"):
		s.nudge_towards(center, enemy_speed)

func _spawn_debris() -> void:
	if _enemy_count >= _current_max_enemies():
		return

	# 50% UFO after level 3
	var use_ufo: bool = false
	if _current_level >= 3 and randf() < 0.5:
		use_ufo = true

	var scene_to_use: PackedScene = debris_scene
	if use_ufo and debris_ufo_scene != null:
		scene_to_use = debris_ufo_scene

	var d = scene_to_use.instantiate()

	# set speed if property/method exists
	var spd := enemy_speed
	if d.has_method("set_base_speed"):
		d.set_base_speed(spd)
	elif d.get("base_speed") != null:
		d.set("base_speed", spd)
	elif d.get("speed") != null:
		d.set("speed", spd)
	elif d.get("enemy_speed") != null:
		d.set("enemy_speed", spd)

	add_child(d)
	_enemy_count += 1
	d.tree_exited.connect(_on_enemy_exited_tree)

	# Auto-despawn after 12s
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 12.0
	d.add_child(t)
	t.timeout.connect(Callable(d, "queue_free"))
	t.start()

	d.global_position = _random_edge_position()
	if has_node("Player") and d.has_method("launch_towards"):
		d.launch_towards($Player.global_position)

# ------------- Menu / Pause / GameOver -------------
func _start_game_from_menu() -> void:
	# close menu and unpause
	if has_node("MenuLayer"):
		$MenuLayer.visible = false
	_menu_music_stop()
	get_tree().paused = false

	# hide "GAME OVER" on HUD (if present)
	var hud := get_node_or_null("../HUD")
	if hud:
		var gol := hud.get_node_or_null("GameOverLabel")
		if gol: gol.visible = false

	# optional reset hook
	if has_method("_reset_game"):
		call("_reset_game")

func show_main_menu_from_game_over() -> void:
	# open menu on game over
	if has_node("MenuLayer"):
		$MenuLayer.visible = true
	_menu_set_title("GAME OVER")
	_menu_music_play()
	get_tree().paused = true

# called when Player emits "game_overed"
func _on_player_game_over() -> void:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = 1.0
	t.process_mode = Node.PROCESS_MODE_ALWAYS  # works while paused
	add_child(t)
	t.timeout.connect(Callable(self, "_open_main_menu_after_game_over"))
	t.start()
	if has_node("GameOverMusic"):
		$GameOverMusic.play()
func _open_main_menu_after_game_over() -> void:
	show_main_menu_from_game_over()

# Pause / Resume (ESC)
func _toggle_pause_menu(open: bool) -> void:
	if open:
		_menu_set_title("Paused")
		_menu_music_play()
	else:
		_menu_set_title("Star Sweeper")
		_menu_music_stop()

	if has_node("MenuLayer"):
		$MenuLayer.visible = open
	get_tree().paused = open

func _menu_set_title(t: String) -> void:
	var n := get_node_or_null("MenuLayer/MainMenu/VBoxContainer/TitleLabel")
	if n and n is Label:
		(n as Label).text = t
	# If you converted title to an image (TextureRect), this will simply do nothing.

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC
		var open: bool = false
		if has_node("MenuLayer"):
			open = $MenuLayer.visible
		_toggle_pause_menu(not open)

# Signals (Start / Quit / Resume)
func _on_start_button_pressed() -> void:
	_start_game_from_menu()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

func _on_resume_button_pressed() -> void:
	_toggle_pause_menu(false)

# ---------------- Helpers ----------------
func _apply_level_settings() -> void:
	# each level → 10% faster spawn (lower wait times)
	var level_index: int = _current_level - 1
	var speed_mult: float = pow(0.90, level_index)

	if star_timer:
		star_timer.wait_time = clamp(_base_star_wait * speed_mult, 0.10, 5.0)
	if debris_timer:
		debris_timer.wait_time = clamp(_base_debris_wait * speed_mult, 0.15, 6.0)

func _current_max_enemies() -> int:
	return min(_max_enemies_base + (_current_level - 1) * 2, 99)

func _update_level_label() -> void:
	var lbl := _get_level_label()
	if lbl:
		lbl.text = "Level: %d" % _current_level

func _get_level_label() -> Label:
	if level_label_path != NodePath("") and has_node(level_label_path):
		var n := get_node(level_label_path)
		if n is Label:
			return n
	if has_node("HUD/LevelLabel") and $"HUD/LevelLabel" is Label:
		return $"HUD/LevelLabel"
	return null

func _random_edge_position() -> Vector2:
	var rect := get_viewport().get_visible_rect()
	var side := randi() % 4
	if side == 0:
		return Vector2(randf() * rect.size.x, -10.0)                  # top
	elif side == 1:
		return Vector2(rect.size.x + 10.0, randf() * rect.size.y)     # right
	elif side == 2:
		return Vector2(randf() * rect.size.x, rect.size.y + 10.0)     # bottom
	else:
		return Vector2(-10.0, randf() * rect.size.y)                  # left

func _on_enemy_exited_tree() -> void:
	_enemy_count = max(0, _enemy_count - 1)


func _on_player_game_overed() -> void:
	pass # Replace with function body.
