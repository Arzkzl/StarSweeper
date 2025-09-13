# scripts/GameCamera.gd
extends Camera2D
# This is the main 2D camera. It can do a simple "screen shake" effect.
# Other nodes (like Player) will call `shake(intensity, duration)` to trigger it.

@export var default_intensity: float = 6.0      # How strong the shake is (pixels of offset) if no value is passed in.
@export var default_duration:  float = 0.15     # How long the shake lasts (seconds) if no value is passed in.
@export var smoothing_off:     bool  = true     # We usually disable position smoothing so tiny shakes are visible.

var _time_left: float = 0.0                     # How many seconds are left in the current shake.
var _duration:  float = 0.0                     # Total duration for the current shake.
var _intensity: float = 0.0                     # Current shake strength (pixels).

func _ready() -> void:
	make_current()                               # Make this the active camera.
	add_to_group("game_camera")                  # So others can find us by group and call `shake(...)`.
	position_smoothing_enabled = not smoothing_off  # Turn smoothing off for crisp shakes.
	offset = Vector2.ZERO                        # Start with no offset (no shake).
	# print("[GameCamera] ready")                # (Optional) Debug log.

func shake(intensity: float = -1.0, duration: float = -1.0) -> void:
	# Public API: call this to start a shake.
	# If caller doesn't pass values, use the defaults above.
	if intensity <= 0.0:
		intensity = default_intensity            # Fallback to default intensity.
	if duration <= 0.0:
		duration = default_duration              # Fallback to default duration.

	# If a shake is already running, keep the STRONGER/longer one.
	_intensity = max(_intensity, intensity)      # Don’t reduce an ongoing stronger shake.
	_duration  = max(_duration,  duration)       # Keep the longer duration.
	_time_left = _duration                       # Reset remaining time to the chosen duration.

func _process(delta: float) -> void:
	# Runs every frame; we compute a small random offset while shaking.
	if _time_left > 0.0:
		_time_left -= delta                      # Count down the remaining time.

		# Compute progress t in [0..1] (1 = just started, 0 = about to end).
		var t: float = clampf(_time_left / _duration, 0.0, 1.0)

		# Ease-out falloff: stronger at the start, softer near the end.
		var falloff: float = t * t               # Quadratic falloff feels nice.

		# Random 2D direction (unit length). Rarely could be zero; guard just in case.
		var dir := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT                  # Fallback direction (extremely unlikely).

		# Final per-frame camera offset = random direction × intensity × falloff.
		offset = dir * (_intensity * falloff)
	else:
		# No shake → reset offset to zero so the image is perfectly still.
		offset = Vector2.ZERO
