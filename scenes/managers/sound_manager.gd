extends Control

func _ready():
	$MusicMenu.play()

func play_enemy_sound():
	$SoundEnemy.play()

func play_coin_sound():
	$SoundCoin.play()

func play_fall_sound():
	$SoundFall.play()

func play_button_sound():
	$SoundButton.play()

func play_menu_music():
	$MusicMenu.play()

func stop_menu_music():
	$MusicMenu.stop()

func play_level_music():
	$MusicLevel.play()

func stop_level_music():
	$MusicLevel.stop()

func play_vehicle_idle():
	if !$VehicleIdle.playing:
		$VehicleIdle.play()

func stop_vehicle_idle():
	$VehicleIdle.stop()

func play_vehicle_run():
	if !$VehicleRun.playing:
		$VehicleRun.play()

func stop_vehicle_run():
	$VehicleRun.stop()

func change_pitch_vehicle_run(pitch_scale: float):
	$VehicleRun.pitch_scale = pitch_scale
