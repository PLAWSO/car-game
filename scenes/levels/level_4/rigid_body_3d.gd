extends RigidBody3D

@export var radius: float = 5.0
@export var angular_velocity_deg: float = 45.0

# Corner offsets from the body's origin, in local space
@export var corner_offsets: Array[Vector3] = [
	Vector3( 0.75, -0.5,  1.5), # front right
	Vector3(-0.75, -0.5,  1.5), # front left
	Vector3( 0.75, -0.5, -1.5), # rear right
	Vector3(-0.75, -0.5, -1.5)  # rear left
]

var rotation_center: Vector3

var start_mass = mass

var angle_to_face = 0.0

var started = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		var left_dir = -global_transform.basis.x.normalized()
		rotation_center = global_transform.origin + left_dir * radius
		# Give it the correct tangential velocity to start
		var radial_dir = (global_transform.origin - rotation_center).normalized()
		var tangent_dir = Vector3.UP.cross(radial_dir).normalized()
		linear_velocity = tangent_dir * (deg_to_rad(angular_velocity_deg) * radius)
	
	if event.is_action_pressed("reset_high"):
		started = true
		if mass < 1.0:
			mass = start_mass
		else:
			mass = 0.0000001
	
	if event.is_action_pressed("turn_left"):
		angle_to_face += PI / 4
		global_transform = Transform3D(Basis(Vector3.UP, angle_to_face), global_transform.origin)

func _ready():
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0
	
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0

func _physics_process(_delta: float):
	if !started: return
	DebugDraw2D.begin_text_group("-- Vehicle --", 1, Color.BLACK, true, 20, 20)

	var omega = deg_to_rad(angular_velocity_deg) # rad/sec
	
	## --- Base centripetal force ---
	var radial_dir = -(global_transform.origin - rotation_center).normalized()
	var accel_vector = -radial_dir * (omega * omega * radius)
#
	var total_mass = mass
	var force_per_corner = (total_mass / 4.0) * accel_vector
#
	#for offset in corner_offsets:
		#var world_corner = global_position + global_transform.basis * offset
		#apply_force(force_per_corner, world_corner - global_position)
		#Draw.vector(world_corner, force_per_corner * 10000, Color.BLACK)

	# --- Steering forces ---
	var tangent_dir = Vector3.UP.cross(radial_dir).normalized()
	var forward_dir = -global_transform.basis.z.normalized()
	
	Draw.vector(self.global_position, radial_dir * 100, Color.RED)
	Draw.vector(self.global_position, tangent_dir * 100, Color.GREEN)
	Draw.vector(self.global_position, forward_dir * 100, Color.BLUE)

	# Angle between where we're pointing and where we should point
	var angle_error = forward_dir.angle_to(tangent_dir)

	# Steering force magnitude (tweak gain for responsiveness)
	var steering_strength = 0.00000002
	var steer_force_mag = angle_error * steering_strength

	# Apply opposing forces at front wheels to generate yaw torque
	var front_right_world = global_transform.origin + global_transform.basis * corner_offsets[2]
	var front_left_world  = global_transform.origin + global_transform.basis * corner_offsets[3]
	DebugDraw2D.set_text("angle_error: ", Format.round_place(angle_error, 2))

	var steer_right_force = global_transform.basis.x * steer_force_mag
	var steer_left_force  = global_transform.basis.x * steer_force_mag

	apply_force(steer_right_force, front_right_world - global_position)
	DebugDraw2D.set_text("steer_right_force: ", Format.vec3(steer_right_force))
	Draw.vector(front_right_world, steer_right_force * 10000, Color.CORNFLOWER_BLUE)
	apply_force(steer_left_force,  front_left_world - global_position)
	Draw.vector(front_left_world, steer_left_force * 10000, Color.CORNFLOWER_BLUE)
	
	DebugDraw2D.end_text_group()
