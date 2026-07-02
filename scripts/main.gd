extends Node3D

const SceneryPanel := preload("res://scripts/scenery_panel.gd")
const MosquitoScene := preload("res://scenes/Mosquito.tscn")
const SharpPlantScene := preload("res://scenes/SharpPlant.tscn")

const SKY_TEXTURE := preload("res://assets/sky_mountains.png")
const FAR_HILLS_TEXTURE := preload("res://assets/far_hills.png")
const NEAR_TREES_TEXTURE := preload("res://assets/near_trees.png")
const GROUND_TEXTURE := preload("res://assets/ground.png")
const TITLE_TEXTURE := preload("res://assets/title.png")

const TITLE_OVERLAY_SECONDS := 5.0
const PLAY_HEIGHT := 7.2
const BASE_SCROLL_SPEED := 2.45
const RATE_ADJUST_ACCEL := 3.6
const RATE_ADJUST_RETURN := 2.2
const MAX_SPEED_BONUS := 2.2
const MAX_SPEED_PENALTY := -1.5
const SPAWN_MIN := 1.05
const SPAWN_MAX := 1.72

@onready var bubble := $Bubble as CharacterBody3D
@onready var camera := $Camera3D as Camera3D
@onready var background_music_1 := $BackgroundMusic1 as AudioStreamPlayer
@onready var background_music_2 := $BackgroundMusic2 as AudioStreamPlayer
@onready var point_sound := $PointSound as AudioStreamPlayer

var play_width := 12.8
var floor_y := -2.72
var current_scroll_speed := BASE_SCROLL_SPEED
var speed_adjustment := 0.0
var spawn_timer := 0.0
var score := 0
var best_score := 0
var game_over := false
var obstacles: Array[Area3D] = []
var scenery_panels: Array[Sprite3D] = []
var scenery_spawn_x := {}
var current_background_music_index := 0

var score_label: Label
var prompt_label: Label
var prompt_timer: Timer
var title_overlay: CanvasLayer
var title_image: TextureRect
var title_timer: Timer

func _ready() -> void:
	randomize()
	_update_world_bounds()
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_build_scenery()
	_build_ui()
	_build_title_overlay()
	_show_title_overlay()
	_start_background_music()
	bubble.popped.connect(_on_bubble_popped)
	bubble.ground_bounced.connect(_on_bubble_ground_bounced)
	_start_run()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_runtime_resources()

func _exit_tree() -> void:
	_cleanup_runtime_resources()

func _process(delta: float) -> void:
	if game_over:
		if Input.is_action_just_pressed("bounce") or Input.is_action_just_pressed("ui_accept"):
			_start_run()
		return

	_update_scroll_speed(delta)
	_update_scenery_spawns()
	spawn_timer -= delta * (current_scroll_speed / BASE_SCROLL_SPEED)
	if spawn_timer <= 0.0:
		_spawn_obstacle()
		spawn_timer = randf_range(SPAWN_MIN, SPAWN_MAX)

func _update_world_bounds() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	play_width = PLAY_HEIGHT * aspect
	floor_y = -PLAY_HEIGHT * 0.5 + 0.88
	camera.size = PLAY_HEIGHT

func _build_scenery() -> void:
	scenery_spawn_x.clear()
	for data in _scenery_specs():
		scenery_spawn_x[data["name"]] = -INF
		for index in range(data["initial_count"]):
			_spawn_scenery_panel(data, index * data["spacing"])

func _scenery_specs() -> Array[Dictionary]:
	return [
		{"name": "sky", "texture": SKY_TEXTURE, "z": -9.0, "y": 0.0, "speed_factor": 0.0, "spacing": play_width, "initial_count": 1},
		{"name": "hills", "texture": FAR_HILLS_TEXTURE, "z": -6.0, "y": -0.05, "speed_factor": 0.22, "spacing": play_width, "initial_count": 3},
		{"name": "trees", "texture": NEAR_TREES_TEXTURE, "z": -3.0, "y": -0.88, "speed_factor": 0.55, "spacing": play_width, "initial_count": 3},
		{"name": "ground", "texture": GROUND_TEXTURE, "z": -0.8, "y": -1.25, "speed_factor": 1.0, "spacing": play_width, "initial_count": 3},
	]

func _spawn_scenery_panel(spec: Dictionary, x: float) -> void:
	var panel := SceneryPanel.new()
	panel.texture_filter = 0
	panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var speed := current_scroll_speed * float(spec["speed_factor"])
	var left_limit := -play_width * 0.5 - float(spec["spacing"])
	panel.setup(spec["texture"], x, spec["y"], spec["z"], play_width, PLAY_HEIGHT, speed, left_limit)
	panel.escaped.connect(_on_scenery_panel_escaped)
	scenery_panels.append(panel)
	add_child(panel)
	scenery_spawn_x[spec["name"]] = maxf(float(scenery_spawn_x.get(spec["name"], -INF)), x)

func _update_scenery_spawns() -> void:
	for panel in scenery_panels:
		var spec := _spec_for_panel(panel)
		if spec.is_empty():
			continue
		panel.speed = current_scroll_speed * float(spec["speed_factor"])

	for spec in _scenery_specs():
		if float(spec["speed_factor"]) <= 0.0:
			continue
		var last_x := float(scenery_spawn_x.get(spec["name"], -INF))
		if last_x < play_width * 0.5 + float(spec["spacing"]):
			_spawn_scenery_panel(spec, last_x + float(spec["spacing"]))

func _spec_for_panel(panel: Sprite3D) -> Dictionary:
	for spec in _scenery_specs():
		if panel.texture == spec["texture"] and is_equal_approx(panel.global_position.z, spec["z"]):
			return spec
	return {}

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)

	score_label = Label.new()
	score_label.position = Vector2(28, 22)
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color("#17324d"))
	score_label.text = "Score 0"
	ui.add_child(score_label)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 30)
	prompt_label.add_theme_color_override("font_color", Color("#17324d"))
	_update_prompt_layout()
	ui.add_child(prompt_label)

func _build_title_overlay() -> void:
	title_overlay = CanvasLayer.new()
	title_overlay.layer = 100
	add_child(title_overlay)

	title_image = TextureRect.new()
	title_image.texture = TITLE_TEXTURE
	title_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_update_title_image_layout()
	title_overlay.add_child(title_image)

func _show_title_overlay() -> void:
	title_overlay.visible = true
	if title_timer:
		title_timer.stop()
		title_timer.queue_free()
	title_timer = Timer.new()
	title_timer.one_shot = true
	title_timer.wait_time = TITLE_OVERLAY_SECONDS
	title_timer.timeout.connect(_hide_title_overlay)
	add_child(title_timer)
	title_timer.start()

func _hide_title_overlay() -> void:
	title_overlay.visible = false
	if title_timer:
		title_timer.queue_free()
		title_timer = null

func _start_background_music() -> void:
	if not background_music_1.finished.is_connected(_on_background_music_finished):
		background_music_1.finished.connect(_on_background_music_finished)
	if not background_music_2.finished.is_connected(_on_background_music_finished):
		background_music_2.finished.connect(_on_background_music_finished)
	current_background_music_index = 0
	_play_current_background_music()

func _play_current_background_music() -> void:
	background_music_1.stop()
	background_music_2.stop()
	if current_background_music_index == 0:
		background_music_1.play()
	else:
		background_music_2.play()

func _on_background_music_finished() -> void:
	current_background_music_index = 1 - current_background_music_index
	_play_current_background_music()

func _start_run() -> void:
	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()
	score = 0
	game_over = false
	speed_adjustment = 0.0
	current_scroll_speed = BASE_SCROLL_SPEED
	spawn_timer = 0.7
	score_label.text = "Score 0"
	prompt_label.text = "Space/Up/click bounce\nRight/D speed up, Left/A slow down"
	bubble.call("setup", play_width, PLAY_HEIGHT, floor_y)
	_start_prompt_timer()

func _start_prompt_timer() -> void:
	if prompt_timer:
		prompt_timer.stop()
		prompt_timer.queue_free()
	prompt_timer = Timer.new()
	prompt_timer.one_shot = true
	prompt_timer.wait_time = 1.6
	prompt_timer.timeout.connect(_hide_start_prompt)
	add_child(prompt_timer)
	prompt_timer.start()

func _hide_start_prompt() -> void:
	if not game_over:
		prompt_label.text = ""
	if prompt_timer:
		prompt_timer.queue_free()
		prompt_timer = null

func _update_scroll_speed(delta: float) -> void:
	var input_direction := 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		input_direction += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		input_direction -= 1.0
	if input_direction != 0.0:
		speed_adjustment += input_direction * RATE_ADJUST_ACCEL * delta
	else:
		speed_adjustment = move_toward(speed_adjustment, 0.0, RATE_ADJUST_RETURN * delta)
	speed_adjustment = clamp(speed_adjustment, MAX_SPEED_PENALTY, MAX_SPEED_BONUS)
	current_scroll_speed = BASE_SCROLL_SPEED + speed_adjustment
	for obstacle in obstacles:
		obstacle.set("speed", current_scroll_speed)

func _spawn_obstacle() -> void:
	var obstacle_scene := SharpPlantScene if randf() < 0.58 else MosquitoScene
	var obstacle := obstacle_scene.instantiate() as Area3D
	var start_x := play_width * 0.5 + 0.9
	obstacle.call("setup", start_x, play_width, PLAY_HEIGHT, floor_y, current_scroll_speed)
	if obstacle.has_method("set_bubble_target"):
		obstacle.call("set_bubble_target", bubble)
	obstacle.escaped.connect(_on_obstacle_escaped)
	obstacles.append(obstacle)
	add_child(obstacle)

func _on_bubble_ground_bounced() -> void:
	if game_over:
		return
	score += 1
	point_sound.stop()
	point_sound.play()
	score_label.text = "Score %d" % score

func _on_obstacle_escaped(obstacle: Area3D) -> void:
	obstacles.erase(obstacle)
	obstacle.queue_free()

func _on_scenery_panel_escaped(panel: Sprite3D) -> void:
	scenery_panels.erase(panel)
	panel.queue_free()

func _on_bubble_popped() -> void:
	game_over = true
	best_score = max(best_score, score)
	prompt_label.text = "Bubble popped\nScore %d  Best %d\nPress Space, Up, or click" % [score, best_score]

func _on_viewport_size_changed() -> void:
	_update_world_bounds()
	if bubble:
		bubble.call("setup", play_width, PLAY_HEIGHT, floor_y)
	_update_prompt_layout()
	_update_title_image_layout()

func _update_prompt_layout() -> void:
	if prompt_label == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	prompt_label.size = Vector2(viewport_size.x, 120)
	prompt_label.position = Vector2(0, viewport_size.y * 0.34)

func _update_title_image_layout() -> void:
	if title_image == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	title_image.size = viewport_size * 0.5
	title_image.position = (viewport_size - title_image.size) * 0.5

func _cleanup_runtime_resources() -> void:
	if is_instance_valid(background_music_1):
		background_music_1.stop()
		background_music_1.stream = null
	if is_instance_valid(background_music_2):
		background_music_2.stop()
		background_music_2.stream = null
	if is_instance_valid(point_sound):
		point_sound.stop()
		point_sound.stream = null
	if is_instance_valid(title_timer):
		title_timer.stop()
		title_timer.queue_free()
		title_timer = null
	if is_instance_valid(prompt_timer):
		prompt_timer.stop()
		prompt_timer.queue_free()
		prompt_timer = null
