# scripts/Star.gd
extends Area2D
# A collectible “star”. It drifts a bit, is pulled by the player's magnet,
# and disappears (adds score) when collected.

@export var drag: float = 4.0          # higher = slows faster
@export var drift_speed: float = 0.0   # initial drift speed (0 = no drift)

var _velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# make sure we are in the "star" group (Player checks this)
	if not is_in_group("star"):
		add_to_group("star")

	# random initial direction (has effect only if drift_speed > 0)
	var dir := Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
	_velocity = dir * drift_speed

func _physics_process(delta: float) -> void:
	# simple drag and move
	_velocity = _velocity.move_toward(Vector2.ZERO, drag * delta)
	global_position += _velocity * delta

# called by Player magnet
func attract_to(target: Vector2, strength: float, delta: float) -> void:
	var to_target := target - global_position
	var accel := to_target.normalized() * strength * delta
	_velocity = (_velocity + accel).limit_length(300.0)

# small kick on spawn
func nudge_towards(point: Vector2, speed: float = 60.0) -> void:
	var dir := (point - global_position).normalized()
	_velocity = dir * speed

# when collected
func collect() -> void:
	ScoreManager.add_score(1)  # single source of truth
	queue_free()
