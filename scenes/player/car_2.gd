extends RigidBody3D
class_name Vehicle

@export_category("Car")
@export_group("Wheels")
@export var ray_cast_wheels: Array[RayCastWheel2]
@export var z_traction := 10.0 

@export_group("Stats")
@export var acceleration := 3000.0
@export var max_speed := 100
@export var accel_curve: Curve
@export var total_wheels := 4
@export var drag_coefficient := 0.3
@export var rolling_coefficient := 0.02 # approx 0.007 - 0.02

@export_group("Engine")
@export var sound_pitch_factor := 4.0
@export var max_rpm := 9000
@export var max_horsepower := 100
@export var power_curve: Curve
@export var num_gears := 3
@export var throttle_change_factor := 10
@export var unloaded_rpm_change_factor := 12000 # approx equal to max_rpm
@export var gears: Array[float]


@export_category("Debug")
@export var show_debug := false
@export_group("Text")
@export_range(1, 100) var text_groups_title_font_size := 20
@export_range(1, 100) var text_groups_text_font_size := 17

var motor_input := 0
var hand_brake := false
var idle := false
var current_gear := 0
var throttle := 0.0
var delta: float
var rpm_at_throttle_pos := 1000.0
var current_rpm := 1000.0
var load := 0.001
var wheel_torque := 0.0
var drag := 0.0
const final_drive = 4.5

func _ready():
	#SoundManager.play_vehicle_idle()
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.DOWN * 0.5
	
	#reset()
	
	Engine.time_scale = 1


func reset(start_pos: Vector3):
	#for wheel in ray_cast_wheels:
		#var start_pos := wheel.position.y + wheel.target_position.y + wheel.wheel_radius
		#wheel.wheel_mesh.position.y = start_pos
	
	global_position = start_pos
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drift"):
		hand_brake = true
	elif event.is_action_released("drift"):
		hand_brake = false
	if event.is_action_pressed("accelerate"):
		motor_input = 1
	elif event.is_action_released("accelerate"):
		motor_input = 0
	if event.is_action_pressed("decelerate"):
		motor_input = -1
	elif event.is_action_released("decelerate"):
		motor_input = 0
	
	if event.is_action_pressed("reset"):
		reset(Vector3(0, 10, 0))
	if event.is_action_pressed("reset_high"):
		reset(Vector3(0, 20, 0))
	if event.is_action_pressed("shift_up"):
		if current_gear < num_gears:
			current_gear += 1
	if event.is_action_pressed("shift_down"):
		if current_gear > -1:
			current_gear -= 1


func _physics_process(delta: float) -> void:
	self.delta = delta
	
	set_throttle()
	set_rpm()
	
	apply_drag()

	set_wheel_torque()
	
	
	## check if wheels are slipping
	#var velocity := linear_velocity.length()
	#var drag_force := velocity * z_traction * ((mass * get_gravity().y))
	#
	#var acceleration_force = (global_basis.z * power * acceleration * motor_input).length()
	#var net_force = acceleration_force + drag_force
	#DebugDraw2D.set_text("acceleration_force: ", acceleration_force)
	#DebugDraw2D.set_text("drag_force: ", drag_force)
	#DebugDraw2D.set_text("Net Force: ", net_force)
	
	#for i in ray_cast_wheels.size():
		#if ray_cast_wheels[i].is_motor:
			#
			#ray_cast_wheels[i].is_slipping = false
			#if net_force > 1400:
				#ray_cast_wheels[i].is_slipping = true
		
		#var color := Color.RED if ray_cast_wheels[i].is_slipping else Color.GREEN
		#Draw.gui_box(str(i), color)
	
	if show_debug:
		draw_debug()
	
	DebugDraw2D.begin_text_group("-- Vehicle --", 2, Color.LIME_GREEN, true, text_groups_title_font_size, text_groups_text_font_size)
	DebugDraw2D.set_text("Velocity: ", linear_velocity.length())
	DebugDraw2D.set_text("Current Gear: ", current_gear)
	DebugDraw2D.set_text("Throttle: ", throttle)
	DebugDraw2D.set_text("Current RPM: ", current_rpm)
	
	do_wheels_physics(self, delta)
	

	
	idle = !motor_input
	
	do_basic_sound()

func set_throttle():
	if motor_input == 1:
		self.throttle = move_toward(throttle, 1, throttle_change_factor * delta)
	else:
		self.throttle = move_toward(throttle, 0, throttle_change_factor * delta)

func set_rpm():
	#self.current_rpm = move_toward(current_rpm, (throttle * max_rpm) + 1000, unloaded_rpm_change_factor * delta)
	self.rpm_at_throttle_pos = (throttle * (max_rpm - 1000)) + 1000

func set_wheel_torque():
	var engine_power_watts = power_curve.sample_baked(self.current_rpm) * max_horsepower * 745.7
	var rpm_rad = (self.current_rpm * 2 * PI) / 60.0
	var engine_torque = engine_power_watts / rpm_rad
	var total_gear_ratio = gears[current_gear] * final_drive
	self.wheel_torque = engine_torque * total_gear_ratio
	DebugDraw2D.set_text("wheel_torque: ", wheel_torque)
	
	#var wheel_rpm = rpm_at_throttle_pos / total_gear_ratio
	var wheel_rpm = self.rpm_at_throttle_pos / total_gear_ratio
	var wheel_angular_velocity = (wheel_rpm * TAU) / 60.0
	var expected_forward_velocity = wheel_angular_velocity * ray_cast_wheels[0].wheel_radius
	DebugDraw2D.set_text("expected_forward_velocity", expected_forward_velocity)
	DebugDraw2D.set_text("rpm_at_throttle_pos", rpm_at_throttle_pos)
	
	if (!Float.is_valid(expected_forward_velocity)):
		self.current_rpm = move_toward(self.current_rpm, self.rpm_at_throttle_pos, unloaded_rpm_change_factor * delta)
		#self.current_rpm = self.rpm_at_throttle_pos
		return
	
	var forward_dir = -global_transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	var flat_velocity = linear_velocity
	flat_velocity.y = 0
	var forward_speed = flat_velocity.dot(forward_dir)
	DebugDraw2D.set_text("forward_speed", forward_speed)
	
	var lug_factor = 0
	var no_wheels_touched = true
	for wheel in ray_cast_wheels:
		#if wheel.is_motor and wheel.ray.is_colliding():
		if wheel.is_motor:
			no_wheels_touched = false
			var velocity_error = expected_forward_velocity - forward_speed
			var expected_rpm = (forward_speed / (wheel.wheel_radius * PI * 2) * total_gear_ratio * 60)
			DebugDraw2D.set_text("expected_rpm: ", expected_rpm)
			#var load = clamp(1.0 + velocity_error * 0.1, 0.5, 3.0)
			#var rpm_change_rate = unloaded_rpm_change_factor / load
			#var clamped = clamp(rpm_change_rate, 0, 100)
			#self.current_rpm = move_toward(current_rpm, (throttle * max_rpm) + 1000, rpm_change_rate * delta)
			self.current_rpm = clamp(expected_rpm, 1000, max_rpm)
			#if abs(expected_forward_velocity - forward_speed) > 5 and self.current_rpm > 2000:
				### REPLACE IF WITH net_force > tire_z_traction
				#if (expected_forward_velocity - forward_speed) > 5:
					#print("SLIPPING")
					#self.wheel_torque *= 0.000000002
	#if no_wheels_touched:
		#self.current_rpm = move_toward(rpm_at_throttle_pos, (throttle * max_rpm) + 1000, unloaded_rpm_change_factor * delta)

func apply_drag():
	var drag := self.linear_velocity.normalized() * self.linear_velocity.length_squared() * drag_coefficient
	var rolling_resistance = self.linear_velocity.normalized() * mass * get_gravity().y * rolling_coefficient
	apply_force(-drag, Vector3(0, -0.5, 0))
	
	#DebugDraw2D.set_text("normalized", -global_transform.basis.z.normalized())
	Draw.vector(global_position + Vector3(0, -0.5, 0), -drag / mass, Color.BLUE)
	
	var forward_dir = -global_transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	#DebugDraw2D.set_text("forward_dir", forward_dir)
	
	var flat_velocity = linear_velocity
	flat_velocity.y = 0
	var forward_speed = flat_velocity.dot(forward_dir)
	#DebugDraw2D.set_text("forward_speed", forward_speed)
	
	if abs(forward_speed) > 0.1:
		var resistance_force = forward_dir * forward_speed * (mass * get_gravity().y) * rolling_coefficient
		apply_central_force(resistance_force)
		#DebugDraw2D.set_text("resistance_force", resistance_force)
		
		Draw.vector(global_position, resistance_force * 1000000, Color.RED)


func do_basic_sound():
	var pitch_ratio = ((current_rpm - 999) / max_rpm) * sound_pitch_factor
	#DebugDraw2D.set_text("pitch_ratio: ", pitch_ratio)
	
	SoundManager.change_pitch_vehicle_run(pitch_ratio)
	
	SoundManager.play_vehicle_run()
	#if idle:
		#SoundManager.play_vehicle_idle()
	#else:
		#SoundManager.stop_vehicle_idle()
		#SoundManager.play_vehicle_run()

func draw_debug():
	Draw.box(self.global_position + Vector3(0, 0.116, 0), self.quaternion, Vector3(1.885, 1.085, 3.9), Color.AQUA)
	

	for i in ray_cast_wheels.size():
		var color := Color.RED if ray_cast_wheels[i].is_slipping else Color.GREEN
		Draw.gui_box(str(i), color)
	DebugDraw2D.end_text_group()
	
	Draw.text_at_position(self.global_position, str(self.global_position))
	Draw.vector(self.global_position, self.linear_velocity * 10, Color.CORNSILK)


func do_wheels_physics(body: Vehicle, delta: float) -> void:
	for wheel in ray_cast_wheels:
		wheel.do_wheel_process(body, delta)


func _on_fall_zone_body_entered(body: Node3D) -> void:
		reset(Vector3(0, 10, 0))
