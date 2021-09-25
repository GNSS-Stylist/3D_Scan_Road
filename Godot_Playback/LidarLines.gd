extends ImmediateGeometry

enum DRAWN_LINE_TYPES { all, onlyAccepted }
export (DRAWN_LINE_TYPES) var drawnLineTypes = DRAWN_LINE_TYPES.all

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var maxHistoryLength = 100

var LidarDataStorage = load("LidarDataStorage.gd")
var lineColors = {
	LidarDataStorage.LSItemType.ACCEPTED: Color(0, 1, 0),
	LidarDataStorage.LSItemType.REJECTED_OUTSIDE_BOUNDING_SPHERE: Color(1, 1, 0),
	LidarDataStorage.LSItemType.REJECTED_NOT_SCANNING: Color(0.5, 0.5, 0.5),
	LidarDataStorage.LSItemType.REJECTED_OBJECT_NOT_ACTIVE: Color(0.5, 0.5, 0.5),
	LidarDataStorage.LSItemType.REJECTED_ANGLE: Color(0.5, 0.5, 0.5),
# No point drawing these (or actually these draw quite funny points into the lidar itself :) )
#	LidarDataStorage.LSItemType.REJECTED_QUALITY_PRE: Color(1, 0, 0),
#	LidarDataStorage.LSItemType.REJECTED_QUALITY_POST: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_NEAR: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_FAR: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_DELTA: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_SLOPE: Color(1, 0, 0),
}

var replayTimeShift:int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _physics_process(_delta):
	var currentReplayTime:int = get_node("/root/Main").replayTime + replayTimeShift

	var dataStorage = get_node("../LidarDataStorage")
	if (dataStorage.beamData.size() == 0):
		return
	
	var itemIndex = dataStorage.beamDataKeys.bsearch(currentReplayTime, true)

	clear()
	begin(Mesh.PRIMITIVE_LINES)
#	set_color(Color(0, 0, 0, 1))

#	var startAngle:float = -1
#	var doAngleCheck:bool = false
	var fullRoundDrawn:bool = false

	while ((itemIndex >= 0) and (itemIndex < dataStorage.beamDataKeys.size()) and 
		(dataStorage.beamDataKeys[itemIndex] > currentReplayTime - maxHistoryLength) and
		(not fullRoundDrawn)):

		for subItem in dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]]:
			if ((drawnLineTypes == DRAWN_LINE_TYPES.all) or (subItem.type == LidarDataStorage.LSItemType.ACCEPTED)):
				if ((lineColors.has(subItem.type)) and (subItem.origin.distance_squared_to(subItem.hitPoint) > 0.0001)):
					set_color(lineColors[subItem.type])
					add_vertex(subItem.origin)
					add_vertex(subItem.hitPoint)
				
					
		itemIndex -= 1

	end()
