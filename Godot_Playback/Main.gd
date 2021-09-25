extends Node

# Variables for playback.
# These are typically either logging computer's uptimes or "ITOW"s
# depending on the settings used in GNSS-Stylus-app when post-processing.
# (ITOWs (Integer Time Of Week) are "GPS-timestamps")
# All times here are ms
var replayTime:int = 0				# Replay position
var replayTimeFraction:float = 0	# Replay position fraction of ms (0...1) for smooth replay when using slow speed
var replayTimestartTicks_msec:int	# This computer's uptime corresponding to start time of playback (may be altered by fast forwarding/rewinding)
var lastReplayTime:int = 0			# Replay time when _physics_process was called last time
var previousReplaySpeed:float = 1
var requestReplayRestart:bool = false

# Time range for replay
# Will be updated according to dataset in use
var replayTimeStart:int = 0
var replayTimeEnd:int =   0

var dataSetIndexInUse:int = 0

# The following can be used to generate synced videos so that the frames
# generated will be at the same time stamps ("quantum").
# Can be used to generate synced alpha mask video for example.
# 0 or huge value (>= 1000, meaning 1 ms frame time) = disable
export(float, 0, 1000) var fps:float = 0
#export(float, 0.001, 100) var replaySpeed:float = 1

# Definitions for lidar object points
# Long version (60 s)
const numOfLidarPointSets:int = 601
const minLidarPointSetTime:int = 100
const lidarPointSetVisibleTime = 60000

# Short version (10 s)
#const numOfLidarPointSets:int = 101
#const minLidarPointSetTime:int = 100
#const lidarPointSetVisibleTime = 10000

# Some variables to store/keep track of lidar points
var lidarPointSets = []
var currentLidarPointSet:int = 0
var currentLidarPointSetLowerRangeReplayTime:int = -1
var lidarPointsInitialAlpha:float
var lidarPointsFinalAlpha:float
var lidarPointSize:float

# Variables for interpolating camera
# (flying from one camera to another when switching camera)
const camera_InterpolationTime_Fast = 500
const camera_InterpolationTime_Slow = 2000
var camera_Interpolating:bool = false
var camera_InterpolationFraction:float = 0
var camera_InterpolationTime:int = 2000
var camera_InterpolateFrom:Camera
var camera_InterpolateTo:Camera
var camera_InterpolationStartTime:int = 0

var lastUptime_ms:int = 0
var pauseStartTime:int = 0
var wasPaused:bool = false
var replaySpeedBeforePause:float = 1

# Most important things
enum IMPORTANTKEY { up, down, left, right, a, b }
var importantKeyBuffer = []
const importantCompareBuffer = [ IMPORTANTKEY.up, IMPORTANTKEY.up, IMPORTANTKEY.down, IMPORTANTKEY.down, IMPORTANTKEY.left, IMPORTANTKEY.right, IMPORTANTKEY.left, IMPORTANTKEY.right, IMPORTANTKEY.b, IMPORTANTKEY.a]
var koolnessKeyActivated = false

# dataset here mean one set of start/end replaytimes and associated camera- and 
# object location/orientation scripts (= *.LOScript-files generated with 
# GNSS-Stylus-application). These can be changed with UI's "Dataset"-OptionButton.
var datasets = [
	# [Name, Start replaytime, End replaytime, Object LOScript, Start replaytime of camera script, Camera LOScript, Camera platform LOScript ]
	["Video overlay", 4362000 - 10000, 5224428, "res://GNSS_Stylus_Scripts/RoadScan.LOScript", 656433, "res://GNSS_Stylus_Scripts/Walk3.LOScript", "res://GNSS_Stylus_Scripts/OutOfSight30kmUp.LOScript"],
	["Walk 1", 4362000 - 5000, 5224428, "res://GNSS_Stylus_Scripts/RoadScan.LOScript", 476196, "res://GNSS_Stylus_Scripts/Walk1.LOScript", "res://GNSS_Stylus_Scripts/OutOfSight30kmUp.LOScript"],

	# Chasing with the car:
	["Car chase", 4476000, 5224428, "res://GNSS_Stylus_Scripts/RoadScan.LOScript", 77818000 - 35000 + 1694 + 4476000 - 4362000, "res://GNSS_Stylus_Scripts/CarCam_StartingFromTheRock.LOScript", "res://GNSS_Stylus_Scripts/CarRig_StartingFromTheRock.LOScript"],
	#["Staring at the rock", 4362000, 5224428, "res://GNSS_Stylus_Scripts/RoadScan.LOScript", 77818000, "res://GNSS_Stylus_Scripts/CarCam_StaringAtTheRock.LOScript", "res://GNSS_Stylus_Scripts/CarRig_StaringAtTheRock.LOScript"],

	# Lidar calibration (stationary camera as time values will never be "in range".
	# there is no sensible "camera track" for calibration).
	["Lidar calibration", 3950000, 4070000, "res://GNSS_Stylus_Scripts/Calib.LOScript", 0, "res://GNSS_Stylus_Scripts/Walk3.LOScript", "res://GNSS_Stylus_Scripts/OutOfSight30kmUp.LOScript"],
#	["Lidar calibration", 3950000, 4070000, "res://GNSS_Stylus_Scripts/Calib.LOScript", 816450 + 4380000 - 4362000, "res://GNSS_Stylus_Scripts/VideoTrack3.LOScript", "res://GNSS_Stylus_Scripts/OutOfSight30kmUp.LOScript"],

	#Camera calibration:
	["Camera calibration", 461128, 581238, "res://GNSS_Stylus_Scripts/OutOfSight30kmUp.LOScript", 461128, "res://GNSS_Stylus_Scripts/CamCalib.LOScript", "res://GNSS_Stylus_Scripts/OutOfSight30kmUp.LOScript"],
]

# Lidarscripts that can be loaded.
# These can be chosen with UI's OptionButton
var lidarScripts = [
	# [Name, filename, compression mode (LidarDataStorage.CompressionMode)]
	["Road scan", "res://GNSS_Stylus_Scripts/RoadScan_Middle.LidarScript.godot_compressed", LidarDataStorage.CompressionMode.DEFLATE],
	["Calibration", "res://GNSS_Stylus_Scripts/Calib.LidarScript.godot_compressed", LidarDataStorage.CompressionMode.DEFLATE],
]

# Called when the node enters the scene tree for the first time.
func _ready():
	seed(12345)

	var LidarObjectPoints = load("LidarObjectPoints.gd")
	
	# Create objects to draw measured points
	# These will be updated later in _physics_process
	for i in range(0, numOfLidarPointSets):
		lidarPointSets.append(LidarObjectPoints.new())
		add_child(lidarPointSets[i])
	requestReplayRestart = true
	
#	$FirstPerson/Head/FirstPersonCamera.current = true
	$LOSolver_CameraEye/RigCamera.current = true

	_on_HSlider_Alpha_Road_Base_value_changed($Panel_UIControls/HSlider_Alpha_Road_Base.value)
	_on_HSlider_Alpha_Road_Colored_value_changed($Panel_UIControls/HSlider_Alpha_Road_Colored.value)
	_on_HSlider_Alpha_Road_Wireframe_value_changed($Panel_UIControls/HSlider_Alpha_Road_Wireframe.value)
	_on_HSlider_Alpha_Buildings_value_changed($Panel_UIControls/HSlider_Alpha_Buildings.value)
	_on_HSlider_Alpha_GroundRock_value_changed($Panel_UIControls/HSlider_Alpha_GroundRock.value)
	_on_CheckBox_ShowHelp_toggled($Panel_UIControls/CheckBox_ShowHelp.pressed)
	
	# Fill datasets into UI's OptionButton
	var datasetOptionButton = get_node("Panel_UIControls/OptionButton_Dataset")
	datasetOptionButton.clear()
	for datasetIndex in range(0, datasets.size()):
		datasetOptionButton.add_item(datasets[datasetIndex][0], datasetIndex)
	datasetOptionButton.select(0)
	_on_OptionButton_Dataset_item_selected(0)

	# Fill lidarscripts into UI's OptionButton
	var lidarScriptOptionButton = get_node("Panel_LoadLidarScript_Confirmation/OptionButton_LidarScript")
	lidarScriptOptionButton.clear()
	for lidarScriptIndex in range(0, lidarScripts.size()):
		lidarScriptOptionButton.add_item(lidarScripts[lidarScriptIndex][0], lidarScriptIndex)
	lidarScriptOptionButton.select(0)	
	
	lastUptime_ms = OS.get_ticks_msec()

# Called every frame. 'delta' is the elapsed time since the previous frame.
# (delta not used here to get better sync when generating video)
# TODO: Likely a lot of things from _physics_process could be moved here
func _process(_delta):
	var uptime:int = OS.get_ticks_msec()
	camSwitch(uptime)

func _physics_process(delta):
	var uptime:int = OS.get_ticks_msec()
	var uptimeDiff = uptime-lastUptime_ms
	handleScriptPlaybackControls(delta)

	# These are used in LidarObjectPoints.gd
	# Maybe a bit ugly to access things here and there...
	lidarPointsInitialAlpha = $Panel_UIControls/HSlider_Alpha_LidarPoints_Initial.value / 255.0
	lidarPointsFinalAlpha = $Panel_UIControls/HSlider_Alpha_LidarPoints_Final.value / 255.0
	lidarPointSize = $Panel_UIControls/SpinBox_PointSize.value

	if Input.is_action_just_pressed("full_screen_toggle"):
		OS.window_fullscreen = !OS.window_fullscreen

	if Input.is_action_just_pressed("hide_controls"):
		var show = !get_node("Panel_ShowControls").visible
		get_node("Panel_ShowControls").visible = show

	if Input.is_action_just_pressed("print_camera_matrix"):
		print(get_viewport().get_camera().get_global_transform())

	if get_tree().paused:
		return
	
	var replaySpeed:float = get_node("Panel_UIControls/SpinBox_ReplaySpeed").value
	
	if ($Panel_UIControls/CheckBox_Pause.pressed):
		if (!wasPaused):
			# This is needed to prevent playback advancing on old speed after
			# resuming from pause
			replayTime = replayTimeStart + (int(((uptime - replayTimestartTicks_msec) * replaySpeed)) % (replayTimeStart - replayTimeEnd))

			pauseStartTime = uptime
			replaySpeedBeforePause = replaySpeed
			wasPaused = true
		replaySpeed = 0
	else:
		if (wasPaused):
			previousReplaySpeed = replaySpeedBeforePause
			wasPaused = false
	
	if (replaySpeed == 0):
		replayTimestartTicks_msec += uptimeDiff
	
	if ((replaySpeed != previousReplaySpeed) and (replaySpeed != 0) and (previousReplaySpeed != 0)):
		# Calculate start time "backwards" so that the replay stays continuous
		replayTimestartTicks_msec = int(uptime - (uptime - replayTimestartTicks_msec) * (previousReplaySpeed / replaySpeed))
	
	if (requestReplayRestart):
		replayTimestartTicks_msec = uptime
		requestReplayRestart = false

	previousReplaySpeed = replaySpeed
		
	while (uptime - replayTimestartTicks_msec < 0):
		# Bit rude way to fix "rewind before the start of times", but works...
		replayTimestartTicks_msec += (replayTimeStart - replayTimeEnd)

	if (replaySpeed != 0):
		if (fps == 0):
			replayTime = replayTimeStart + (int(((uptime - replayTimestartTicks_msec) * replaySpeed)) % (replayTimeStart - replayTimeEnd))
			# int is 64-bit signed int godot, so we can use it here
			# (using arbitrary "big enough" multiplier, not beautiful...):
			var psReplayTime:int = (replayTimeStart * int(1e9)) + (int(((uptime - replayTimestartTicks_msec) * replaySpeed * 1e9)) % ((replayTimeStart - replayTimeEnd) * int(1e9)))
			psReplayTime -= replayTime * int(1e9)
			replayTimeFraction = float(psReplayTime) / 1e9
		else:
			var frameIndex:int = int(int((uptime - replayTimestartTicks_msec + 1) + (500.0 / fps)) * fps / 1000)
			replayTime = replayTimeStart + int((frameIndex * 1000.0 / fps) * replaySpeed) % (replayTimeStart - replayTimeEnd) 
			#print(frameIndex)
	else:
		# This branch is needed to be able to fast forward/rewind/step forward/step backward while paused
		if (fps == 0):
			replayTime = replayTimeStart + (int(((uptime - replayTimestartTicks_msec) * replaySpeedBeforePause)) % (replayTimeStart - replayTimeEnd))
		else:
			var frameIndex:int = int(int((uptime - replayTimestartTicks_msec + 1) + (500.0 / fps)) * fps / 1000)
			replayTime = replayTimeStart + int((frameIndex * 1000.0 / fps) * replaySpeedBeforePause) % (replayTimeStart - replayTimeEnd) 

	if (lastReplayTime > replayTime):
		# When time goes backward, just delete all existing points
		# (This is a "fallback" implementation for the one below
		# that tries (and somewhat succeeds) to delete only points needed)
#		for i in range(0, numOfLidarPointSets):
#			lidarPointSets[i].setViewRange(-1, -1, 0)
			
		if true:
			# Miserable rewinding code:
			# Clear point sets backward as long as needed
			# (needed for rewind to work)
			# Glitches (stucks for a while doing some heavy things) 
			# now and then, especially when rewinding/looping playback.
			# don't know why. May be also problem in LidarObjectPoints.gd(?)
			while ((lidarPointSets[currentLidarPointSet].firstReplayTimeToShow != -1) and
			(lidarPointSets[currentLidarPointSet].firstReplayTimeToShow > replayTime)):
				lidarPointSets[currentLidarPointSet].setViewRange(-1, -1, 0)
				currentLidarPointSet = (currentLidarPointSet + numOfLidarPointSets - 1) % numOfLidarPointSets
			currentLidarPointSetLowerRangeReplayTime = lidarPointSets[currentLidarPointSet].firstReplayTimeToShow
	
	if (currentLidarPointSetLowerRangeReplayTime == -1):
		currentLidarPointSetLowerRangeReplayTime = replayTime - 1000
	
	if (replayTime - currentLidarPointSetLowerRangeReplayTime > 10000):
		currentLidarPointSetLowerRangeReplayTime = replayTime - 10000
		
	if (currentLidarPointSetLowerRangeReplayTime < replayTimeStart):
		currentLidarPointSetLowerRangeReplayTime = replayTimeStart
	
	var tempReplayTime = lastReplayTime + 100
	
	if (replayTime - tempReplayTime > 10000):
		tempReplayTime = replayTime - 10000
	
	while true:
		if (tempReplayTime > replayTime):
			tempReplayTime = replayTime
			
#		if ((tempReplayTime - currentLidarPointSetLowerRangeReplayTime < 1000) and (currentLidarPointSetLowerRangeReplayTime <= tempReplayTime)):
		if (currentLidarPointSetLowerRangeReplayTime <= tempReplayTime):
			lidarPointSets[currentLidarPointSet].setViewRange(currentLidarPointSetLowerRangeReplayTime, tempReplayTime - 1, lidarPointSetVisibleTime)
			if (tempReplayTime - currentLidarPointSetLowerRangeReplayTime >= minLidarPointSetTime):
				# Switch to next point set only when points have been added from adequate time period
				# This prevents creating of too small point sets when replay speed is slow
				# which, consequently would lead to huge amounts of pointsets, slowing everything down
				currentLidarPointSet = (currentLidarPointSet + 1) % numOfLidarPointSets
				currentLidarPointSetLowerRangeReplayTime = tempReplayTime
		else:
			currentLidarPointSetLowerRangeReplayTime = tempReplayTime
			
		if (tempReplayTime >= replayTime):
			break;
		
		tempReplayTime += 100

# Some debug etc things:
#	var vanGlobal = $LOSolver_VanScanner/MB100D_Full.global_transform

#	var numOfLidarPoints:int = 0
#	for i in range(0, numOfLidarPointSets):
#		numOfLidarPoints += lidarPointSets[i].numOfPoints
#	print(numOfLidarPoints)

	important_function()
	
	lastReplayTime = replayTime
	lastUptime_ms = uptime

func camSwitch(uptime):
	var oldCamera = get_viewport().get_camera()
	var newCamera = null
	
	if Input.is_action_just_pressed("camera_first_person_global"):
		var firstPerson = get_node("FirstPerson")
		var flyCamera = get_node("FirstPerson/Head/FirstPersonCamera")
		firstPerson.set_LocationOrientation(get_viewport().get_camera().get_global_transform())
		newCamera = flyCamera
		camera_InterpolationTime = camera_InterpolationTime_Fast
	if Input.is_action_just_pressed("camera_first_person_van"):
		var cameraRig = get_node("LOSolver_VanScanner")
		var firstPerson = get_node("LOSolver_VanScanner/FirstPerson")
		var flyCamera = get_node("LOSolver_VanScanner/FirstPerson/Head/FirstPersonCamera")
		var sourceCameraGlobal = get_viewport().get_camera().get_global_transform()
		var rigGlobal = cameraRig.get_global_transform()
		var newTransform = rigGlobal.inverse() * sourceCameraGlobal
		firstPerson.set_LocationOrientation(newTransform)
		newCamera = flyCamera
		camera_InterpolationTime = camera_InterpolationTime_Fast
	if Input.is_action_just_pressed("camera_follow_van"):
		newCamera = get_node("LOSolver_VanScanner/BackCamera")
		camera_InterpolationTime = camera_InterpolationTime_Slow
	if Input.is_action_just_pressed("camera_camerarig"):
		newCamera = get_node("LOSolver_CameraEye/RigCamera")
		camera_InterpolationTime = camera_InterpolationTime_Slow
	if Input.is_action_just_pressed("camera_lidarrig_down"):
		newCamera = get_node("LOSolver_VanScanner/LidarAndCameraRig/Camera/CameraBody/RigCamera")
		camera_InterpolationTime = camera_InterpolationTime_Slow
	if Input.is_action_just_pressed("camera_first_person_car"):
		var cameraRig = get_node("LOSolver_CameraRigAndCar")
		var firstPerson = get_node("LOSolver_CameraRigAndCar/FirstPerson")
		var flyCamera = get_node("LOSolver_CameraRigAndCar/FirstPerson/Head/FirstPersonCamera")
		var sourceCameraGlobal = get_viewport().get_camera().get_global_transform()
		var rigGlobal = cameraRig.get_global_transform()
		var newTransform = rigGlobal.inverse() * sourceCameraGlobal
		firstPerson.set_LocationOrientation(newTransform)
		newCamera = flyCamera
		camera_InterpolationTime = camera_InterpolationTime_Fast
	if Input.is_action_just_pressed("camera_start_still"):
		newCamera = get_node("StartStillCamera")
		camera_InterpolationTime = camera_InterpolationTime_Slow

	if Input.is_action_just_pressed("camera_memory_store"):
		var memCamera = get_node("MemoryCamera")
		var sourceCamera = get_viewport().get_camera()
		var sourceCameraGlobal = get_viewport().get_camera().get_global_transform()
		memCamera.global_transform = sourceCameraGlobal
		memCamera.near = sourceCamera.near
		memCamera.far = sourceCamera.far
		memCamera.fov = sourceCamera.fov
	if Input.is_action_just_pressed("camera_memory_recall"):
		newCamera = get_node("MemoryCamera")
		camera_InterpolationTime = camera_InterpolationTime_Slow

	if (newCamera):
		if (newCamera == oldCamera):
			# Nothing to do really
			newCamera.current = true
			camera_Interpolating = false
		elif (camera_Interpolating):
			# Quick change on double press
			newCamera.current = true
			camera_Interpolating = false
		else:
			# Otherwise start interpolating
			camera_InterpolateFrom = oldCamera
			camera_InterpolateTo = newCamera
			camera_InterpolationStartTime = uptime
			camera_Interpolating = true
	
	if (camera_Interpolating):
		var currentFraction:float = smoothstep(camera_InterpolationStartTime, camera_InterpolationStartTime + camera_InterpolationTime, uptime)
		if (currentFraction >= 1):
			camera_InterpolateTo.current = true
			camera_Interpolating = false
		else:
			var currentPosition:Vector3 = camera_InterpolateFrom.global_transform.origin.linear_interpolate(camera_InterpolateTo.global_transform.origin, currentFraction)
			# Use quaternion slerp for smooth interpolation of rotation
			var currentOrientation:Quat = camera_InterpolateFrom.global_transform.basis.slerp(camera_InterpolateTo.global_transform.basis, currentFraction)
			var currentNear = camera_InterpolateFrom.near + (camera_InterpolateTo.near - camera_InterpolateFrom.near) * currentFraction
			var currentFar = camera_InterpolateFrom.far + (camera_InterpolateTo.far - camera_InterpolateFrom.far) * currentFraction
			var currentFov = camera_InterpolateFrom.fov + (camera_InterpolateTo.fov - camera_InterpolateFrom.fov) * currentFraction
			$CameraSwitchCamera.global_transform = Transform(currentOrientation, currentPosition)
			$CameraSwitchCamera.near = currentNear
			$CameraSwitchCamera.far = currentFar
			$CameraSwitchCamera.fov = currentFov
			$CameraSwitchCamera.current = true

func handleScriptPlaybackControls(_delta):
	if Input.is_action_just_pressed("rewind_5s"):
		replayTimestartTicks_msec = replayTimestartTicks_msec + 5000
	if Input.is_action_just_pressed("fast_forward_5s"):
		replayTimestartTicks_msec = replayTimestartTicks_msec - 5000
	if Input.is_action_pressed("resetReplayTime"):
		requestReplayRestart = true
	if (wasPaused):
		if Input.is_action_just_pressed("playback_step_forward"):
			replayTimestartTicks_msec = replayTimestartTicks_msec - $Panel_UIControls/SpinBox_ReplaySpeed.value * 1000 / replaySpeedBeforePause
		if Input.is_action_just_pressed("playback_step_backward"):
			replayTimestartTicks_msec = replayTimestartTicks_msec + $Panel_UIControls/SpinBox_ReplaySpeed.value * 1000 / replaySpeedBeforePause


func _on_Button_LoadLidarScript_pressed():
	var selectedScript = $Panel_LoadLidarScript_Confirmation/OptionButton_LidarScript.get_selected_id()
	$LidarDataStorage.loadFile(lidarScripts[selectedScript][1], lidarScripts[selectedScript][2])
	$Panel_LoadLidarScript_Confirmation.visible = false

func _on_Button_ClearLidarScript_pressed():
	$LidarDataStorage.clearData()
	$LidarLines.clear()
	$Panel_LoadLidarScript_Confirmation.visible = false

func _on_Button_LoadClearLidarScript_pressed():
	$Panel_LoadLidarScript_Confirmation.visible = true

func _on_Button_CancelLidarScriptOperation_pressed():
	$Panel_LoadLidarScript_Confirmation.visible = false


func _on_CheckBox_ShowHelp_toggled(button_pressed):
	$Panel_Help.visible = button_pressed

func important_function():
	# This is important, thou shall not touch!!11!

	var keyPressed = false
	var koolnessPressed = false
	
	if Input.is_action_just_pressed("ui_up"):
		importantKeyBuffer.push_back(IMPORTANTKEY.up)
		keyPressed = true
	if Input.is_action_just_pressed("ui_down"):
		importantKeyBuffer.push_back(IMPORTANTKEY.down)
		keyPressed = true
	if Input.is_action_just_pressed("ui_left"):
		importantKeyBuffer.push_back(IMPORTANTKEY.left)
		keyPressed = true
	if Input.is_action_just_pressed("ui_right"):
		importantKeyBuffer.push_back(IMPORTANTKEY.right)
		keyPressed = true
	if Input.is_action_just_pressed("create_new_box"):
		importantKeyBuffer.push_back(IMPORTANTKEY.b)
		keyPressed = true
	if Input.is_action_just_pressed("move_left"):
		importantKeyBuffer.push_back(IMPORTANTKEY.a)
		keyPressed = true
	if Input.is_action_just_pressed("koolness_fills_the_world"):
		keyPressed = true
		koolnessPressed = true

	if (keyPressed):
		var mismatch

		if (importantKeyBuffer.size() < importantCompareBuffer.size()):
			mismatch = true
		else:
			mismatch = false
			while (importantKeyBuffer.size() > importantCompareBuffer.size()):
				importantKeyBuffer.pop_front()
		
			for i in range(importantKeyBuffer.size()):
				if (importantKeyBuffer[i] != importantCompareBuffer[i]):
					mismatch = true;
		
		if (not mismatch) or (koolnessKeyActivated and koolnessPressed):
			var van = get_node("LOSolver_VanScanner/MB100D_NoRig")
			var rootNode = get_node("/root")
			var scene = load("res://eegg/EEgg.tscn")
			var newScene = scene.instance()
			newScene.transform = van.global_transform
			newScene.transform.origin.y += 1
			rootNode.add_child(newScene)
			koolnessKeyActivated = true


func setMaterialAlpha(material:SpatialMaterial, alpha:int):
	if (alpha >= 256):
		material.flags_transparent = false
		material.albedo_color.a8 = 255
	else:
		material.flags_transparent = true
		material.albedo_color.a8 = alpha

func setObjectVisibilityBasedOnAlpha(object, alpha: int):
	if (alpha == 0):
		object.visible = false
	else:
		object.visible = true

func _on_HSlider_Alpha_Road_Base_value_changed(value):
	var material:SpatialMaterial = $Road.get_surface_material(0)
	setMaterialAlpha(material, value)

func _on_HSlider_Alpha_Road_Colored_value_changed(value):
	var material:SpatialMaterial = $Road.coloredSurfaceMaterial
	setMaterialAlpha(material, value)

func _on_HSlider_Alpha_Road_Wireframe_value_changed(value):
	var material:SpatialMaterial = $Road.wireframeMaterial
	setMaterialAlpha(material, value)

func _on_HSlider_Alpha_Buildings_value_changed(value):
	var material:SpatialMaterial = $Buildings.get_surface_material(0)
	setMaterialAlpha(material, value)
	setObjectVisibilityBasedOnAlpha($Buildings, value)


func _on_Button_RegenPoints_pressed():
	var pointsTimeStart = replayTime-lidarPointSetVisibleTime

	for i in range(0, numOfLidarPointSets):
		if (pointsTimeStart <= replayTime):
			var pointsTimeEnd = pointsTimeStart + 100
			if (pointsTimeEnd > replayTime):
				pointsTimeEnd = replayTime
			lidarPointSets[i].setViewRange(pointsTimeStart, pointsTimeEnd, lidarPointSetVisibleTime)
			pointsTimeStart = pointsTimeEnd + 1
			
			# Need to update these to keep "normal" point handling in sync
			currentLidarPointSet = i
			currentLidarPointSetLowerRangeReplayTime = pointsTimeStart

		else:
			# Clear rest
			lidarPointSets[i].setViewRange(-1, -1, 0)

func _on_HSlider_Alpha_GroundRock_value_changed(value):
#	var material:SpatialMaterial = $GroundRock_Clipped/node.get_surface_material(0)
	var material:SpatialMaterial = $GroundRock_Clipped/node.get_active_material(0)
	setMaterialAlpha(material, value)
	setObjectVisibilityBasedOnAlpha($GroundRock_Clipped, value)


func _on_OptionButton_Dataset_item_selected(index):
	if (index >= 0) and (index < datasets.size()):
		replayTimeStart = datasets[index][1]
		replayTimeEnd = datasets[index][2]
		replayTimestartTicks_msec = OS.get_ticks_msec()
		replayTime = replayTimeStart
		dataSetIndexInUse = index

		get_node("LOSolver_VanScanner").loadFile(datasets[index][3])
		get_node("LOSolver_CameraEye").loadFile(datasets[index][5])
		get_node("LOSolver_CameraEye").replayTimeShift = datasets[index][4] - replayTimeStart
		get_node("LOSolver_CameraRigAndCar").loadFile(datasets[index][6])
		get_node("LOSolver_CameraRigAndCar").replayTimeShift = datasets[index][4] - replayTimeStart
		
		requestReplayRestart = true
	else:
		print("Dataset not found!")
