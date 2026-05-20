extends Node3D

@export var rotation_speed := 90.0
@export var move_speed := 14.0
@export var zoom_speed := 8.0

@export var min_zoom := 8.0
@export var max_zoom := 30.0

@onready var camera_pivot := $CameraPitch
@onready var camera: Camera3D = (
	$CameraPitch/Camera3D
)


func _ready():

	camera.projection = (
		Camera3D.PROJECTION_ORTHOGONAL
	)

	camera.size = 14.0

	camera_pivot.rotation_degrees.x = -55.0

	camera.position = Vector3(
		0,
		0,
		20
	)


func _process(delta):
	_handle_rotation(delta)
	_handle_movement(delta)


func _handle_rotation(delta):

	if Input.is_action_pressed(
		"rotate_left"
	):
		rotation_degrees.y += (
			rotation_speed * delta
		)

	if Input.is_action_pressed(
		"rotate_right"
	):
		rotation_degrees.y -= (
			rotation_speed * delta
		)


func _handle_movement(delta):

	var input_vector := Vector3.ZERO

	if Input.is_action_pressed("move_up"):
		input_vector.z += 1

	if Input.is_action_pressed("move_down"):
		input_vector.z -= 1

	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1

	if Input.is_action_pressed("move_right"):
		input_vector.x += 1

	if input_vector == Vector3.ZERO:
		return

	input_vector = input_vector.normalized()

	var forward := -transform.basis.z
	var right := transform.basis.x

	var move_direction := (
		(right * input_vector.x)
		+
		(forward * input_vector.z)
	)

	move_direction.y = 0

	global_position += (
		move_direction.normalized()
		*
		move_speed
		*
		delta
	)


func _unhandled_input(event):

	if event.is_action_pressed(
		"zoom_in"
	):
		camera.size -= zoom_speed

	if event.is_action_pressed(
		"zoom_out"
	):
		camera.size += zoom_speed

	camera.size = clamp(
		camera.size,
		min_zoom,
		max_zoom
	)


func focus_on_unit(unit: UnitBase):

	if not unit:
		return

	var target_position := (
		unit.global_position
	)

	target_position.y = global_position.y

	var tween := create_tween()

	tween.tween_property(
		self,
		"global_position",
		target_position,
		0.4
	).set_trans(
		Tween.TRANS_SINE
	).set_ease(
		Tween.EASE_OUT
	)
