extends Sprite3D

signal escaped(panel)

var speed := 0.0
var escape_x := -10.0

func setup(texture_resource: Texture2D, start_x: float, y: float, z_distance: float, target_width: float, target_height: float, move_speed: float, left_limit: float) -> void:
	render_priority = -100
	alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	texture = texture_resource
	position = Vector3(start_x, y, z_distance)
	var width_scale := target_width / maxf(float(texture_resource.get_width()), 1.0)
	var height_scale := target_height / maxf(float(texture_resource.get_height()), 1.0)
	pixel_size = maxf(width_scale, height_scale)
	scale = Vector3.ONE
	speed = move_speed
	escape_x = left_limit

func _process(delta: float) -> void:
	if speed > 0.0:
		global_position.x -= speed * delta
	if global_position.x < escape_x:
		escaped.emit(self)
