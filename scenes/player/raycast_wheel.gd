extends Node3D
class_name RayCastWheel

#region Exported Variables
@export_group("Vehicle")
@export var vehicle: Vehicle

@export_group("Spring Properties")
@export var spring_strength := 5000
@export var spring_damping := 120
@export var rest_dist := 0.175
@export var over_extend := 0.2
@export var wheel_return_speed = 5.0

@export_group("Wheel Properties")
@export var wheel_radius := 0.3
@export var tire_turn_speed := 0.1
@export var tire_max_turn_degrees := 25
@export var turn_radius_curve: Curve
@export var rolling_coef := 0.02 # approx 0.007 - 0.02
@export var braking_coef := 100

@export_group("Functions")
@export var is_motor := false
@export var is_steer := false

@export_category("Debug")
@export var show_debug := false
#endregion

#region On Ready Variables
@onready var mesh: Node3D = self.get_node("Mesh") # should be mesh instance, no?
@onready var ray: RayCast3D = self.get_node("FloorRay")
@onready var force_pos_timer: Timer = self.get_node("Timer")
@onready var smoke_particle: GPUParticles3D = self.get_node("SmokeParticle")
#endregion

#region Physics Variables (updated near the start of every physics frame)
var vehicle_wheel_center_offset: Vector3
var contact_point: Vector3
var spring_length: float
var physics_delta: float
var is_slipping := false
var wheel_velocity: Vector3
#endregion

#region Lifetime Variables (set on _ready)
var vehicle_mass: float
var resting_weight_on_wheel: float
#endregion

#region Physics Forces 
var acceleration_force: Vector3
var spring_force: Vector3
var steering_force: Vector3
var rolling_resistance_force: Vector3
var braking_force: Vector3
#endregion

func _ready() -> void:
	await get_tree().process_frame
	if is_motor:
		smoke_particle.emitting = false
	self.vehicle_mass = vehicle.mass
	ray.target_position.y = -(rest_dist + wheel_radius + over_extend)
	self.resting_weight_on_wheel = ((vehicle_mass * -self.vehicle.get_gravity().y) / vehicle.total_wheels)

#region Do Wheel Process (function called from Vehicle every physics frame)
func do_wheel_process(body: Vehicle, delta: float):
	ray.force_raycast_update()
	calc_shared_values(delta)
	
	do_wheel_steer()
	
	if ray.is_colliding():
		self.mesh.position.y = -self.spring_length
		do_wheel_physics()
	else:
		if is_motor:
			smoke_particle.emitting = false
		do_return_to_rest()
	
	do_wheel_spin()

#endregion

#region Move Wheel
func do_wheel_steer():
	if not is_steer: return
	
	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	var max_turn := self.turn_radius_curve.sample_baked(vehicle.linear_velocity.length()) * tire_max_turn_degrees # CHANGE TO VELOCITY OF VEHICLE
	if turn_input:
		rotation.y = clampf(rotation.y + turn_input * physics_delta, deg_to_rad(-max_turn), deg_to_rad(max_turn))
	else:
		rotation.y = move_toward(rotation.y, 0, tire_turn_speed * physics_delta)

func do_wheel_spin():
	pass
	## visually spin wheel
	## I think we want this to be based on engine speed only?
	#mesh.rotate_x((-vehicle_forward_velocity * delta) / wheel_radius)

func do_return_to_rest():
	var rest_position = -(rest_dist - ray.target_position.y - wheel_radius - 0.18)
	mesh.position.y = lerp(mesh.position.y, rest_position, 1.0 - exp(-wheel_return_speed * physics_delta))
#endregion

#region Calculate Shared Values
func calc_shared_values(delta):
	self.contact_point = self.ray.get_collision_point()
	self.spring_length = self.ray.global_position.distance_to(self.contact_point) - self.wheel_radius
	self.vehicle_wheel_center_offset = Vector3(self.mesh.global_position) - vehicle.global_position
	self.physics_delta = delta
	self.wheel_velocity = get_point_velocity(self.vehicle, self.contact_point)
#endregion

#region Do Wheel Physics
func do_wheel_physics():
	var apply_rolling_resistance := true
	if apply_rolling_resistance:
		self.rolling_resistance_force = calc_rolling_resistance_force()
		vehicle.apply_force(self.rolling_resistance_force, self.vehicle_wheel_center_offset)
		
	var apply_acceleration := is_motor and vehicle.motor_input != 0
	if apply_acceleration:
		self.acceleration_force = calc_acceleration_force()
		var losses = self.rolling_resistance_force.length() + vehicle.drag_force.length()
		var max_tolerable_acceleration = 5000 # COULD USE MORE ROBUST SOLUTION
		var currently_slipping: bool = (self.acceleration_force.length() - losses) > max_tolerable_acceleration
		var in_grip_cooldown := vehicle.frames_hooked_up <= vehicle.frames_to_hook_up
		DebugDraw2D.set_text("losses: ", losses)
		DebugDraw2D.set_text("power: ", self.acceleration_force.length())
		DebugDraw2D.set_text("net: ", self.acceleration_force.length() - losses)
		DebugDraw2D.set_text("slipping? ", (self.acceleration_force.length() - losses) > max_tolerable_acceleration)
		
		self.is_slipping = false
		if currently_slipping:
			self.is_slipping = true
		
		if currently_slipping or in_grip_cooldown:
			self.acceleration_force.limit_length(max_tolerable_acceleration)
			smoke_particle.emitting = true
			vehicle.apply_force(self.acceleration_force, self.vehicle_wheel_center_offset)
		else:
			smoke_particle.emitting = false
			vehicle.apply_force(self.acceleration_force, self.vehicle_wheel_center_offset)
	
	self.spring_force = calc_spring_force()
	var apply_spring := (vehicle.linear_velocity.y > 0 or self.spring_force.y > 0)
	if apply_spring:
		vehicle.apply_force(self.spring_force, self.vehicle_wheel_center_offset)
	
	var apply_steering := true
	if apply_steering:
		self.steering_force = calc_steering_force()
		vehicle.apply_force(self.steering_force, self.vehicle_wheel_center_offset)
	
	var apply_braking := vehicle.brake_input
	if apply_braking:
		self.braking_force = calc_braking_force()
		vehicle.apply_force(self.braking_force, self.vehicle_wheel_center_offset)
	
	if self.show_debug:
		pass
		#DebugDraw2D.set_text("losses: ", (self.rolling_resistance_force + (vehicle.drag_force / 4)).length())
		#DebugDraw2D.set_text("power: ", (self.acceleration_force).length())
		#DebugDraw2D.set_text("net: ", (self.acceleration_force).length() - (self.rolling_resistance_force + (vehicle.drag_force / 4)).length())

		#if apply_acceleration: Draw.vector(self.global_position, self.acceleration_force / vehicle_mass, Color.GREEN)
		#if apply_spring: Draw.vector(self.global_position, spring_force / vehicle_mass, Color.BLUE)
		#if apply_steering: Draw.vector(self.global_position, steering_force / vehicle_mass, Color.RED)
		#if apply_rolling_resistance: Draw.vector(self.global_position, rolling_resistance_force / vehicle_mass, Color.BLACK)
		#if apply_braking: Draw.vector(self.global_position, braking_force / vehicle_mass, Color.DEEP_PINK)
		
		
#endregion

#region Calculate Instant Forces
func calc_steering_force() -> Vector3:
	## steering_velocity = float;  <0, if opposite direction, 0 if perpendicular, >0 if same direction
	var steering_velocity := self.ray.global_basis.x.dot(wheel_velocity)
	var steering_traction_factor := calc_steering_traction_factor()
	return -ray.global_basis.x * steering_velocity * resting_weight_on_wheel * steering_traction_factor

func calc_steering_traction_factor() -> float:
	# implement some kind of understeer?
	# self.spring_force < resting_weight_on_wheel
	return 1.0

func calc_acceleration_force() -> Vector3:
	var ray_forward = -self.ray.global_basis.z
	#DebugDraw2D.set_text("motor_input", vehicle.motor_input)
	return ray_forward * vehicle.motor_input * vehicle.wheel_torque / wheel_radius

func calc_spring_force() -> Vector3:
	var offset := self.rest_dist - self.spring_length
	var spring_force := spring_strength * offset
	var spring_damp_force := spring_damping * ray.global_basis.y.dot(wheel_velocity)
	## currently pushing global up, change to pushing vehicle up?
	return (spring_force - spring_damp_force) * ray.get_collision_normal()

func calc_rolling_resistance_force() -> Vector3:
	var forward_dir = -vehicle.global_transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()
	
	var flat_velocity = vehicle.linear_velocity
	flat_velocity.y = 0
	var forward_speed = flat_velocity.dot(forward_dir)
	
	if abs(forward_speed) > 0.1:
		var resistance_force = -(forward_dir * forward_speed * resting_weight_on_wheel * rolling_coef)
		return resistance_force
	
	return Vector3.ZERO

func calc_braking_force() -> Vector3:
	var force = -ray.global_basis.z * self.ray.global_basis.z.dot(wheel_velocity) * braking_coef
	return force


#endregion

#region Helper Functions

func get_point_velocity(body: RigidBody3D, point: Vector3) -> Vector3:
	return body.linear_velocity + body.angular_velocity.cross(point - body.global_transform.origin)

#func _on_timer_timeout() -> void:
	#if typeof(last_force_pos) != typeof(Vector3.ZERO): return
	#print(Format.vec3(last_force_pos))
	#force_pos_timer.start()
	#last_force_pos = body.global_position

#endregion
