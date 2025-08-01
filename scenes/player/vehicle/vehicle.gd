extends RigidBody3D
class_name Vehicle

#region Exported Variables
@export_category("Car")
@export_group("Wheels")
@export var ray_cast_wheels: Array[RayCastWheel]
@export var frames_to_hook_up := 60

@export_group("Drag")
@export var drag_coefficient := 0.3

@export_group("Engine")
@export var sound_pitch_factor := 4.0
@export var max_rpm := 9000
@export var max_horsepower := 100
@export var power_curve: Curve

@export_group("Transmission")
@export var num_gears := 3
@export var throttle_change_factor := 2
@export var gears: Array[float]
@export var final_drive = 4.5

@export_category("Debug")
@export var show_debug := false
@export_group("Text")
@export_range(1, 100) var text_groups_title_font_size := 20
@export_range(1, 100) var text_groups_text_font_size := 17
#endregion

#region Lifetime Variables (set on _ready)
var total_wheels: int
#endregion

#region User Input Variables (directly connected to user input)
var motor_input := 0
var brake_input := 0
var hand_brake := false
var current_gear := 0
var throttle := 0.0
var throttle_rpm := 1000.0
var frames_hooked_up := 0
#endregion

#region Physics Variables (updated near the start of every physics frame)
var physics_delta: float
var current_rpm := 1000.0
var wheel_torque := 0.0
var drag_force: Vector3
var total_gear_ratio: float
#endregion

func _ready():
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.DOWN * 0.5
	
	self.total_wheels = ray_cast_wheels.size()
	
	#reset()
	
	Engine.time_scale = 1

#region Handle User Input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drift"):
		hand_brake = true
	elif event.is_action_released("drift"):
		hand_brake = false
	
	if event.is_action_pressed("shift_up"):
		if current_gear < num_gears:
			current_gear += 1
	if event.is_action_pressed("shift_down"):
		if current_gear > -1:
			current_gear -= 1
	
	if event.is_action_pressed("accelerate"):
		if current_gear == -1:
			motor_input = -1
		else:
			motor_input = 1
	elif event.is_action_released("accelerate"):
		motor_input = 0
	
	if event.is_action_pressed("brake"):
		brake_input = 1
	elif event.is_action_released("brake"):
		brake_input = 0
	
	if event.is_action_pressed("reset"):
		reset(Vector3(0, 10, 0))
	if event.is_action_pressed("reset_high"):
		reset(Vector3(0, 20, 0))


#endregion

#region Physics Process
func _physics_process(delta: float) -> void:
	calc_shared_values(delta)
	
	set_throttle()
	
	set_throttle_rpm()
	
	apply_drag()

	set_wheel_torque()
	
	if show_debug:
		draw_debug()
	
	do_wheels_physics(self)
	
	set_engine_rpm()
	
	do_basic_sound()

#endregion

#region Calculate Shared Values
func calc_shared_values(delta):
	self.total_gear_ratio = gears[current_gear] * final_drive
	self.physics_delta = delta
	pass

#endregion

#region Do Wheels Physics (calculate and apply all forces for all wheels)
func do_wheels_physics(body: Vehicle) -> void:
	for wheel in ray_cast_wheels:
		wheel.do_wheel_process(body, physics_delta)
#endregion

#region Set Throttle Position
func set_throttle():
	if motor_input != 0:
		self.throttle = move_toward(throttle, 1, throttle_change_factor * physics_delta)
	else:
		self.throttle = move_toward(throttle, 0, throttle_change_factor * physics_delta)

func set_throttle_rpm():
	self.throttle_rpm = (throttle * (max_rpm - 1000)) + 1000

#endregion

#region Set Torque Applied To Wheels
func set_wheel_torque():
	## using current_rpm from last physics frame
	var engine_power_watts = power_curve.sample_baked(self.current_rpm) * max_horsepower * 745.7 * throttle
	var rpm_rad = (self.current_rpm * 2 * PI) / 60.0
	var engine_torque = engine_power_watts / rpm_rad
	self.wheel_torque = engine_torque * self.total_gear_ratio
#endregion

#region Set Engine RPM
func set_engine_rpm():
	var total_rpm = 0.0
	var no_drive_wheels_slipping = true
	var some_drive_wheels_colliding = false
	var drive_wheels := 0
	for wheel in ray_cast_wheels:
		if wheel.is_motor:
			total_rpm = (wheel.wheel_velocity.length() / (wheel.wheel_radius * PI * 2) * total_gear_ratio * 60)
			drive_wheels += 1
			if wheel.is_slipping:
				no_drive_wheels_slipping = false
			if wheel.ray.is_colliding():
				some_drive_wheels_colliding = true
	
	if !no_drive_wheels_slipping:
		frames_hooked_up = 0
	else:
		frames_hooked_up += 1
	
	if no_drive_wheels_slipping and some_drive_wheels_colliding and current_gear != 0 and frames_hooked_up > frames_to_hook_up:
		print("CONNECTED")
		self.current_rpm = clamp(total_rpm / drive_wheels, 1000, max_rpm)
	else:
		print("SOLO")
		self.current_rpm = throttle_rpm
		#self.current_rpm = move_toward(self.current_rpm, throttle_rpm, 1000 * physics_delta)
#endregion

#region Apply Drag
func apply_drag():
	self.drag_force = self.linear_velocity.normalized() * self.linear_velocity.length_squared() * drag_coefficient
	apply_force(-self.drag_force, Vector3(0, -0.5, 0))
	
	if show_debug:
		Draw.vector(global_position + Vector3(0, -0.5, 0), -self.drag_force / mass, Color.BLUE)

#endregion

#region Sound
func do_basic_sound():
	var pitch_ratio = ((current_rpm - 999) / max_rpm) * sound_pitch_factor
	SoundManager.change_pitch_vehicle_run(pitch_ratio)
	SoundManager.play_vehicle_run()
#endregion

#region Draw Debug
func draw_debug():
	#Draw.box(self.global_position + Vector3(0, 0.116, 0), self.quaternion, Vector3(1.885, 1.085, 3.9), Color.AQUA)
	DebugDraw2D.begin_text_group("-- Vehicle --", 2, Color.LIME_GREEN, true, text_groups_title_font_size, text_groups_text_font_size)
	DebugDraw2D.set_text("Velocity: ", linear_velocity.length())
	DebugDraw2D.set_text("Current Gear: ", current_gear)
	DebugDraw2D.set_text("Throttle: ", throttle)
	DebugDraw2D.set_text("Current RPM: ", current_rpm)

	#for i in ray_cast_wheels.size():
		#var color := Color.RED if ray_cast_wheels[i].is_slipping else Color.GREEN
		#Draw.gui_box(str(i), color)
	DebugDraw2D.end_text_group()
	
	#Draw.text_at_position(self.global_position, str(self.global_position))
	#Draw.vector(self.global_position, self.linear_velocity * 10, Color.CORNSILK)
#endregion

#region Reset Car
func _on_fall_zone_body_entered(body: Node3D) -> void:
		reset(Vector3(0, 10, 0))


func reset(start_pos: Vector3):
	global_position = start_pos
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
#endregion
