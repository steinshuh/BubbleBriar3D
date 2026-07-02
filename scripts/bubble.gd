extends CharacterBody3D

signal popped
signal ground_bounced

const GRAVITY := 9.2
const BOUNCE_VELOCITY := 4.2
const FLOOR_BOUNCE := 5.2
const MAX_FALL := -6.5
const POP_ANIMATION_FRAME_COUNT := 8
const POP_ANIMATION_FRAME_TIME := 0.07
const POP_FRAME_SCALE_MULTIPLIER := 1.3

var radius := 0.31
var alive := true
var fixed_x := 0.0
var play_width := 12.8
var play_height := 7.2
var floor_y := -2.72
var pop_animation_time := 0.0
var pop_animation_frame := 0
var pop_animation_playing := false
var normal_sprite_scale := Vector3.ONE

@onready var sprite := $Sprite3D as Sprite3D
@onready var pop_sound := $PopSound as AudioStreamPlayer3D
@onready var breeze_sound := $BreezeSound as AudioStreamPlayer3D

func _ready() -> void:
	var collider := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider and collider.shape is SphereShape3D:
		collider.shape.radius = radius
	normal_sprite_scale = sprite.scale
	sprite.frame = 0
	sprite.scale = normal_sprite_scale

func setup(width: float, height: float, floor_position_y: float) -> void:
	play_width = width
	play_height = height
	floor_y = floor_position_y
	fixed_x = -play_width * 0.5 + play_width * 0.24
	global_position = Vector3(fixed_x, play_height * 0.05, 0.0)
	velocity = Vector3.ZERO
	alive = true
	pop_animation_playing = false
	pop_animation_time = 0.0
	pop_animation_frame = 0
	sprite.frame = 0
	sprite.scale = normal_sprite_scale
	sprite.modulate.a = 0.7

func _physics_process(delta: float) -> void:
	if not alive:
		_advance_pop_animation(delta)
		velocity.y = max(velocity.y - GRAVITY * delta, MAX_FALL)
		move_and_slide()
		global_position.x = fixed_x
		global_position.z = 0.0
		return

	if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
		velocity.y = BOUNCE_VELOCITY
		breeze_sound.stop()
		breeze_sound.play()

	velocity.y = max(velocity.y - GRAVITY * delta, MAX_FALL)
	move_and_slide()
	global_position.x = fixed_x
	global_position.z = 0.0

	if global_position.y - radius < floor_y:
		global_position.y = floor_y + radius
		velocity.y = FLOOR_BOUNCE
		ground_bounced.emit()

	var ceiling_y := play_height * 0.5
	if global_position.y + radius > ceiling_y:
		global_position.y = ceiling_y - radius
		velocity.y = -0.9

func pop() -> void:
	if not alive:
		return
	alive = false
	velocity.y *= 0.5
	velocity.x = 0.0
	velocity.z = 0.0
	sprite.modulate.a = 0.7
	pop_animation_playing = true
	pop_animation_time = 0.0
	pop_animation_frame = 0
	_apply_pop_frame_visuals()
	pop_sound.stop()
	pop_sound.play()
	popped.emit()

func _advance_pop_animation(delta: float) -> void:
	if not pop_animation_playing:
		return
	pop_animation_time += delta
	while pop_animation_time >= POP_ANIMATION_FRAME_TIME and pop_animation_playing:
		pop_animation_time -= POP_ANIMATION_FRAME_TIME
		if pop_animation_frame < POP_ANIMATION_FRAME_COUNT - 1:
			pop_animation_frame += 1
			_apply_pop_frame_visuals()
		else:
			pop_animation_playing = false

func _apply_pop_frame_visuals() -> void:
	sprite.frame = pop_animation_frame
	var scale_factor: float = pow(POP_FRAME_SCALE_MULTIPLIER, pop_animation_frame)
	sprite.scale = normal_sprite_scale * scale_factor
