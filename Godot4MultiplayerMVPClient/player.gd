extends CharacterBody3D

@export var speed = 5.0
@export var jump_velocity = 4.5
@export var mouse_sensitivity = 0.003

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var camera = $Camera3D

var peer_id = 0

# Interpolation targets for remote players
var target_position: Vector3 = Vector3.ZERO
var target_rotation: Quaternion = Quaternion()

func _ready():
	peer_id = name.to_int()
	
	if peer_id == 0 or peer_id == multiplayer.get_unique_id():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false
		target_position = global_position
		target_rotation = global_transform.basis.get_rotation_quaternion()

func _unhandled_input(event):
	if peer_id != 0 and peer_id != multiplayer.get_unique_id():
		return
		
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if mouse_sensitivity == null:
			mouse_sensitivity = 0.003
			
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	# Safety fallback for variables
	if speed == null:
		speed = 5.0

	# CASE A: Local Player
	if peer_id == 0 or peer_id == multiplayer.get_unique_id():
		if not is_on_floor():
			velocity.y -= gravity * delta

		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = jump_velocity

		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)

		move_and_slide()

		# Send transform up to the Networking root node
		var main_node = get_node_or_null("/root/Networking")
		if main_node and main_node.has_method("send_my_transform"):
			main_node.send_my_transform(global_position, global_rotation)
			
	# CASE B: Remote Player (Smooth interpolation)
	else:
		global_position = global_position.lerp(target_position, delta * 20.0)
		var current_quat = global_transform.basis.get_rotation_quaternion()
		var new_quat = current_quat.slerp(target_rotation, delta * 20.0)
		global_transform.basis = Basis(new_quat)

# Called by Networking.gd when a packet arrives for this player
func update_remote_transform(pos: Vector3, rot: Vector3):
	target_position = pos
	target_rotation = Quaternion.from_euler(rot)
