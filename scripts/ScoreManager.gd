# ScoreManager.gd
# Simple save/load system using JSON (Godot 4).
# Put this script in Project Settings → Autoload as "ScoreManager"
# so you can call: ScoreManager.get_high_score(), ScoreManager.try_set_high_score(...), etc.

extends Node

# ------------------------------------------------------------
# Where we store the save file.
# "user://" points to a writable folder created by Godot.
# The file name is up to you.
# ------------------------------------------------------------
const SAVE_PATH: String = "user://save.json"

# ------------------------------------------------------------
# The data we keep in the save file.
# You can add more keys later if you need.
# ------------------------------------------------------------
var data: Dictionary = {
	"high_score": 0,                      # best score so far
	"options": {                          # simple on/off options
		"sfx_on": true,
		"low_fx": false
	}
}

func _ready() -> void:
	# Load saved data when the game starts.
	load_data()

# ------------------------------------------------------------
# HIGH SCORE HELPERS
# ------------------------------------------------------------

func get_high_score() -> int:
	# Read high score from the Dictionary.
	return int(data.get("high_score", 0))

func try_set_high_score(score: int) -> bool:
	# If the new score is better, save it and return true.
	if score > get_high_score():
		data["high_score"] = score
		save_data()
		return true
	return false

# ------------------------------------------------------------
# SIMPLE OPTIONS (on/off)
# ------------------------------------------------------------

func set_option(key: String, value: bool) -> void:
	# Update an option and save right away.
	var opts: Dictionary = data.get("options", {})
	opts[key] = value
	data["options"] = opts
	save_data()

func get_option(key: String, default_value: bool = false) -> bool:
	# Read an option with a default value.
	var opts: Dictionary = data.get("options", {})
	return bool(opts.get(key, default_value))

# ------------------------------------------------------------
# SAVE / LOAD
# ------------------------------------------------------------

func save_data() -> void:
	# Open the file for writing.
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("ScoreManager: cannot open save file for writing.")
		return

	# Convert Dictionary → JSON text. "\t" makes it pretty to read.
	var json_text: String = JSON.stringify(data, "\t")
	f.store_string(json_text)
	f.flush()
	f.close()
	print("[ScoreManager] saved to ", SAVE_PATH, " | high=", data.get("high_score", 0))
func load_data() -> void:
	# If there is no file yet, keep defaults and return.
	if not FileAccess.file_exists(SAVE_PATH):
		return

	# Open the file for reading.
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("ScoreManager: cannot open save file for reading.")
		return

	# Read the whole file as text.
	var text: String = f.get_as_text()
	f.close()

	# Parse JSON text → Variant value.
	# IMPORTANT: use "=" (not ":="), because we give the type explicitly.
	var value: Variant = JSON.parse_string(text)

	# Only accept a Dictionary. If not, keep default data.
	if value is Dictionary:
		data = value as Dictionary
	else:
		push_warning("ScoreManager: invalid JSON; using defaults.")

# ------------------------------------------------------------
# RESET (optional helper)
# ------------------------------------------------------------

func reset_data() -> void:
	# Put everything back to default and save.
	data = {
		"high_score": 0,
		"options": {
			"sfx_on": true,
			"low_fx": false
		}
	}
	save_data()
