class_name LidarDataStorage

extends Node

enum LSItemType { 
	ACCEPTED, 
	REJECTED_OUTSIDE_BOUNDING_SPHERE, 
	REJECTED_NOT_SCANNING, 
	REJECTED_OBJECT_NOT_ACTIVE, 
	REJECTED_ANGLE, 
	REJECTED_QUALITY_PRE, 
	REJECTED_QUALITY_POST, 
	REJECTED_DISTANCE_NEAR, 
	REJECTED_DISTANCE_FAR, 
	REJECTED_DISTANCE_DELTA, 
	REJECTED_SLOPE,
	
	REJECTED_UNKNOWN }

enum CompressionMode {
	NO_COMPRESSION,
	DEFLATE,
	GZIP
}

export var lsFilename:String = ""
export(CompressionMode) var compressionMode = CompressionMode.NO_COMPRESSION

var beamData = {}
var beamDataKeys
var numberOfPoints:int = 0

class BeamItem:
	var type:int	#LSItemType
	var rotation:float
	var origin:Vector3
	var hitPoint:Vector3
	func _init(type_p:int, rotation_p:float, origin_p:Vector3, hitPoint_p:Vector3):
		self.type = type_p
		self.rotation = rotation_p
		self.origin = origin_p
		self.hitPoint = hitPoint_p

# Called when the node enters the scene tree for the first time.
func _ready():
	if lsFilename.length() > 0:
		# Try to load file at this phase only if defined.
		loadFile(lsFilename, compressionMode)
		
func clearData():
	beamData.clear()
	beamDataKeys = []

func loadFile(fileName, compression):
	clearData()
	var lineNumber:int = 0

	var file = File.new()
	var openResult = !OK
	
	match compression:
		CompressionMode.NO_COMPRESSION:
			openResult = file.open(fileName, File.READ)
		CompressionMode.DEFLATE:
			openResult = file.open_compressed(fileName, File.READ, File.COMPRESSION_DEFLATE)
		CompressionMode.GZIP:
			openResult = file.open_compressed(fileName, File.READ, File.COMPRESSION_GZIP)
			
	if openResult != OK:
		print("Can't open file ", fileName)
		return
		
	# Create compressed file. This was added because github has a hard limit
	# of 100 MB for a single file and this LidarScript is over the limit.
	# After several tries and banging my head to a wall I couldn't get 
	# "external" compression working. So create a compressed file 
	# using godot's own compression method instead.
	if false:
		var compressedFile = File.new()
		compressedFile.open_compressed(fileName + ".godot_compressed", File.WRITE, File.COMPRESSION_DEFLATE)
		while not file.eof_reached():
			var line = file.get_line()
			compressedFile.store_line(line)
		compressedFile.close()
		return
		
	# Use this to get uncompressed file back
	if false:
		var uncompressedFile = File.new()
		uncompressedFile.open(fileName + ".uncompressed", File.WRITE)
		while not file.eof_reached():
			var line = file.get_line()
			uncompressedFile.store_line(line)
		uncompressedFile.close()
		return
		
	var line
	while not file.eof_reached():
		lineNumber += 1
		line = file.get_line()
		var subStrings = line.split("\t")
		if subStrings.size() < 2:
			continue
		
		if subStrings[0] == "META":
			if subStrings[1] == "END":
				break
			# TODO: Add some sanity checks here.
			# (now just skipping all checks...)
	lineNumber += 1
	line = file.get_line()
	if line != "Uptime\tType\tDescr/subtype\tRotAngle\tOrigin_X\tOrigin_Y\tOrigin_Z\tHit_X\tHit_Y\tHit_Z":
		print("Invalid header line in ", lsFilename)
		return

	var oldUptime:int = -1
	var itemArray = []

	while not file.eof_reached():
		lineNumber += 1
#		if (lineNumber % 1000) == 0:
#			print("Reading lidar script, line: ", lineNumber)
		line = file.get_line()
		var subStrings = line.split("\t")
		if (subStrings.size() >= 2):
			var newUpTime = subStrings[0].to_int()
			
			if ((oldUptime != newUpTime) and (not itemArray.empty())):
				beamData[oldUptime] = itemArray.duplicate()
				itemArray.clear()
				oldUptime = newUpTime
			
			match subStrings[1]:
				"L":
					if (subStrings.size() != 10):
						print("Invalid line ", lineNumber, " in LidarScript file ", lsFilename, ". Terminating interpretation.")
						return
						
					var type = LSItemType.REJECTED_UNKNOWN
					match subStrings[2]:
						"H":
							type = LSItemType.ACCEPTED
						"M":
							type = LSItemType.REJECTED_OUTSIDE_BOUNDING_SPHERE
						"NS":
							type = LSItemType.REJECTED_NOT_SCANNING
						"NO":
							type = LSItemType.REJECTED_OBJECT_NOT_ACTIVE
						"FA":
							type = LSItemType.REJECTED_ANGLE
						"FQ1":
							type = LSItemType.REJECTED_QUALITY_PRE
						"FQ2":
							type = LSItemType.REJECTED_QUALITY_POST
						"FDN":
							type = LSItemType.REJECTED_DISTANCE_NEAR
						"FDF":
							type = LSItemType.REJECTED_DISTANCE_FAR
						"FDD":
							type = LSItemType.REJECTED_DISTANCE_DELTA
						"FS":
							type = LSItemType.REJECTED_SLOPE
						"F?":
							type = LSItemType.REJECTED_UNKNOWN
					
					var rotation: = float(subStrings[3])
					var origin = Vector3(subStrings[4], subStrings[5], subStrings[6])
					var hitPoint = Vector3(subStrings[7], subStrings[8], subStrings[9])
			
					itemArray.append(BeamItem.new(type, rotation, origin, hitPoint))
					numberOfPoints += 1
					
				# TODO: Add other types here (below) if/when needed
				# Probably place them in different dictionaries?
				#"OBJECTNAME"
				#"STARTOBJECT"
				#"ENDOBJECT"
				#"STARTSCAN"
				#"ENDSCAN"

	if ((not itemArray.empty()) and (oldUptime != -1)):
		beamData[oldUptime] = itemArray

	beamDataKeys = beamData.keys()
