# ScoreManager.gd 
extends Node

const SAVE_PATH: String = "user://high_score.json"

var score: int = 0
var high_score: int = 0

func _ready() -> void:
	_load_high_score()

# --- current score ---
func get_score() -> int:
	return score

func add_score(amount: int) -> void:
	score += amount
	try_set_high_score(score)

func reset_score() -> void:
	score = 0

# --- high score ---
func get_high_score() -> int:
	return high_score

func try_set_high_score(value: int) -> bool:
	if value > high_score:
		high_score = value
		_save_high_score()
		return true
	return false

# --- save / load ---
func _save_high_score() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"high_score": high_score}))
		f.close()

func _load_high_score() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		high_score = 0
		return

	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var text: String = f.get_as_text()
		f.close()

		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			var dict: Dictionary = parsed as Dictionary
			if dict.has("high_score"):
				high_score = int(dict["high_score"])
		else:
			high_score = 0
