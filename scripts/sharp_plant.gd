extends Area3D

signal escaped(obstacle)

var speed := 2.3
var escape_x := -8.0
var floor_y := -2.72

func setup(start_x: float, width: float, height: float, floor_position_y: float, move_speed: float) -> void:
	speed = move_speed
	escape_x = -width * 0.5 - 1.2
	floor_y = floor_position_y
	global_position = Vector3(start_x, floor_y - 0.12, 0.0)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	global_position.x -= speed * delta
	global_position.z = 0.0
	if global_position.x < escape_x:
		escaped.emit(self)

func _on_body_entered(body: Node) -> void:
	if body.has_method("pop"):
		body.pop()
