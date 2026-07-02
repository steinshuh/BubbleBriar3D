extends Sprite3D

signal escaped(panel)

var speed := 0.0
var escape_x := -10.0

func setup(texture_resource: Texture2D, start_x: float, y: float, z_distance: float, panel_scale: Vector3, move_speed: float, left_limit: float) -> void:
	texture = texture_resource
	position = Vector3(start_x, y, z_distance)
	scale = panel_scale
	speed = move_speed
	escape_x = left_limit

func _process(delta: float) -> void:
	if speed > 0.0:
		global_position.x -= speed * delta
	if global_position.x < escape_x:
		escaped.emit(self)
