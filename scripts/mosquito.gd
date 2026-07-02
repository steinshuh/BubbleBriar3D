extends Area3D

signal escaped(obstacle)

const MOSQUITO_ANIMATION_FRAME_COUNT := 8
const MOSQUITO_ANIMATION_FRAME_TIME := 0.08
const MOSQUITO_MAX_VOLUME_DB := -3.0
const MOSQUITO_MIN_VOLUME_DB := -36.0
const MOSQUITO_MAX_AUDIBLE_DISTANCE := 7.2

var speed := 2.3
var escape_x := -8.0
var play_height := 7.2
var bubble_target: Node3D
var animation_time := 0.0
var animation_frame := 0

@onready var sprite := $Sprite3D as Sprite3D
@onready var mosquito_sound := $MosquitoSound as AudioStreamPlayer3D

func setup(start_x: float, width: float, height: float, floor_y: float, move_speed: float) -> void:
	speed = move_speed
	escape_x = -width * 0.5 - 1.2
	play_height = height
	global_position.x = start_x
	global_position.y = randf_range(-height * 0.12, height * 0.26)
	global_position.z = 0.0

func set_bubble_target(target: Node3D) -> void:
	bubble_target = target
	if is_node_ready():
		_update_sound_volume()

func _ready() -> void:
	animation_frame = 0
	sprite.frame = animation_frame
	body_entered.connect(_on_body_entered)
	mosquito_sound.finished.connect(_on_mosquito_sound_finished)
	mosquito_sound.play()
	_update_sound_volume()

func _process(delta: float) -> void:
	_advance_animation(delta)
	global_position.x -= speed * delta
	global_position.z = 0.0
	_update_sound_volume()
	if global_position.x < escape_x:
		escaped.emit(self)

func _advance_animation(delta: float) -> void:
	animation_time += delta
	while animation_time >= MOSQUITO_ANIMATION_FRAME_TIME:
		animation_time -= MOSQUITO_ANIMATION_FRAME_TIME
		animation_frame = (animation_frame + 1) % MOSQUITO_ANIMATION_FRAME_COUNT
		sprite.frame = animation_frame

func _update_sound_volume() -> void:
	if bubble_target == null or not is_instance_valid(bubble_target):
		mosquito_sound.volume_db = MOSQUITO_MIN_VOLUME_DB
		return
	var distance_to_bubble := global_position.distance_to(bubble_target.global_position)
	var closeness := 1.0 - clampf(distance_to_bubble / MOSQUITO_MAX_AUDIBLE_DISTANCE, 0.0, 1.0)
	mosquito_sound.volume_db = lerpf(MOSQUITO_MIN_VOLUME_DB, MOSQUITO_MAX_VOLUME_DB, closeness)

func _on_mosquito_sound_finished() -> void:
	mosquito_sound.play()

func _on_body_entered(body: Node) -> void:
	if body.has_method("pop"):
		body.pop()
