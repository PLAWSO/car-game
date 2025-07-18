extends RigidBody3D

@export var wheels: Array[RaycastWheel]
@export var acceleration := 600.0
@export var max_speed := 20

var motor_input := 0

func _ready():
	for wheel in wheels:
		var start_pos := wheel.position.y + wheel.target_position.y + wheel.wheel_radius
		wheel.wheel_mesh.position.y = start_pos
	
	Engine.time_scale = 0.5

func _unhandled_input(event: InputEvent) -> void:
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

	do_wheel_physics(self, delta)
	
	draw_zone_title_pos(self.global_position, str(self.global_position))


func do_wheel_physics(body: RigidBody3D, delta) -> void:
	for wheel in wheels:
		do_spring_physics(wheel)
		do_wheel_acceleration(wheel)

func do_wheel_acceleration(ray: RaycastWheel) -> void:
	var forward_dir := -ray.global_basis.z
	var vel := forward_dir.dot(linear_velocity)
	
	ray.wheel_mesh.rotate_x(-vel * get_process_delta_time() * 2 * PI * ray.wheel_radius)
	
	if ray.is_colliding() and ray.is_motor and motor_input:
		
		var contact := ray.wheel_mesh.global_position
		var force_vector := forward_dir * acceleration * motor_input
		var force_pos := contact - global_position
		
		if vel > max_speed:
			force_vector = force_vector * 0.1
		
		## applies force parallel with vehicle forward axis
		#apply_force(force_vector, force_pos)
		#DebugDraw3D.draw_arrow_ray(contact, force_vector / mass, 2.5, Color.CRIMSON, 0.5)
		
		## applies force parallel with world forward axis
		var projected_vector: Vector3 = (force_vector - ray.get_collision_normal() * force_vector.dot(ray.get_collision_normal()))
		apply_force(projected_vector, force_pos)
		DebugDraw3D.draw_arrow_ray(contact, projected_vector / mass, 2.5, Color.CRIMSON, 0.5)
		


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
		
		var force_vector := (spring_force - spring_damp_force) * spring_up_direction
		
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
