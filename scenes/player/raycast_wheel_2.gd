extends Node3D
class_name RayCastWheel2

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
@export var grip_curve: Curve
@export var z_traction: float
@export var tire_turn_speed := 0.1
@export var tire_max_turn_degrees := 25
@export var turn_radius_curve: Curve

@export_group("Functions")
@export var is_motor := false
@export var is_steer := false

@export_category("Debug")
@export var show_debug := false
#endregion

#region On Ready Variables
@onready var mesh: Node3D = self.get_node("Mesh") # should be mesh instance, no?
@onready var ray: RayCast3D = self.get_node("FloorRay")
@onready var rotation_indicator: MeshInstance3D = self.get_node("Mesh/RotationIndicator")

@onready var force_pos_timer: Timer = self.get_node("Timer")
#endregion

#region Physics Variables (updated near the start of every physics frame)
var force_position: Vector3
var contact_point: Vector3
var ray_forward: Vector3
var vehicle_forward_velocity: float
var spring_length: float
var physics_delta: float
var tire_velocity: Vector3
#var last_force_pos
var steering_velocity: float
var grip_ratio: float
var grip_factor: float
var z_grip_factor: float
var gravity: float
var offset: float
var calculatedRPM: int
var is_slipping := false
#endregion

#region Lifetime Variables (set on _ready)
var vehicle_mass: float
#endregion

#region Physics Forces 
var acceleration_force: Vector3
var spring_force: Vector3
var steering_force: Vector3
var drag_force: Vector3
#endregion

func _ready() -> void:
	self.vehicle_mass = vehicle.mass
	ray.target_position.y = -(rest_dist + wheel_radius + over_extend)

#region Do Wheel Process (function called from Vehicle every physics frame)
func do_wheel_process(body: Vehicle, delta: float):
	ray.force_raycast_update()
	calc_shared_values(delta)
	
	do_wheel_steer()
	
	if ray.is_colliding():
		self.mesh.position.y = -self.spring_length
		do_wheel_physics()
	else:
		do_return_to_rest()
	
	do_wheel_spin()
	
	if show_debug:
		Draw.vector(ray.global_position + Vector3(1, 0, 0), ray.target_position, Color.WEB_PURPLE)
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
	#mesh.rotate_x((-vehicle_forward_velocity * delta) / wheel_radius)

func do_return_to_rest():
	var rest_position = -(rest_dist - ray.target_position.y - wheel_radius - 0.18)
	mesh.position.y = lerp(mesh.position.y, rest_position, 1.0 - exp(-wheel_return_speed * physics_delta))
#endregion

#region Calculate Shared Values
func calc_shared_values(delta):
	self.contact_point = self.ray.get_collision_point()
	self.spring_length = self.ray.global_position.distance_to(self.contact_point) - self.wheel_radius
	self.offset = self.rest_dist - spring_length
	var tire_mesh_position = Vector3(self.mesh.global_position)
	#tire_mesh_position.y = -(self.spring_length)
	self.contact_point = tire_mesh_position
	self.force_position = self.contact_point - vehicle.global_position
	self.ray_forward = -self.ray.global_basis.z
	self.vehicle_forward_velocity = self.ray_forward.dot(vehicle.linear_velocity)
	self.physics_delta = delta
	self.tire_velocity = get_point_velocity(self.vehicle, self.contact_point)
	## steering_velocity = float;  <0, if opposite direction, 0 if perpendicular, >0 if same direction 
	self.steering_velocity = self.ray.global_basis.x.dot(tire_velocity)
	Draw.vector(self.force_position + vehicle.global_position, -ray.global_basis.x, Color.BLACK)
	self.grip_ratio = absf(self.steering_velocity / self.tire_velocity.length())
	self.grip_factor = self.grip_curve.sample_baked(self.grip_ratio)
	self.gravity = -self.vehicle.get_gravity().y
	self.z_grip_factor = z_traction
	if is_slipping:
		self.grip_factor = 0.5
		self.z_grip_factor = 0.5
#endregion

#region Do Wheel Physics
func do_wheel_physics():
	#var apply_acceleration := vehicle_forward_velocity < vehicle.max_speed and is_motor and vehicle.motor_input and vehicle.current_gear == 1
	var apply_acceleration := is_motor and vehicle.motor_input
	if apply_acceleration:
		self.acceleration_force = calc_acceleration_force()
		vehicle.apply_force(self.acceleration_force, self.force_position)
	
	self.spring_force = calc_spring_force()
	var apply_spring := (vehicle.linear_velocity.y > 0 or self.spring_force.y > 0)
	if apply_spring:
		vehicle.apply_force(self.spring_force, self.force_position)
	
	var apply_steering := true
	if apply_steering:
		self.steering_force = calc_steering_force()
		vehicle.apply_force(self.steering_force, self.force_position)
	
	#var apply_drag := is_motor and !vehicle.motor_input
	var apply_drag := false
	if apply_drag:
		self.drag_force = calc_drag_force()
		vehicle.apply_force(self.drag_force, self.force_position)
	
	if self.show_debug:
		if apply_acceleration: Draw.vector(self.force_position + vehicle.global_position, self.acceleration_force / vehicle_mass, Color.GREEN)
		if apply_spring: Draw.vector(self.force_position + vehicle.global_position, spring_force / vehicle_mass, Color.BLUE)
		if apply_steering: Draw.vector(self.force_position + vehicle.global_position, steering_force / vehicle_mass, Color.RED)
		if apply_drag: Draw.vector(self.force_position + vehicle.global_position, drag_force / vehicle_mass, Color.BLACK)
#endregion

#region Calculate Instant Forces
func calc_steering_force() -> Vector3:
	DebugDraw2D.set_text("grip_factor: ", grip_factor)
	grip_factor = 1
	return -ray.global_basis.x * steering_velocity * grip_factor * ((vehicle_mass * gravity)/ vehicle.total_wheels)

func calc_acceleration_force() -> Vector3:
	## if new speed is x amount higher
	#return ray_forward * vehicle.acceleration * vehicle.motor_input * speed_factor
	return ray_forward * vehicle.motor_input * vehicle.wheel_torque / wheel_radius

func calc_spring_force() -> Vector3:
	var offset := self.rest_dist - self.spring_length
	var spring_force := spring_strength * offset
	var tire_velocity := get_point_velocity(vehicle, contact_point)
	var spring_damp_force := spring_damping * ray.global_basis.y.dot(tire_velocity)
	return (spring_force - spring_damp_force) * ray.get_collision_normal()

func calc_drag_force() -> Vector3:
	var forward_velocity := ray_forward.dot(tire_velocity)
	return ray.global_basis.z * forward_velocity * z_grip_factor * ((vehicle_mass * gravity))

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
