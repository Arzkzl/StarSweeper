# ScoreManager.gd
# Project Settings → Autoload → Name: ScoreManager, Path: this file

extends Node

const SAVE_PATH: String = "user://save.json"

var data: Dictionary = {
	"high_score": 0,
	"options": {
		"sfx_on": true,
		"low_fx": false
	}
}

# ------- CURRENT SCORE (for gameplay / leveling) -------
var score: int = 0

func _ready() -> void:
	load_data()

# ---------- Score (current) ----------
func get_score() -> int:
	return score

func add_score(amount: int) -> void:
	score += amount
	try_set_high_score(score)

func reset_score() -> void:
	score = 0

# ---------- High score ----------
func get_high_score() -> int:
	return int(data.get("high_score", 0))

func try_set_high_score(score_value: int) -> bool:
	if score_value > get_high_score():
		data["high_score"] = score_value
		save_data()
		return true
	return false

# ---------- Options ----------
func set_option(key: String, value: bool) -> void:
	var opts: Dictionary = data.get("options", {})
	opts[key] = value
	data["options"] = opts
	save_data()

func get_option(key: String, default_value: bool = false) -> bool:
	var opts: Dictionary = data.get("options", {})
	return bool(opts.get(key, default_value))

# ---------- Save / Load ----------
func save_data() -> void:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("ScoreManager: cannot open save file for writing.")
		return
	var json_text: String = JSON.stringify(data, "\t")
	f.store_string(json_text)
	f.flush()
	f.close()
	print("[ScoreManager] saved to ", SAVE_PATH, " | high=", data.get("high_score", 0))

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("ScoreManager: cannot open save file for reading.")
		return
	var text: String = f.get_as_text()
	f.close()
	var value: Variant = JSON.parse_string(text)
	if value is Dictionary:
		data = value as Dictionary
	else:
		push_warning("ScoreManager: invalid JSON; using defaults.")

# ---------- Reset all ----------
func reset_data() -> void:
	data = {
		"high_score": 0,
		"options": {
			"sfx_on": true,
			"low_fx": false
		}
	}
	save_data()
	reset_score()
