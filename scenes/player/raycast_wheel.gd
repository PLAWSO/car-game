extends RayCast3D
class_name RaycastWheel

@export var spring_strength := 5000
@export var spring_damping := 120
@export var rest_dist := 0.175
@export var over_extend := 0.2
@export var wheel_radius := 0.3
@export var is_motor := false

@onready var wheel_mesh: Node3D = get_parent().get_node("mesh")
