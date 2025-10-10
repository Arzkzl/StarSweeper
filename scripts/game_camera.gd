# scripts/GameCamera.gd 
extends Camera2D

@export var default_intensity: float = 6.0   # pixels of offset
@export var default_duration:  float = 0.15  # seconds
@export var disable_smoothing:  bool  = true # turn off position smoothing for crisp shake

var _time_left: float = 0.0
var _duration:  float = 0.0
var _intensity: float = 0.0

func _ready() -> void:
	make_current()                         # use this as the active camera
	add_to_group("game_camera")            # optional: easy to find from other nodes
	position_smoothing_enabled = not disable_smoothing
	offset = Vector2.ZERO

func shake(intensity: float = -1.0, duration: float = -1.0) -> void:
	# start (or restart) a simple screen shake
	if intensity <= 0.0:
		intensity = default_intensity
	if duration <= 0.0:
		duration = default_duration

	_intensity = intensity
	_duration  = duration
	_time_left = duration

func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		var t := clampf(_time_left / max(0.0001, _duration), 0.0, 1.0) # progress 1→0
		var falloff := t                                               # linear fade

		# random 2D unit direction
		var dir := Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT

		offset = dir * (_intensity * falloff)
	else:
		offset = Vector2.ZERO
