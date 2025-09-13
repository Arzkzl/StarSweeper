# scripts/Game.gd
extends Node2D                                       
# Root node that coordinates spawning, difficulty and (optionally) background video.
@onready var _video: VideoStreamPlayer =  get_node_or_null(^"VideoLayer/VideoRoot/VideoBG")           
# Try to find the background VideoStreamPlayer in the scene (can be null).	

@export var autoplay_bg_video: bool = false          # If true, play the background video on start; if false, keep it paused (your current preference).

@export var star_spawn_max_wait: float = 1.6         # At the very beginning, stars spawn slowly (bigger wait time).
@export var star_spawn_min_wait: float = 0.6         # At max difficulty, stars spawn faster (smaller wait time).
@export var difficulty_ramp_time: float = 60.0       # How many seconds it takes to reach maximum difficulty (t = 1.0).

var _elapsed: float = 0.0                            # Counts how many seconds have passed since the scene started.

@onready var star_timer:  Timer = $StarTimer         # Timer node that triggers star spawns (must exist in the scene).
@onready var debris_timer: Timer = $DebrisTimer      # Timer node that triggers debris spawns (must exist in the scene).

@onready var star_scene:   PackedScene = preload("res://scenes/star.tscn")            # Star scene to instantiate for each spawn.
	
@onready var debris_scene: PackedScene = preload("res://scenes/debris.tscn")            # Debris scene to instantiate for each spawn.
	

func _ready() -> void:
	add_to_group("game_root")    # So other scripts (e.g., debris) can find this node and read difficulty via group.

	# background video control
	if _video:                                        # If the video node is found...
		_video.loop = false                           # We manage looping manually if needed (prevents visible stutter when it loops).
		if autoplay_bg_video:                         # Only play if you enabled it in the Inspector.
			_video.call_deferred("play")             # Defer play call until the node is fully inside the scene tree.
		_video.z_index = -100                        # Keep video behind everything.
	else:
		push_warning("[Video] Not found at VideoLayer/VideoRoot/VideoBG (this is OK if you don't use video).")

	#  Timer setup and signal connections
	if star_timer:
		if not star_timer.timeout.is_connected(_spawn_star):
			star_timer.timeout.connect(_spawn_star)  # Call _spawn_star every time the timer times out.
		star_timer.wait_time = star_spawn_max_wait    # Start with the slowest spawn rate (largest wait).
		if star_timer.is_stopped():
			star_timer.start()                       # Make sure the timer is running.

	if debris_timer:
		if not debris_timer.timeout.is_connected(_spawn_debris):
			debris_timer.timeout.connect(_spawn_debris)  # Call _spawn_debris on timeout.
		if debris_timer.is_stopped():
			debris_timer.start()                    # Start debris spawns.
	if has_node("../HUD"):
		$"../HUD".set_high_score(ScoreManager.get_high_score())


func _process(delta: float) -> void:
	_elapsed += delta                                 # Increase the elapsed time each frame.

	# Difficulty t goes from 0.0 → 1.0 across 'difficulty_ramp_time' seconds.
	var t: float = clampf(_elapsed / difficulty_ramp_time, 0.0, 1.0)

	# Make stars spawn faster as difficulty increases by shrinking the timer wait time.
	if star_timer:
		star_timer.wait_time = lerpf(star_spawn_max_wait, star_spawn_min_wait, t)

func _spawn_star() -> void:
	# 1) Create a star instance.
	var s: Node2D = star_scene.instantiate()
	add_child(s)                                      # Add it to the scene so it becomes active.

	# 2) Place it at a random position just outside the screen edges.
	var p: Vector2 = _random_edge_position()
	s.global_position = p

	# 3) Give it a tiny nudge toward the screen center so it drifts inward nicely.
	var center: Vector2 = get_viewport().get_visible_rect().size * 0.5
	if s.has_method("nudge_towards"):
		s.nudge_towards(center, 80.0)                 # 80 px/s initial push toward the center.

func _spawn_debris() -> void:
	# 1) Create a debris (meteor) instance.
	var d: Node2D = debris_scene.instantiate()
	add_child(d)                                      # Add it to the scene so it becomes active.

	# 2) Spawn from a random edge position.
	var p := _random_edge_position()
	d.global_position = p

	# 3) Aim it at the Player so it travels inward.
	if has_node("Player") and d.has_method("launch_towards"):
		d.launch_towards($Player.global_position)

func _random_edge_position() -> Vector2:
	# Returns a point slightly outside one of the four screen edges.
	var rect := get_viewport().get_visible_rect()     # The current visible rectangle (size depends on window).
	var side := randi() % 4                           # 0=top, 1=right, 2=bottom, 3=left

	if side == 0:                                     # Top edge
		return Vector2(randf() * rect.size.x, -10.0)
	elif side == 1:                                   # Right edge
		return Vector2(rect.size.x + 10.0, randf() * rect.size.y)
	elif side == 2:                                   # Bottom edge
		return Vector2(randf() * rect.size.x, rect.size.y + 10.0)
	else:                                             # Left edge
		return Vector2(-10.0, randf() * rect.size.y)

func get_difficulty_t() -> float:
	# Public helper: other nodes (like debris) can ask "how hard is the game right now?"
	# t = 0.0 at start, and smoothly grows to 1.0 by 'difficulty_ramp_time' seconds.
	return clampf(_elapsed / difficulty_ramp_time, 0.0, 1.0)
