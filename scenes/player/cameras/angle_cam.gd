extends Camera3D

@export var distance := 6.0
@export var height := 3.0
@export var camera_sensitivity := 0.001

#@onready var target: Node3D = get_parent().get_parent()
@onready var pivot: Node3D = get_parent()
@onready var player: RigidBody3D = pivot.get_parent()

func _init() -> void:
	top_level = false


#func _input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#top_level = false
		#get_parent().rotate_y(-event.relative.x * camera_sensitivity)
		##get_parent().rotate_z(-event.relative.y * camera_sensitivity)
		#top_level = true
		#
#
func _physics_process(delta: float) -> void:
	# match pivot position to player position (pivot is set as top-level to ignore rotation of player)
	pivot.global_position = player.global_position
	
	# get player horizontal velocity
	var player_velocity = player.linear_velocity
	var horizontal_velocity = Vector2(player_velocity.x, player_velocity.z)
	
	# return if player velocity is close to zero
	if horizontal_velocity.length() < 0.1:
		return
	
	# set top-down angle of pivot
	#var direction = Vector3(player_velocity.x, 0, player_velocity.z).normalized()
	#pivot.look_at(pivot.global_position + direction, Vector3.UP)
	var current_position := -pivot.global_transform.basis.z.normalized()
	var target_position := Vector3(player_velocity.x, 0, player_velocity.z).normalized()
	
	var direction = lerp(current_position, target_position, 1.0 - exp(-10 * delta))
	pivot.look_at(pivot.global_position + direction, Vector3.UP)
	
	#var current_basis = pivot.global_transform.basis
	#var t = 1.0 - exp(-1000000 * delta)
	#pivot.global_transform.basis = current_basis.slerp(target_basis, t)
	#pivot.look_at(lerp(pivot.basis.looking_at(), pivot.global_position + direction, 1.0 - exp(-100 * delta)), Vector3.UP)
	
	
	# convert local offset to world space:
	#var local_offset = Vector3(0, 3, 5)
	#var world_offset = player.global_transform.basis * local_offset
	#pivot.global_position = player.global_position + world_offset
	
	# set camera "look at" position (in front of player)
	#var local_look_at_offset = Vector3(0, 1, -3)
	#var world_look_at_offset = player.global_transform.basis * local_look_at_offset
	#look_at_from_position(global_position, player.global_position + world_look_at_offset, Vector3.UP)

#func _physics_process(delta: float) -> void:
	#var distance_from_target := global_position - target.global_position
	#
	#if distance_from_target.length() < min_distance:
		#distance_from_target = distance_from_target.normalized() * min_distance
	#elif distance_from_target.length() > max_distance:
		#distance_from_target = distance_from_target.normalized() * max_distance
	#
	#distance_from_target.y = height
	#global_position = target.global_position + distance_from_target
	#
	#var look_dir := global_position.direction_to(target.global_position).abs() - Vector3.UP
	#if not look_dir.is_zero_approx():
		#look_at_from_position(global_position, target.global_position, Vector3.UP)
