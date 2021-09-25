extends MeshInstance


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

export var coloredSurfaceMaterial:Material
export var wireframeMaterial:Material
#export(float, -1, 1, 0.0001) var faceShiftY:float

# Called when the node enters the scene tree for the first time.
func _ready():
#	var originalMaterial = get_surface_material(0)
#	var originalSurfaceArrays = mesh.surface_get_arrays(0)
#	mesh = ArrayMesh.new()
#	mesh.add_surface_from_arrays()
	makeColoredFaces(mesh)
	makeWireframe(mesh)

func makeColoredFaces(arrayMesh:ArrayMesh):
	var faces = self.mesh.get_faces()

	var filteredArray = []
	filteredArray.resize(Mesh.ARRAY_MAX)
	
	var filteredVertices = PoolVector3Array()
	var colorArray = PoolColorArray()
	
	filteredVertices.resize(faces.size())
	colorArray.resize(faces.size())
	
	var vertIndex = 0
	var colorIndex = 0
	
	for faceIndex in range(0, faces.size()/3):
		filteredVertices[vertIndex + 0] = faces[faceIndex * 3 + 0]
		filteredVertices[vertIndex + 1] = faces[faceIndex * 3 + 1]
		filteredVertices[vertIndex + 2] = faces[faceIndex * 3 + 2]
		
		var faceColor = Color(rand_range(0, 1), rand_range(0, 1), rand_range(0, 1))
		colorArray[colorIndex + 0] = faceColor
		colorArray[colorIndex + 1] = faceColor
		colorArray[colorIndex + 2] = faceColor
		
		vertIndex += 3
		colorIndex += 3

#	for vertexIndex in range(0, filteredVertices.size()):
#		filteredVertices[vertexIndex].y += faceShiftY

	filteredArray[Mesh.ARRAY_VERTEX] = filteredVertices
	filteredArray[Mesh.ARRAY_COLOR] = colorArray

#	mesh = ArrayMesh.new()
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, filteredArray)
	set_surface_material(arrayMesh.get_surface_count() - 1, coloredSurfaceMaterial)

func makeWireframe(arrayMesh:ArrayMesh):
	var meshInstance = get_node("/root/Main/Road")
	var faceVertices = meshInstance.mesh.get_faces()
#	var originalMaterial = get_surface_material(0)
	var array = meshInstance.mesh.surface_get_arrays(0)

	var filteredArray = []
	filteredArray.resize(Mesh.ARRAY_MAX)
	
	var filteredVertices = PoolVector3Array()
	
	filteredVertices.resize(faceVertices.size() * 2)
	
	var vertCount = 0
	
	for faceIndex in range(0, faceVertices.size()/3):
		
		# ifs here try to filter out duplicate lines.
		# Filtering will only work when x-coordinates of endpoint differ.
		# Should filter out most of those.
		# This could be made far better, though...
		
		if (faceVertices[faceIndex * 3 + 0].x >= faceVertices[faceIndex * 3 + 1].x):
			filteredVertices[vertCount + 0] = faceVertices[faceIndex * 3 + 0]
			filteredVertices[vertCount + 1] = faceVertices[faceIndex * 3 + 1]
			vertCount += 2
		
		if (faceVertices[faceIndex * 3 + 1].x >= faceVertices[faceIndex * 3 + 2].x):
			filteredVertices[vertCount + 0] = faceVertices[faceIndex * 3 + 1]
			filteredVertices[vertCount + 1] = faceVertices[faceIndex * 3 + 2]
			vertCount += 2
		
		if (faceVertices[faceIndex * 3 + 2].x >= faceVertices[faceIndex * 3 + 0].x):
			filteredVertices[vertCount + 0] = faceVertices[faceIndex * 3 + 2]
			filteredVertices[vertCount + 1] = faceVertices[faceIndex * 3 + 0]
			vertCount += 2

	filteredVertices.resize(vertCount)

	if 0:
		for faceIndex in range(0, array[Mesh.ARRAY_VERTEX].size()/3):
			filteredVertices.push_back(array[Mesh.ARRAY_VERTEX][faceIndex * 3 + 0])
			filteredVertices.push_back(array[Mesh.ARRAY_VERTEX][faceIndex * 3 + 1])
			
			filteredVertices.push_back(array[Mesh.ARRAY_VERTEX][faceIndex * 3 + 1])
			filteredVertices.push_back(array[Mesh.ARRAY_VERTEX][faceIndex * 3 + 2])
			
			filteredVertices.push_back(array[Mesh.ARRAY_VERTEX][faceIndex * 3 + 2])
			filteredVertices.push_back(array[Mesh.ARRAY_VERTEX][faceIndex * 3 + 0])

	filteredArray[Mesh.ARRAY_VERTEX] = filteredVertices

#	mesh = ArrayMesh.new()
	arrayMesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, filteredArray)
	set_surface_material(arrayMesh.get_surface_count() - 1, wireframeMaterial)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var maxAlpha = 0.0
	for surfaceIndex in range(mesh.get_surface_count()):
#		var material = mesh.surface_get_material(surfaceIndex)
		var material = get_active_material(surfaceIndex)
		if (material != null):
			var alpha =material.albedo_color.a
			if alpha > maxAlpha:
				maxAlpha = alpha
	
	if maxAlpha == 0:
		visible = false
	else:
		visible = true
