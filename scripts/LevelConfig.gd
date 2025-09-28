# res://levels/LevelConfig.gd
extends Resource
class_name LevelConfig

# Name of the level (for display or debugging)
@export var level_name: String = "Level 1"

# How long the level lasts in seconds
@export var duration_sec: int = 60           

# How often enemies spawn (enemies per second)
@export var spawn_rate_per_sec: float = 1.5  

# Maximum number of enemies that can be active on screen
@export var max_enemies_on_screen: int = 10

# Base movement speed for enemies
@export var enemy_speed: float = 200.0

# List of enemy types available in this level
@export var enemy_types: Array[String] = ["basic"]  

# Multiplier for score calculation in this level
@export var score_multiplier: float = 1.0

# Optional: different background video per level (leave empty if not used)
@export var background_video_path: String = ""      
