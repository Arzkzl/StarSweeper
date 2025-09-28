# scripts/Star.gd
extends Area2D
# This is a collectible “star”.
# It slowly drifts, gets pulled by the player's magnet, and disappears when collected.

@export var drag: float = 4.0                 # How quickly the star slows down (higher = stops faster)
@export var drift_speed: float = 0.0          # Initial drift speed (0 = no drift at spawn)
var _velocity: Vector2 = Vector2.ZERO         # The star’s current movement direction and speed

func _ready() -> void:
	add_to_group("star")                       # Put this node in the "star" group (easy to find/filter)
	# Pick a random direction on spawn; if drift_speed is 0, this has no visible effect.
	var dir := Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()  # Random unit vector
	_velocity = dir * drift_speed              # Set initial velocity = direction × speed

func _physics_process(delta: float) -> void:
	# delta = time (in seconds) since the last physics frame. Use it for smooth motion.
	# Gradually slow the velocity toward zero by "drag" each frame:
	_velocity = _velocity.move_toward(Vector2.ZERO, drag * delta)
	# Move the star according to its current velocity:
	global_position += _velocity * delta

# Called by the Player’s magnet each frame while the star is inside the magnet Area2D.
func attract_to(target: Vector2, strength: float, delta: float) -> void:
	var to_target := target - global_position   # Vector pointing from star to the target (player)
	var accel := to_target.normalized() * strength * delta  # Acceleration toward the target this frame
	_velocity = (_velocity + accel).limit_length(300.0)     # Add accel, but clamp max speed to 300 px/s

# Give the star a small push toward a point when it spawns (nice “inward drift” effect).
func nudge_towards(point: Vector2, speed: float = 60.0) -> void:
	var dir := (point - global_position).normalized()  # Direction toward the point
	_velocity = dir * speed                            # Set velocity instantly to that direction/speed

# When collected by the Player’s collector Area2D, remove this star from the scene.
# When collected by the Player’s collector Area2D, remove this star from the scene.
func collect() -> void:
	# add +1 to current score (ScoreManager must be Autoload)
	ScoreManager.add_score(1)
	queue_free()  # delete at end of frame                                  # Delete this node safely at the end of the frame
