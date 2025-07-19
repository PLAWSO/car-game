extends RigidBody3D

@export var wheels: Array[RaycastWheel]
@export var acceleration := 3000.0
#@export var deceleration := 200
@export var max_speed := 30
@export var accel_curve: Curve
@export var tire_turn_speed := 2.0
@export var tire_max_turn_degrees := 25

@export_range(1, 100) var text_groups_title_font_size := 20
@export_range(1, 100) var text_groups_text_font_size := 17

var motor_input := 0
var hand_brake := false

func _ready():
	#linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	#linear_damp = 0
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.DOWN * 0.5
	
	reset()
	
	#Engine.time_scale = 0.5


func reset():
	for wheel in wheels:
		var start_pos := wheel.position.y + wheel.target_position.y + wheel.wheel_radius
		wheel.wheel_mesh.position.y = start_pos
	
	global_position = Vector3(0, 10, 0)
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("drift"):
		hand_brake = true
	if event.is_action_released("drift"):
		hand_brake = false
	if event.is_action_pressed("accelerate"):
		motor_input = 1
	elif event.is_action_released("accelerate"):
		motor_input = 0
		
	if event.is_action_pressed("decelerate"):
		motor_input = -1
	elif event.is_action_released("decelerate"):
		motor_input = 0

func _physics_process(delta: float) -> void:
	
	DebugDraw3D.draw_box(self.global_position + Vector3(0, 0.116, 0), self.quaternion, Vector3(1.885, 1.085, 3.9), Color.AQUA, true, 0.016)
	
	DebugDraw2D.begin_text_group("-- Vehicle --", 2, Color.LIME_GREEN, true, text_groups_title_font_size, text_groups_text_font_size)
	DebugDraw2D.set_text("Velocity: ", linear_velocity.length())
	DebugDraw2D.end_text_group()
	
	do_wheel_physics(self, delta)
	
	draw_zone_title_pos(self.global_position, str(self.global_position))


func do_wheel_physics(body: RigidBody3D, delta: float) -> void:
	#var grounded:= false
	for wheel in wheels:
		#if wheel.is_colliding():
			#grounded = true
		wheel.force_raycast_update()
		do_spring_physics(wheel)
		do_wheel_acceleration(wheel, delta)
		do_steering_rotation(delta)
		do_wheel_traction(wheel, delta)
	
	## reorient vehicle
	#if grounded:
		#center_of_mass = Vector3.ZERO
	#else:
		#center_of_mass = Vector3.DOWN * 0.5

func do_wheel_traction(ray: RaycastWheel, delta: float) -> void:
	if not ray.is_colliding(): return
	
	var steer_side_dir := ray.global_basis.x
	var tire_vel := get_point_velocity(ray.wheel_mesh.global_position)
	var steering_x_vel := steer_side_dir.dot(tire_vel)
	
	var grip_factor := absf(steering_x_vel / tire_vel.length())
	var x_traction := ray.grip_curve.sample_baked(grip_factor)
	
	if hand_brake:
		x_traction = 0.1
	
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var force_pos := ray.wheel_mesh.global_position - global_position
	
	##
	## Z FORCE TRACTION
	##
	
	var f_vel := -ray.global_basis.z.dot(tire_vel)
	var z_traction := 0.5
	var z_force := global_basis.z * f_vel * z_traction * ((mass * gravity)/4.0)
	apply_force(z_force, force_pos)
	DebugDraw3D.draw_arrow_ray(ray.wheel_mesh.global_position, z_force / mass, 2.5, Color.SEA_GREEN, 0.5)
	
	
	##
	## X FORCE TRACTION
	##
	
	## alternate way to calculate force??
	#var x_force := -steer_side_dir * steering_x_vel * x_traction * ((mass * gravity) / 4.0)
	
	var desired_acceleration := (steering_x_vel * x_traction) / delta
	var x_force := -steer_side_dir * desired_acceleration * (mass / 4)
	
	## different way to apply force? seems broken
	#var x_force := -global_basis.x * desired_acceleration * (mass / 4)
	
	apply_force(x_force, force_pos)
	DebugDraw3D.draw_arrow_ray(ray.wheel_mesh.global_position, x_force / mass, 2.5, Color.SEA_GREEN, 0.5)


func do_steering_rotation(delta: float) -> void:
	var turn_input := Input.get_axis("turn_right", "turn_left") * tire_turn_speed
	
	if turn_input:
		$DF_Wheel.rotation.y = clampf($PF_Wheel.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
		$PF_Wheel.rotation.y = clampf($PF_Wheel.rotation.y + turn_input * delta,
			deg_to_rad(-tire_max_turn_degrees), deg_to_rad(tire_max_turn_degrees))
	else:
		$DF_Wheel.rotation.y = move_toward($DF_Wheel.rotation.y, 0, tire_turn_speed * delta)
		$PF_Wheel.rotation.y = move_toward($PF_Wheel.rotation.y, 0, tire_turn_speed * delta)

func do_wheel_acceleration(ray: RaycastWheel, delta) -> void:
	var forward_dir := -ray.global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	
	ray.wheel_mesh.rotate_x((-vel * delta) / ray.wheel_radius)
	
	if ray.is_colliding():
		var contact := ray.wheel_mesh.global_position
		var force_pos := contact - global_position
		
		## apply motor acceleration
		if ray.is_motor and not motor_input == 0:
			var speed_ratio := vel / max_speed
			var ac := accel_curve.sample_baked(speed_ratio)
			var force_vector := forward_dir * acceleration * motor_input * ac
			var projected_vector: Vector3 = (force_vector - ray.get_collision_normal() * force_vector.dot(ray.get_collision_normal()))
			apply_force(projected_vector, force_pos)
			DebugDraw3D.draw_arrow_ray(contact, projected_vector / mass, 2.5, Color.CRIMSON, 0.5)
		
		
		## older method of manually applying wheel drag
		## apply wheel drag
		#if abs(vel) > 0.2:
			#var drag_force_vector = global_basis.z * deceleration * signf(vel)
			#apply_force(drag_force_vector, force_pos)
			#DebugDraw3D.draw_arrow_ray(contact, drag_force_vector / mass, 2.5, Color.CRIMSON, 0.5)
		## bring car to stop
		#elif abs(vel) < 0.3:
			#linear_velocity = Vector3.ZERO
			#angular_velocity = Vector3.ZERO
		
		## applies force parallel with vehicle forward axis
		#apply_force(force_vector, force_pos)
		#DebugDraw3D.draw_arrow_ray(contact, force_vector / mass, 2.5, Color.CRIMSON, 0.5)
		
		## applies force parallel with world forward axis
		#var projected_vector: Vector3 = (force_vector - ray.get_collision_normal() * force_vector.dot(ray.get_collision_normal()))
		#apply_force(projected_vector, force_pos)
		#DebugDraw3D.draw_arrow_ray(contact, projected_vector / mass, 2.5, Color.CRIMSON, 0.5)
		


func do_spring_physics(ray: RaycastWheel):
	if ray.is_colliding():
		ray.target_position.y = -(ray.rest_dist + ray.wheel_radius + ray.over_extend)
		var contact := ray.get_collision_point()
		var spring_up_direction := ray.global_transform.basis.y
		var spring_len := ray.global_position.distance_to(contact) - ray.wheel_radius
		var offset := ray.rest_dist - spring_len
		
		ray.wheel_mesh.position.y = -spring_len
		
		var spring_force := ray.spring_strength * offset
		
		var world_vel := get_point_velocity(contact)
		var relative_vel := spring_up_direction.dot(world_vel)
		var spring_damp_force := ray.spring_damping * relative_vel
		
		#if (spring_force - spring_damp_force < 0):
			#return
		
		## apply spring force towards car up
		#var force_vector := (spring_force - spring_damp_force) * spring_up_direction
		
		## apply spring force normal to ground
		var force_vector := (spring_force - spring_damp_force) * ray.get_collision_normal()
		
		contact = ray.wheel_mesh.global_position
		var force_pos_offset := contact - global_position
		apply_force(force_vector, force_pos_offset)
		
		DebugDraw3D.draw_arrow_ray(contact, force_vector / mass, 2.5, Color.AQUAMARINE, 0.5)


func draw_ray(ray: RayCast3D):
	ray.force_raycast_update()
	DebugDraw3D.draw_line_hit(ray.global_position, ray.to_global(ray.target_position), ray.get_collision_point(), ray.is_colliding(), 0.3)


func draw_zone_title_pos(pos: Vector3, title: String, font_size: int = 16, outline: int = 9):
	var _s1 = DebugDraw3D.new_scoped_config().set_text_outline_size(outline)
	DebugDraw3D.draw_text(pos, title, font_size)


func get_point_velocity(point: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(point - global_transform.origin)


func _on_fall_zone_body_entered(body: Node3D) -> void:
	reset()
