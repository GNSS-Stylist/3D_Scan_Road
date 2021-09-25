extends MeshInstance

enum DRAWN_POINT_TYPES { all, onlyAccepted }
export (DRAWN_POINT_TYPES) var drawnPointTypes = DRAWN_POINT_TYPES.all

enum SHAPE {cube, tetrahedron}
export (SHAPE) var shape = SHAPE.cube

var viewTime:int = 60000
var startPointSize:float = 50
var endPointSize:float = 1
#var pointsAdded:bool = false
var prevPointSize:float

#var cubeSize = 0.01
#var tetrahedronSize = 0.01

var firstReplayTimeToShow:int = -1
var lastReplayTimeToShow:int = -1

var firstReplayTimeAdded:int = -1
var lastReplayTimeAdded:int = -1

var replayTimeShift:int = 0

var myMaterial:SpatialMaterial

var numOfPoints:int = 0

var LidarDataStorage = load("LidarDataStorage.gd")
var pointColors = {
	LidarDataStorage.LSItemType.ACCEPTED: Color(0, 1, 0),
	LidarDataStorage.LSItemType.REJECTED_OUTSIDE_BOUNDING_SPHERE: Color(1, 1, 0),
	LidarDataStorage.LSItemType.REJECTED_NOT_SCANNING: Color(0.5, 0.5, 0.5),
	LidarDataStorage.LSItemType.REJECTED_OBJECT_NOT_ACTIVE: Color(0.5, 0.5, 0.5),
	LidarDataStorage.LSItemType.REJECTED_ANGLE: Color(1, 0, 0),

# No point drawing these (or actually these draw quite funny points inside the lidar itself :) )
#	LidarDataStorage.LSItemType.REJECTED_QUALITY_PRE: Color(1, 0, 0),
#	LidarDataStorage.LSItemType.REJECTED_QUALITY_POST: Color(1, 0, 0),

# Rejected for being too near points are only reflections from the camera
# not much of use here although they draw a nice "track"
#	LidarDataStorage.LSItemType.REJECTED_DISTANCE_NEAR: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_FAR: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_DISTANCE_DELTA: Color(1, 0, 0),
	LidarDataStorage.LSItemType.REJECTED_SLOPE: Color(1, 0, 0),
}

const tetrahedronVertices = [
	Vector3(sqrt(8.0/9.0),   0,             -(1.0/3.0)),
	Vector3(-sqrt(2.0/9.0),  sqrt(2.0/3.0), -(1.0/3.0)),
	Vector3(-sqrt(2.0/9.0), -sqrt(2.0/3.0), -(1.0/3.0)),
	Vector3(0,              0,               1)
	]


# Called when the node enters the scene tree for the first time.
func _ready():
#	myMaterial = self.material_override
	myMaterial = SpatialMaterial.new()
	
	myMaterial.flags_transparent = true
	myMaterial.flags_unshaded = true
	myMaterial.flags_use_point_size = false
	myMaterial.flags_do_not_receive_shadows = true
	myMaterial.flags_disable_ambient_light = true
	myMaterial.vertex_color_use_as_albedo = true
	myMaterial.render_priority = 10
	myMaterial.params_depth_draw_mode = SpatialMaterial.DEPTH_DRAW_ALWAYS

#	myMaterial.albedo_color = Color(1, 0, 0, 1)
#	myMaterial.params_point_size = 10
#	myMaterial.albedo_color = Color(0, 1, 0, 1)
	
	self.material_override = myMaterial
	
	pause_mode = PAUSE_MODE_STOP

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
#	pass

#func _physics_process(_delta):
	var currentReplayTime:int = get_node("/root/Main").replayTime + replayTimeShift

	if ((currentReplayTime - lastReplayTimeToShow > viewTime) or # Maximum view time reached
	(currentReplayTime < lastReplayTimeAdded) or # User likely rewinded
	(firstReplayTimeAdded != firstReplayTimeToShow) or # Start time changed (this is not usual, so no need for optimization)
	(lastReplayTimeAdded > lastReplayTimeToShow) or # End time got smaller (rewindind a small amount)
	(firstReplayTimeToShow == -1) or (lastReplayTimeToShow == -1)): # First or last times are invalid
		if mesh:
			mesh = null
			numOfPoints = 0
		firstReplayTimeAdded = -1
		lastReplayTimeAdded = -1
		
		if (currentReplayTime - lastReplayTimeToShow > viewTime):
			firstReplayTimeToShow = -1
			lastReplayTimeToShow = -1

	if (currentReplayTime - lastReplayTimeToShow > viewTime):
		# Slight optimization: No need for further processing
		return

	var pointSize:float = get_node("/root/Main").lidarPointSize

	if (prevPointSize != pointSize):
		# Need to refresh box sizes
		prevPointSize = pointSize
		firstReplayTimeAdded = -1
		lastReplayTimeAdded = -1
		if mesh:
			mesh = null
			numOfPoints = 0

	var firstReplayTimeToAdd:int = -1
	var lastReplayTimeToAdd:int = -1

	if ((firstReplayTimeToShow != -1) and (lastReplayTimeToShow != -1)):
		if (firstReplayTimeAdded != firstReplayTimeToShow):
			firstReplayTimeToAdd = firstReplayTimeToShow
			lastReplayTimeToAdd = lastReplayTimeToShow
		elif (lastReplayTimeAdded != lastReplayTimeToShow):
			firstReplayTimeToAdd = lastReplayTimeAdded + 1
			lastReplayTimeToAdd = lastReplayTimeToShow
	
	if (firstReplayTimeToAdd != -1) and (lastReplayTimeToAdd != -1):
		var dataStorage = get_node("../LidarDataStorage")
		if (dataStorage.beamData.size() == 0):
			return

		var itemIndex = dataStorage.beamDataKeys.bsearch(firstReplayTimeToAdd, true)
		var lastItemIndex = dataStorage.beamDataKeys.bsearch(lastReplayTimeToAdd, false)
		
		if not mesh:
			mesh = ArrayMesh.new()
			numOfPoints = 0
		
		# Godot's PoolxxxArrays don't support adding items
		# (at least using append_array() )
		# Took quite a while to figure this out.
		# Didn't find anything about this in the documentation either...
		# So that's why vertices and colors are first placed into
		# "normal" arrays
		# This became quite messy, but I don't have the energy to refactor this just now.
		
		var vertices = []	#PoolVector3Array() # PoolVector3Array doesn't support append_array...
		var colors = []		#PoolColorArray()	# neither does PoolColorArray
		
		var arrayMeshArray = []
		arrayMeshArray.resize(Mesh.ARRAY_MAX)

		arrayMeshArray[Mesh.ARRAY_VERTEX] = vertices
		arrayMeshArray[Mesh.ARRAY_COLOR] = colors

		while ((itemIndex <= lastItemIndex) and (itemIndex < dataStorage.beamDataKeys.size())):
			for subItem in dataStorage.beamData[dataStorage.beamDataKeys[itemIndex]]:
				if ((drawnPointTypes == DRAWN_POINT_TYPES.all) or (subItem.type == LidarDataStorage.LSItemType.ACCEPTED)):
					if ((pointColors.has(subItem.type)) and (subItem.origin.distance_squared_to(subItem.hitPoint) > 1)):
						# <1 m limit to filter out reflections from a camera
						# (If you want to draw the path of the camera, lower the limit
						# to something like 0.001).
						
						match(shape):
							SHAPE.cube:
								var arrayToAppend = addCube(subItem.hitPoint, pointSize, pointColors[subItem.type])
								for i in range(Mesh.ARRAY_MAX):
									if (arrayToAppend[i]):
										arrayMeshArray[i].append_array(arrayToAppend[i])
							#SHAPE.tetrahedron:
								# Tetrahedron is currently unsupported...
								# addTetrahedron(subItem.hitPoint)
							
						numOfPoints += 1
			itemIndex += 1

		if (arrayMeshArray[Mesh.ARRAY_VERTEX].size() > 0):
			# Read the comment few lines up to see why this is done this way
			var arrayMeshArray2 = []
			arrayMeshArray2.resize(Mesh.ARRAY_MAX)

			arrayMeshArray2[Mesh.ARRAY_VERTEX] = PoolVector3Array(arrayMeshArray[Mesh.ARRAY_VERTEX])
			arrayMeshArray2[Mesh.ARRAY_COLOR] = PoolColorArray(arrayMeshArray[Mesh.ARRAY_COLOR])
			
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrayMeshArray2)
			set_surface_material(0, myMaterial)
		
		if ((firstReplayTimeAdded == -1) or (firstReplayTimeAdded > firstReplayTimeToAdd)):
			firstReplayTimeAdded = firstReplayTimeToAdd
		
		lastReplayTimeAdded = lastReplayTimeToAdd
		
	var initialAlpha:float = get_node("/root/Main").lidarPointsInitialAlpha
	var finalAlpha:float = get_node("/root/Main").lidarPointsFinalAlpha

	if (initialAlpha < 1.0 or finalAlpha < 1.0):
		var fraction = clamp(float(currentReplayTime - lastReplayTimeToShow) / viewTime, 0, 1)
		var alpha = clamp(initialAlpha + (finalAlpha - initialAlpha) * fraction, 0, 1)
		
		myMaterial.albedo_color.a = alpha
#		myMaterial.albedo_color.a = (1.0 - float(currentReplayTime - lastReplayTimeToShow) / viewTime)
		myMaterial.flags_transparent = true
	else:
		myMaterial.albedo_color.a = 1.0
		myMaterial.flags_transparent = false
		
#	set_surface_material(mesh.get_surface_count() - 1, myMaterial)
		

#	myMaterial.params_point_size = startPointSize - (float(currentReplayTime - lastReplayTimeToShow) / viewTime) * (startPointSize - endPointSize)

func addCube(origin:Vector3, cubeSize:float, color:Color):
	var arrayMeshArray = []
	arrayMeshArray.resize(Mesh.ARRAY_MAX)

	var corners = []
	corners.resize(8)
	
	for i in range(8):
		corners[i] = origin
	
	var cubeSizeHalf = cubeSize / 2
	
	corners[0].x -= cubeSizeHalf
	corners[0].y += cubeSizeHalf
	corners[0].z += cubeSizeHalf
		
	corners[1].x += cubeSizeHalf
	corners[1].y += cubeSizeHalf
	corners[1].z += cubeSizeHalf
		
	corners[2].x -= cubeSizeHalf
	corners[2].y -= cubeSizeHalf
	corners[2].z += cubeSizeHalf
		
	corners[3].x += cubeSizeHalf
	corners[3].y -= cubeSizeHalf
	corners[3].z += cubeSizeHalf
		
	corners[4].x -= cubeSizeHalf
	corners[4].y += cubeSizeHalf
	corners[4].z -= cubeSizeHalf
		
	corners[5].x += cubeSizeHalf
	corners[5].y += cubeSizeHalf
	corners[5].z -= cubeSizeHalf
		
	corners[6].x -= cubeSizeHalf
	corners[6].y -= cubeSizeHalf
	corners[6].z -= cubeSizeHalf
		
	corners[7].x += cubeSizeHalf
	corners[7].y -= cubeSizeHalf
	corners[7].z -= cubeSizeHalf
	
	var vertices = PoolVector3Array()
	vertices.resize(6 * 2 * 3)
	
	# Front:
	vertices[0] = corners[0]
	vertices[1] = corners[1]
	vertices[2] = corners[2]
	
	vertices[3] = corners[1]
	vertices[4] = corners[3]
	vertices[5] = corners[2]
	
	# Left:
	vertices[6] = corners[0]
	vertices[7] = corners[2]
	vertices[8] = corners[4]
	
	vertices[9] = corners[4]
	vertices[10] = corners[2]
	vertices[11] = corners[6]
	
	# Right:
	vertices[12] = corners[1]
	vertices[13] = corners[5]
	vertices[14] = corners[3]
	
	vertices[15] = corners[3]
	vertices[16] = corners[5]
	vertices[17] = corners[7]
	
	# Top:
	vertices[18] = corners[0]
	vertices[19] = corners[4]
	vertices[20] = corners[1]
	
	vertices[21] = corners[1]
	vertices[22] = corners[4]
	vertices[23] = corners[5]

	# Bottom:
	vertices[24] = corners[2]
	vertices[25] = corners[3]
	vertices[26] = corners[6]
	
	vertices[27] = corners[3]
	vertices[28] = corners[7]
	vertices[29] = corners[6]

	# Back:
	vertices[30] = corners[4]
	vertices[31] = corners[7]
	vertices[32] = corners[5]
	
	vertices[33] = corners[4]
	vertices[34] = corners[6]
	vertices[35] = corners[7]
	
	var colors = PoolColorArray()
	colors.resize(vertices.size())

	for i in range(vertices.size()):
		colors[i] = color

	arrayMeshArray[ArrayMesh.ARRAY_VERTEX] = vertices
	arrayMeshArray[ArrayMesh.ARRAY_COLOR] = colors

	return arrayMeshArray

func addTetrahedron(_origin:Vector3):
	# Not implemented (implementation below uses obsolete way to do this)
	# If needed, take ideas from cube code above.
#	pass
	
	"""
	var vertices = []
	vertices.resize(4)
	
	for i in range(4):
		vertices[i] = origin
		vertices[i] += tetrahedronVertices[i] * tetrahedronSize
		
	add_vertex(vertices[0])
	add_vertex(vertices[1])
	add_vertex(vertices[2])
	
	add_vertex(vertices[0])
	add_vertex(vertices[2])
	add_vertex(vertices[3])

	add_vertex(vertices[0])
	add_vertex(vertices[3])
	add_vertex(vertices[1])

	add_vertex(vertices[1])
	add_vertex(vertices[3])
	add_vertex(vertices[2])
"""

func setViewRange(firstReplayTimeToShow_p:int, lastReplayTimeToShow_p:int, viewTime_p):
	firstReplayTimeToShow = firstReplayTimeToShow_p
	lastReplayTimeToShow = lastReplayTimeToShow_p
	viewTime = viewTime_p
	_process(0)
	return
