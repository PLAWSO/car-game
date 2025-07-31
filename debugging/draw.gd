extends Node
class_name Draw

static func vector(origin: Vector3, vectorToDraw: Vector3, color: Color):
	DebugDraw3D.draw_arrow_ray(origin, vectorToDraw, 2.5, color, 0.1)

static func ray_cast(ray: RayCast3D):
	ray.force_raycast_update()
	DebugDraw3D.draw_line_hit(ray.global_position, ray.to_global(ray.target_position), ray.get_collision_point(), ray.is_colliding(), 0.3)

static func text_at_position(position: Vector3, text: String, font_size: int = 16, outline: int = 9):
	var _s1 = DebugDraw3D.new_scoped_config().set_text_outline_size(outline)
	DebugDraw3D.draw_text(position, text, font_size)

static func box(position: Vector3, rotation: Quaternion, size: Vector3, color: Color):
		DebugDraw3D.draw_box(position, rotation, size, color, true, 0.001)

static func gui_box(key: String, color: Color):
	DebugDraw2D.set_text(key, "█", 7, color)
