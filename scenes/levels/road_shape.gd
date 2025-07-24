@tool  # Allows the script to run in the editor

extends Path3D

func _ready():
	print("LOADING ROAD SHAPE")
	# Only do this in the editor
	if not Engine.is_editor_hint():
		return
		
	var curve := self.curve
	if not curve:
		return

	for i in curve.get_point_count():
		var in_tangent = curve.get_point_in(i)
		var out_tangent = curve.get_point_out(i)

		# Skip zero-length tangents (nothing to scale)
		if in_tangent.length() > 0.001:
			curve.set_point_in(i, in_tangent.normalized() * 2.0)
		if out_tangent.length() > 0.001:
			curve.set_point_out(i, out_tangent.normalized() * 2.0)

	print("Tangent handles scaled.")
