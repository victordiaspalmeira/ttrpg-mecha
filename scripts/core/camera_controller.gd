extends Node3D

@onready var grid_manager := %GridManager

@export var rotation_speed := 90.0
@export var move_speed := 12.0
@export var zoom_speed := 4.0

@export var min_zoom := 8.0
@export var max_zoom := 40.0

@onready var camera: Camera3D = (
	$CameraPitch/Camera3D
)

func _ready():

	global_position = (
		grid_manager.global_position
	)


func _process(delta):

	_handle_rotation(delta)
	_handle_movement(delta)
	_handle_zoom(delta)


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
		input_vector.z -= 1

	if Input.is_action_pressed("move_down"):
		input_vector.z += 1

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
	move_direction = move_direction.normalized()

	global_position += (
		move_direction
		*
		move_speed
		*
		delta
	)


func _handle_zoom(delta):

	if Input.is_action_pressed("zoom_in"):
		camera.size -= (
			zoom_speed * delta
		)

	if Input.is_action_pressed("zoom_out"):
		camera.size += (
			zoom_speed * delta
		)

	camera.size = clamp(
		camera.size,
		min_zoom,
		max_zoom
	)