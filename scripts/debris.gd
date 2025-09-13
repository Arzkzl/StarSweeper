# scripts/debris.gd
extends Area2D
# Think of this as a small rock (a meteor) in space.
# It flies toward the player, spins a little, and if it touches the player,
# it hurts the player and then disappears.

@export var base_speed: float = 180.0
# How fast the rock moves (pixels per second) when the game is at the easiest level.

@export var max_speed_bonus: float = 0.20
# When the game gets harder, we add up to +20% more speed.
# Example: with 0.20, speed can become 1.20 × base_speed at max difficulty.

@export var spin_deg_per_sec: float = 120.0
# How fast the rock spins (degrees per second). This is only for visuals.

@export var randomize_spin_dir: bool = true
# If true, the rock randomly spins clockwise or counter-clockwise.

var _dir: Vector2 = Vector2.ZERO
# The direction the rock will move in.
# Example: (1, 0) means “to the right”, (-1, 0) means “to the left”.

var _spin_sign: float = 1.0
# +1 means spin one way, -1 means spin the other way.

var _game: Node = null
# We will try to remember the Game node here.
# The Game node can tell us how hard the game is (0.0 to 1.0).

func _ready() -> void:
	# This runs once when the rock appears.
	add_to_group("debris")
	# Put this rock in a group called "debris" (useful for finding or debugging).

	body_entered.connect(_on_body_entered)
	# When this rock overlaps (touches) a physics body (like the Player),
	# call the function _on_body_entered below.

	_game = get_tree().get_first_node_in_group("game_root")
	# Try to find the Game node (we expect the Game node to be in the "game_root" group).

	# Randomly choose spin direction (only if we want randomness).
	if randomize_spin_dir and randf() < 0.5:
		_spin_sign = -1.0

func launch_towards(point: Vector2) -> void:
	# This function sets the rock to move toward a specific point on the screen.
	# Usually, we call this with the player position when we spawn the rock.
	var to := point - global_position
	# "to" is the vector (arrow) from the rock to the target point.

	if to.length() > 0.0:
		_dir = to.normalized()
		# Make the arrow length 1 (unit vector) so speed is controlled only by base_speed.
	else:
		_dir = Vector2.ZERO
		# If we are exactly on the point, don’t move.

func _physics_process(delta: float) -> void:
	# This runs every physics frame (many times per second).
	# We will move the rock and spin it a little.

	# 1) Work out how hard the game is (0.0 = easy, 1.0 = hard).
	var t: float = 0.0
	if _game and _game.has_method("get_difficulty_t"):
		# If the Game node exists and it has get_difficulty_t(), use it.
		t = clampf(_game.get_difficulty_t(), 0.0, 1.0)

	# 2) Turn the difficulty into a speed multiplier.
	# At easy: 1.0. At hard: 1.0 + max_speed_bonus (e.g., 1.20).
	var mult: float = 1.0 + max_speed_bonus * t

	# 3) Move forward in the chosen direction.
	var pixels_per_second := base_speed * mult
	global_position += _dir * pixels_per_second * delta
	# delta is “time since last frame”, so movement is smooth on any computer.

	# 4) Spin for a nice visual effect.
	rotation_degrees += _spin_sign * spin_deg_per_sec * delta

func _on_body_entered(body: Node) -> void:
	# This runs when the rock touches another physics body.
	# If that body has a function called take_damage, we call it with 1.
	if body and body.has_method("take_damage"):
		body.take_damage(1)

	# After hitting something, delete this rock so it doesn’t keep colliding.
	queue_free()
