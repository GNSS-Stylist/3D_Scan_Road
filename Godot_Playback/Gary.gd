extends KinematicBody

var camera_angle_y_unfiltered:float = 0
var camera_angle_x_unfiltered:float = 0
var camera_angle_y_filtered:float = 0
var camera_angle_x_filtered:float = 0

# Use values like 0.01 for the next to smoothen camera angle changes more.
# This makes turning less responsive, but maybe easier to follow
# when creating videos etc.
const camera_angle_filter_coeff:float = 0.01	#0.01
#const camera_angle_filter_coeff:float = 0.001	#0.01

const mouse_sensitivity = 0.15
var camera_change = Vector2()

var velocity = Vector3()
var direction = Vector3()
var velocityMultiplier = 0.5

#fly variables
const FLY_SPEED = 20
const FLY_ACCEL = 2

var mouse_captured = false

func _ready():
	var manipulator = get_node("ManipulatorCollisionShape")
	var capsule = get_node("Capsule")
	var manipulatorMeshes = get_node("ManipulatorMeshes")

	manipulator.disabled = true
	manipulator.visible = true
	capsule.disabled = true
	manipulatorMeshes.visible = false

	var rmbManipulator = get_node("RMBManipulatorCollisionShape")
	var rmbManipulatorMeshes = get_node("RMBManipulatorMeshes")
	rmbManipulator.disabled = true
	rmbManipulator.visible = true
	rmbManipulatorMeshes.visible = false

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):

#	camSwitch()

	var manipulator = get_node("ManipulatorCollisionShape")
	var capsule = get_node("Capsule")
	var manipulatorMeshes = get_node("ManipulatorMeshes")
	var rmbManipulator = get_node("RMBManipulatorCollisionShape")
	var rmbManipulatorMeshes = get_node("RMBManipulatorMeshes")

	if Input.is_action_just_pressed('toggle_mouse'):
		if mouse_captured:
			mouse_captured = false
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			mouse_captured = true
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# This is outside the mouse_captured-branch below to keep flying speed
	# identical between both first persons (in world and van-coordinates)
	handleFlyingSpeed()

	if mouse_captured and !(get_node("Head/FirstPersonCamera").current):
		# Do not react if camera is not in use
		# (There are two instances of this class)
		manipulator.disabled = true
#			manipulator.visible = true
		capsule.disabled = true
		manipulatorMeshes.visible = false
		rmbManipulator.disabled = true
#			rmbManipulator.visible = true
		rmbManipulatorMeshes.visible = false

		# Prevent annoying movements when changing to this camera due to remembering some old values
		camera_angle_y_unfiltered = camera_angle_y_filtered
		camera_angle_x_unfiltered = camera_angle_x_filtered
		direction = Vector3()
		velocity = Vector3()
		camera_change = Vector2()

		return

	if mouse_captured:
		aim(delta)
		fly(delta)

		if Input.is_action_just_pressed("mouse_left"):
			manipulator.disabled = false
#			manipulator.visible = false
			capsule.disabled = false
			manipulatorMeshes.visible = true
		if Input.is_action_just_released("mouse_left"):
			manipulator.disabled = true
#			manipulator.visible = true
			capsule.disabled = true
			manipulatorMeshes.visible = false

		if Input.is_action_just_pressed("mouse_right"):
			rmbManipulator.disabled = false
#			rmbManipulator.visible = false
			rmbManipulatorMeshes.visible = true
		if Input.is_action_just_released("mouse_right"):
			rmbManipulator.disabled = true
#			rmbManipulator.visible = true
			rmbManipulatorMeshes.visible = false

func _input(event):
	if event is InputEventMouseMotion:
		camera_change = event.relative

func fly(delta):
	# reset the direction of the player
	direction = Vector3()
	
	# get the rotation of the camera
	var aim = $Head/FirstPersonCamera.get_global_transform().basis
	
	# check input and change direction
	if Input.is_action_pressed("move_forward"):
		direction -= aim.z
	if Input.is_action_pressed("move_backward"):
		direction += aim.z
	if Input.is_action_pressed("move_left"):
		direction -= aim.x
	if Input.is_action_pressed("move_right"):
		direction += aim.x
	if Input.is_action_pressed("move_up"):
		direction += aim.y
	if Input.is_action_pressed("move_down"):
		direction -= aim.y

	if Input.is_action_just_pressed("create_new_box"):
		var rootNode = get_node("/root")
		var boxScene = load("res://BasicCube.tscn")
		var box = boxScene.instance()
		box.transform = get_node("ManipulatorMeshes/ManipulatorExtension").global_transform
		rootNode.add_child(box)
	
	# where would the player go at max speed
	var target = direction * FLY_SPEED
	
	# calculate a portion of the distance to go
	velocity = velocity.linear_interpolate(target, FLY_ACCEL * delta)
	
	# move
	var _discard = move_and_slide(velocity * velocityMultiplier)

func handleFlyingSpeed():
	if (velocityMultiplier > 0.01):
		if Input.is_action_pressed("movement_speed_down"):
			velocityMultiplier /= 1.02
		if Input.is_action_just_released("movement_speed_down_mousewheel"):
			velocityMultiplier /= 1.1

	if (velocityMultiplier < 10):
		if Input.is_action_pressed("movement_speed_up"):
			velocityMultiplier *= 1.02
		if Input.is_action_just_released("movement_speed_up_mousewheel"):
			velocityMultiplier *= 1.1

	velocityMultiplier = clamp(velocityMultiplier, 0.01, 10)

func aim(delta):
	if camera_change.length() > 0:
#		$Head.rotate_y(deg2rad(-camera_change.x * mouse_sensitivity))
		camera_angle_y_unfiltered -= camera_change.x * mouse_sensitivity
		camera_angle_x_unfiltered -= camera_change.y * mouse_sensitivity
		
		if camera_angle_x_unfiltered < -90:
			camera_angle_x_unfiltered = -90
		if camera_angle_x_unfiltered > 90:
			camera_angle_x_unfiltered = 90
			
		camera_change = Vector2()
	
	transform.basis = Basis()

	var correctedCoeff = pow(camera_angle_filter_coeff, delta)
		
	camera_angle_x_filtered = camera_angle_x_filtered * correctedCoeff + camera_angle_x_unfiltered * (1 - correctedCoeff)
	camera_angle_y_filtered = camera_angle_y_filtered * correctedCoeff + camera_angle_y_unfiltered * (1 - correctedCoeff)
			
	rotate_x(deg2rad(camera_angle_x_filtered))
	rotate_y(deg2rad(camera_angle_y_filtered))


##		var change = -camera_change.y * mouse_sensitivity
##		if change + camera_angle_x < 90 and change + camera_angle_x > -90:
#			$Head/Camera.rotate_x(deg2rad(change))
##			rotate_x(deg2rad(change))
#			camera_angle_x += change

func set_LocationOrientation(newTransform: Transform):
	transform = newTransform
	transform.basis = Basis()
	var newBasis = newTransform.basis
	camera_angle_x_unfiltered = - rad2deg(asin(newBasis.z.y))
	camera_angle_x_filtered = camera_angle_x_unfiltered
	camera_angle_y_unfiltered = rad2deg(atan2(newBasis.z.x, newBasis.z.z))
	camera_angle_y_filtered = camera_angle_y_unfiltered
	rotate_x(deg2rad(camera_angle_x_filtered))
	rotate_y(deg2rad(camera_angle_y_filtered))
#	firstPerson.camera_change = Vector2(0,0)

	
