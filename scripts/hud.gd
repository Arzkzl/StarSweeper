# scripts/HUD.gd
extends CanvasLayer                                # HUD layer that stays on top of the gameplay (shows score/lives/game over)

@onready var score_label: Label = $ScoreLabel      # Reference to the Label that displays the score
@onready var lives_label: Label = $LivesLabel      # Reference to the Label that displays remaining lives
@onready var game_over_label: Label = $GameOverLabel  # Reference to the big "GAME OVER" Label (usually hidden until needed)
@onready var restart_button: Button = $RestartButton  # Reference to the Restart button (if your node name has a space: $"Restart Button")
@onready var high_label: Label = get_node_or_null(^"HighScoreLabel")

func set_score(value: int) -> void:
	score_label.text = "Score: %d" % value         # Update the score text (e.g., "Score: 12")

func set_lives(value: int) -> void:
	lives_label.text = "Lives: %d" % value         # Update the lives text (e.g., "Lives: 3")

func show_game_over() -> void:
	game_over_label.visible = true                 # Show the "GAME OVER" message
	restart_button.visible = true                  # Show the Restart button so the player can restart

func _on_restart_button_pressed() -> void:
	get_tree().paused = false                      # Ensure the game is unpaused (so input/UI works)
	get_tree().reload_current_scene()              # Reload the current scene to restart the game
	
func set_high_score(v: int) -> void:
	if high_label: high_label.text = "Highest Score: %d" % v
func _ready() -> void:
	# Show saved high score when game starts.
	if high_label:
		high_label.text = "Highest Score: %d" % ScoreManager.get_high_score()
