extends Node3D
class_name RayCastWheel2

@export_group("Spring Properties")
@export var spring_strength := 5000
@export var spring_damping := 120
@export var rest_dist := 0.175
@export var over_extend := 0.2

@export_group("Wheel Properties")
@export var wheel_radius := 0.3
@export var grip_curve: Curve
@export var x_traction: float
@export var z_traction: float
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25

@export_group("Motor")
@export var is_motor := false
@export var is_steer := false

@export_category("Debug")
@export var show_debug := false

@onready var mesh: Node3D = self.get_node("Mesh") # should be mesh instance, no?
@onready var ray: RayCast3D = self.get_node("FloorRay")
@onready var rotation_indicator: MeshInstance3D = self.get_node("Mesh/RotationIndicator")

@onready var force_pos_timer: Timer = self.get_node("Timer")
var last_force_pos

var is_slipping := false

var wheel_return_speed = 5.0

func _ready() -> void:
	ray.target_position.y = -(rest_dist + wheel_radius + over_extend)

func get_point_velocity(body: RigidBody3D, point: Vector3) -> Vector3:
	return body.linear_velocity + body.angular_velocity.cross(point - body.global_transform.origin)


func do_wheel_process(body: Vehicle, delta: float):
	do_wheel_steer(delta)
	do_wheel_physics(body, delta)
	
	#Draw.vector(ray.global_position + Vector3(1, 0, 0), ray.target_position, Color.WEB_PURPLE)
	#print(ray.global_position - ray.target_position)


func do_wheel_steer(delta: float):
	if not is_steer: return
	
	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	if turn_input:
		rotation.y = clampf(rotation.y + turn_input * delta,
		deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
	else:
		rotation.y = move_toward(rotation.y, 0, tire_turn_speed * delta)


func do_wheel_physics(body: Vehicle, delta: float):
	ray.force_raycast_update()
	#ray.target_position.y = -(rest_dist + wheel_radius + over_extend)
	
	var mass = body.mass
	
	## visually spin wheel
	var ray_forward := -ray.global_basis.z
	var body_velocity := ray_forward.dot(body.linear_velocity)
	mesh.rotate_x((-body_velocity * delta) / wheel_radius)
	
	if not ray.is_colliding():
		#mesh.position.y = -(rest_dist - ray.target_position.y - wheel_radius - 0.18) # bigger number = higher
		var rest_position = -(rest_dist - ray.target_position.y - wheel_radius - 0.18)
		mesh.position.y = lerp(mesh.position.y, rest_position, 1.0 - exp(-wheel_return_speed * delta))
		print("NOT COLLIDING")
		return
	print("PAUSE")
	
	var contact := ray.get_collision_point()
	var spring_length := ray.global_position.distance_to(contact) - wheel_radius
	var offset := rest_dist - spring_length
	
	mesh.position.y = -spring_length
	contact = mesh.global_position
	var force_pos := contact - body.global_position
	
	## spring forces
	var spring_force := spring_strength * offset
	var tire_velocity := get_point_velocity(body, contact)
	var spring_damp_force := spring_damping * ray.global_basis.y.dot(tire_velocity)
	
	var y_force := (spring_force - spring_damp_force) * ray.get_collision_normal()
	
	## acceleration
	if is_motor and body.motor_input:
		var speed_ratio := body_velocity / body.max_speed
		var speed_factor := body.accel_curve.sample_baked(speed_ratio)
		var acceleration_force := ray_forward * body.acceleration * body.motor_input * speed_factor
		body.apply_force(acceleration_force, force_pos)
		if self.show_debug: Draw.vector(force_pos + body.global_position, acceleration_force / mass, Color.GREEN)
	
	## steering
	var steering_velocity := ray.global_basis.x.dot(tire_velocity)
	
	var grip_ratio = absf(steering_velocity / tire_velocity.length())
	var grip_factor := grip_curve.sample_baked(grip_ratio)
	
	#if not body.hand_brake and grip_factor < 0.2:
		#self.is_slipping = false
	#if body.hand_brake and not self.is_steer:
		#grip_factor = 0.4
		#self.is_slipping = true
	#elif self.is_slipping and not self.is_steer:
		#grip_factor = 0.4
		#self.is_slipping = true
	var z_grip_factor := z_traction
	if body.hand_brake:
		grip_factor = 0
		z_grip_factor = 0
	
	var gravity := -body.get_gravity().y
	var x_force := -ray.global_basis.x * steering_velocity * grip_factor * ((body.mass * gravity)/ body.total_wheels)
	
	var forward_velocity := ray_forward.dot(tire_velocity)
	var z_force := ray.global_basis.z * forward_velocity * z_grip_factor * ((body.mass * gravity))
	
	body.apply_force(x_force, force_pos)
	var apply_suspension_force: bool = body.linear_velocity.y > 0 or y_force.y > 0
	if apply_suspension_force: body.apply_force(y_force, force_pos)
	## drag
	if is_motor and !body.motor_input:
		body.apply_force(z_force, force_pos)
	
	
	if self.show_debug:
		Draw.vector(force_pos + body.global_position, ray.global_basis.x, Color.BLUE_VIOLET)
		Draw.vector(force_pos + body.global_position, x_force / mass, Color.RED)
		if apply_suspension_force: Draw.vector(force_pos + body.global_position, y_force / mass, Color.BLUE)
		if is_motor and !body.motor_input: Draw.vector(force_pos + body.global_position, z_force / mass, Color.BLACK)
	
	last_force_pos = body.global_position


func _on_timer_timeout() -> void:
	if typeof(last_force_pos) != typeof(Vector3.ZERO): return
	print(Format.vec3(last_force_pos))
	force_pos_timer.start()
	
