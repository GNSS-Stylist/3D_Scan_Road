extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

#var replayTimeShift:int = -1	# -1 Here: See LidarLines.gd why
var replayTimeShift:int = 0

# Time to wait after valid lidar data before starting to rotate the lidar by itself:
export var idleRotationWaitTime:int = 1000

# Rotation speed of lidar when no data has come in the time defined above
export var idleRotationSpeed:float = 20.0
export var idleObeyPause:bool = false

var lastDataTime = 0
var lastDataTimeRotation:float = 0

var pauseStartUptime:int = 0
var totalPauseTime:int = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	lastDataTime = OS.get_ticks_msec()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# TODO: This is a horrible mess, should refactor...
	var dataStorage = get_node("/root/Main/LidarDataStorage")

	var currentReplayTime:int = get_node("/root/Main").replayTime + replayTimeShift
	var itemIndex:int = 0
	
	if (dataStorage.beamData.size() > 0):
		itemIndex = dataStorage.beamDataKeys.bsearch(currentReplayTime, true)

	if (dataStorage.beamData.size() > 0) and (itemIndex < dataStorage.beamDataKeys.size()):
		var subItem = dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]].back()
		lastDataTimeRotation = subItem.rotation
		self.rotation = Vector3(subItem.rotation, 0,0)
		lastDataTime = OS.get_ticks_msec()
	elif OS.get_ticks_msec() - lastDataTime > idleRotationWaitTime:
		if get_tree().paused and idleObeyPause:
			if pauseStartUptime == 0:
				pauseStartUptime = OS.get_ticks_msec()
			return
		elif pauseStartUptime != 0:
			totalPauseTime += OS.get_ticks_msec() - pauseStartUptime
			pauseStartUptime = 0
		var replaySpeed:float = get_node("/root/Main/Panel_UIControls/SpinBox_ReplaySpeed").value
		var timediff:int = OS.get_ticks_msec() - lastDataTime - idleRotationWaitTime - totalPauseTime
		var rotationSubRound = (int(timediff * replaySpeed * idleRotationSpeed)) % 1000
		var rotationAngle:float = lastDataTimeRotation + (rotationSubRound / 1000.0 * (2.0 * PI))
		self.rotation = Vector3(rotationAngle, 0,0)





