# scripts/HUD.gd
extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var lives_label: Label = $LivesLabel
@onready var game_over_label: Label = $GameOverLabel
@onready var high_label: Label = get_node_or_null(^"HighScoreLabel")  # optional

func _ready() -> void:
	# show saved high score at start (if the node exists)
	if high_label:
		high_label.text = "Highest Score: %d" % ScoreManager.get_high_score()

	# hide "GAME OVER" by default
	if is_instance_valid(game_over_label):
		game_over_label.visible = false

# --- public API used by Game/Player ---

func set_score(value: int) -> void:
	if is_instance_valid(score_label):
		score_label.text = "Score: %d" % value

func set_lives(value: int) -> void:
	if is_instance_valid(lives_label):
		lives_label.text = "Lives: %d" % value

func set_high_score(v: int) -> void:
	if high_label:
		high_label.text = "Highest Score: %d" % v

func show_game_over() -> void:
	# show only the label; restart happens via Main Menu
	if is_instance_valid(game_over_label):
		game_over_label.visible = true

func hide_game_over() -> void:
	if is_instance_valid(game_over_label):
		game_over_label.visible = false
