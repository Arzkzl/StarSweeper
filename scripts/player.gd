# scripts/Player.gd
extends CharacterBody2D
# This is the player you control. Think of it as a small “black hole”.
# You move it with the keyboard, it pulls stars in, collects them for points,
# loses lives when meteors (debris) hit it, and it can shake the camera.

# --- CAMERA LINK (so we can shake the screen) ---
@export var camera_path: NodePath = ^"../GameCamera"      # A path to the Camera2D in the scene (set in the Inspector)
@onready var _cam_node: Camera2D = get_node_or_null(camera_path)  # We try to find that camera when the game starts

# --- BLACK HOLE LOOK & FEEL (glow that “breathes” and rotates slowly) ---
@export var glow_spin_deg_per_sec: float = 18.0           # How fast the glow turns (degrees per second)
@export var glow_pulse_scale: float = 0.12                # How much the glow grows/shrinks (e.g. 0.12 = +12%)
@export var glow_pulse_time: float = 0.7                  # How long one grow/shrink cycle lasts (in seconds)
@export var glow_pulse_alpha: float = 0.12                # How much brighter the glow gets at the peak

# --- GAMEPLAY SETTINGS ---
@export var speed: float = 220.0                          # How fast the player moves on the screen
@export var magnet_strength: float = 900.0                # How strongly stars are pulled toward the player
@export var lives: int = 3                                # How many lives you start with

# --- PATHS TO CHILD NODES (set in the Inspector) ---
@export var core_path: NodePath = ^"BH_Core"              # (Optional) a center sprite you might use later
@export var glow_path: NodePath = ^"BH_Glow"              # The outer glow circle sprite
@export var horizon_path: NodePath = ^"BH_Horizon"        # A ring around the glow (event horizon)
@export var burst_path: NodePath = ^"PickupBurst"         # Particle effect played when you collect a star

# We look up those child nodes once the scene is ready:
@onready var _glow: Sprite2D    = get_node_or_null(glow_path)         # The glow sprite (can be missing)
@onready var _horizon: Sprite2D = get_node_or_null(horizon_path)      # The ring sprite (can be missing)
@onready var _burst: GPUParticles2D = get_node_or_null(burst_path)    # The particle effect (can be missing)

var score: int = 0                                        # Your current points
var _shake_tw: Tween                                       # A helper we use for the fallback camera shake

func _ready() -> void:
	# This runs once when the player appears in the scene.

	# 1) Connect the “collector” area so we know when a star is inside our capture radius.
	if not $Collector.area_entered.is_connected(_on_collector_area_entered):
		$Collector.area_entered.connect(_on_collector_area_entered)

	# 2) Find the HUD (the text on screen) and show starting score and lives.
	var hud := get_node_or_null("../HUD")                  # We look for a HUD next to the Player
	if hud:
		if hud.has_method("set_score"):
			hud.call_deferred("set_score", score)          # Use deferred (safe) to avoid timing issues
		if hud.has_method("set_lives"):
			hud.call_deferred("set_lives", lives)

	# 3) Make the glow gently “breathe” forever (grow a bit → shrink a bit).
	if _glow:
		var base_scale: Vector2 = _glow.scale              # Remember current size
		var base_color: Color = _glow.modulate             # Remember current color (includes transparency)
		var up_scale: Vector2 = base_scale * (1.0 + glow_pulse_scale)   # The bigger size at the top of the breath

		var up_color: Color = base_color                   # The brighter color at the top of the breath
		up_color.a = clampf(base_color.a + glow_pulse_alpha, 0.0, 1.0)   # Increase only the transparency safely

		# A “tween” smoothly changes properties over time.
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_loops()
		tw.tween_property(_glow, "scale",    up_scale,    glow_pulse_time)   # Grow and brighten
		tw.parallel().tween_property(_glow, "modulate",  up_color,           glow_pulse_time)
		tw.tween_property(_glow, "scale",    base_scale,  glow_pulse_time)   # Shrink and dim
		tw.parallel().tween_property(_glow, "modulate",  base_color,         glow_pulse_time)

	# 4) Do a similar, smaller breathing effect on the ring (horizon), shifted in time.
	if _horizon:
		var base_scale_h: Vector2 = _horizon.scale
		var base_color_h: Color = _horizon.modulate
		var up_scale_h: Vector2 = base_scale_h * (1.0 + glow_pulse_scale * 0.6)  # Smaller growth than the glow

		var up_color_h: Color = base_color_h
		up_color_h.a = clampf(base_color_h.a + glow_pulse_alpha * 0.7, 0.0, 1.0) # Smaller brightening

		var tw2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_loops()
		tw2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)       # Keep pulsing even when the game is paused (optional)
		tw2.tween_interval(glow_pulse_time * 0.5)           # Start half a cycle later than the glow
		tw2.tween_property(_horizon, "scale",   up_scale_h,   glow_pulse_time)
		tw2.parallel().tween_property(_horizon, "modulate", up_color_h,     glow_pulse_time)
		tw2.tween_property(_horizon, "scale",   base_scale_h, glow_pulse_time)
		tw2.parallel().tween_property(_horizon, "modulate", base_color_h,   glow_pulse_time)

func _physics_process(delta: float) -> void:
	# This runs many times per second. Here we move and pull stars.

	# 1) MOVEMENT: read the keyboard (arrow keys / WASD by default).
	# Godot gives us a direction vector: (1,0)=right, (-1,0)=left, (0,1)=down, etc.
	var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vec * speed    # Turn that direction into actual pixels per second
	move_and_slide()                # Apply movement while colliding properly with the world

	# 2) MAGNET: ask nearby stars to move toward us (they have an 'attract_to' function).
	for a in $Magnet.get_overlapping_areas():          # All Areas touching our Magnet Area2D
		if a.is_in_group("star"):                      # We only care about stars
			a.attract_to(global_position, magnet_strength, delta)  # Pull star toward us a little bit

	# 3) SMALL ROTATIONS: keep the visuals alive with a slow spin.
	if _glow:
		_glow.rotation_degrees += glow_spin_deg_per_sec * delta      # Glow rotates one way
	if _horizon:
		_horizon.rotation_degrees -= glow_spin_deg_per_sec * 0.6 * delta  # Horizon rotates the other way a bit slower

func _on_collector_area_entered(area: Area2D) -> void:
	# This happens when something enters the “Collector” (small circle around the player).
	if not area.is_in_group("star"):    # If it’s not a star, we ignore it.
		return

	var hit_pos: Vector2 = area.global_position  # Where we grabbed the star (for placing particles)
	area.collect()                               # Tell the star to remove itself

	# Play the “sparkle” particle at the pickup point:
	if _burst:
		_burst.global_position = hit_pos
		_burst.emitting = false
		_burst.restart()
		_burst.emitting = true

	# Increase the score and update the HUD text:
	score += 1
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_score"):
		hud.set_score(score)

func take_damage(amount: int) -> void:
	# Called when a meteor (debris) hits us.
	_shake_camera(10.0, 0.20)     # Give a small camera shake so the hit feels impactful (you can tune these numbers)

	lives -= amount               # Reduce our lives by the damage amount (here it’s usually 1)
	var hud := get_node_or_null("../HUD")
	if hud and hud.has_method("set_lives"):
		hud.set_lives(lives)      # Show the new lives number
	if lives <= 0:
		_game_over()              # If no lives remain, end the game

func _game_over() -> void:
	# 1) Save high score once (writes JSON if it is a new record)
	var is_new: bool = ScoreManager.try_set_high_score(score)

	# 2) Update the HUD text so the player can see the latest High
	var hud := get_node_or_null(^"../HUD")
	if hud and hud.has_method("set_high_score"):
		hud.set_high_score(ScoreManager.get_high_score())

	# (Optional) Log to Output to be sure it ran
	print("[Player] GAME OVER | score=", score, " | high=", ScoreManager.get_high_score(), " | new_record=", is_new)

	# 3) Pause and show the Game Over UI
	get_tree().paused = true
	if hud and hud.has_method("show_game_over"):
		hud.show_game_over()

# --------- CAMERA SHAKE HELPERS (use GameCamera if present; otherwise do a simple local shake) ---------

func _shake_camera(intensity: float = 6.0, duration: float = 0.15) -> void:
	# First, try the camera assigned in the Inspector.
	if _cam_node == null:
		_cam_node = get_node_or_null(camera_path)            # Try to find it by path again
		if _cam_node == null:
			_cam_node = get_viewport().get_camera_2d()       # Last resort: whichever camera is active now

	if _cam_node == null:
		print("[Player] no camera node (camera_path=", camera_path, ")")  # Helpful message if nothing was found
		return

	# If the camera has a “shake” function (from GameCamera.gd), use that:
	if _cam_node.has_method("shake"):
		_cam_node.shake(intensity, duration)
		return

	# If not, do a basic shake ourselves by wiggling the camera’s offset:
	_shake_camera_local(_cam_node, intensity, duration)

func _shake_camera_local(cam: Camera2D, intensity: float, duration: float) -> void:
	# Stop any previous shake and reset the offset.
	if _shake_tw:
		_shake_tw.kill()
	cam.offset = Vector2.ZERO

	# Build a tiny animation (tween) that nudges the camera a few times and returns to center.
	var steps := 6                                              # How many quick nudges we do
	var dt: float = maxf(duration / float(steps), 0.001)        # Time for each nudge (avoid division by zero)
	_shake_tw = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	for i in steps:                                             # Repeat 'steps' times
		var ang: float = randf() * TAU                          # Pick a random angle (in radians)
		var vec: Vector2 = Vector2(cos(ang), sin(ang)) * intensity  # Turn it into a direction × strength
		_shake_tw.tween_property(cam, "offset", vec, dt)        # Move the camera to that offset

	_shake_tw.tween_property(cam, "offset", Vector2.ZERO, dt)  # Finally, return the camera to center
