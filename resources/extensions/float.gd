extends Node
class_name Float

static func is_valid(value: float) -> bool:
	return !is_nan(value) and is_finite(value)
