extends Node3D

func _ready() -> void:
	SoundManager.play_level_music()
	Global.coins = 0
