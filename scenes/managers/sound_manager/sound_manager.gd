extends Control

func _ready():
	pass

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
