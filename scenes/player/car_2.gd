extends RigidBody3D
class_name Vehicle

@export_category("Car")
@export_group("Wheels")
@export var ray_cast_wheels: Array[RayCastWheel2]
@export_group("Stats")
@export var acceleration := 3000.0
@export var max_speed := 30
@export var accel_curve: Curve
@export var total_wheels := 4

@export_category("Debug")
@export var show_debug := false
@export_group("Text")
@export_range(1, 100) var text_groups_title_font_size := 20
@export_range(1, 100) var text_groups_text_font_size := 17

var motor_input := 0
var hand_brake := false


func _ready():
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


func _physics_process(delta: float) -> void:
	if show_debug:
		draw_debug()
	
	do_wheels_physics(self, delta)


func draw_debug():
	Draw.box(self.global_position + Vector3(0, 0.116, 0), self.quaternion, Vector3(1.885, 1.085, 3.9), Color.AQUA)
	
	DebugDraw2D.begin_text_group("-- Vehicle --", 2, Color.LIME_GREEN, true, text_groups_title_font_size, text_groups_text_font_size)
	DebugDraw2D.set_text("Velocity: ", linear_velocity.length())
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
