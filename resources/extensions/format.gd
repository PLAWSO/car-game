extends Node
class_name Format

static func vec3(vector: Vector3) -> String:
	return str(round_place(vector.x, 2)) + ", " + str(round_place(vector.y, 2)) + ", " + str(round_place(vector.z, 2))

static func round_place(number: float, places: int):
	return round(number * pow(10, places)) / pow(10, places)
