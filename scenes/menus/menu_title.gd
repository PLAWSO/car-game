extends Control

func _on_button_pressed() -> void:
	SoundManager.stop_menu_music()
	SoundManager.play_button_sound()
	LevelManager.change_to_level_1()
