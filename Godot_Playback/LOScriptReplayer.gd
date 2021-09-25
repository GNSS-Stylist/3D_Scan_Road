extends KinematicBody

enum QUAT_INTERPOLATION_METHOD { lastValue, nextValue, nearestValue, slerp, slerpni, cubic_slerp }
enum ORIGIN_INTERPOLATION_METHOD { lastValue, nextValue, nearestValue, linear, cubic }

export var loFilename:String = ""
export var replayTimeShift:int = 0

export (ORIGIN_INTERPOLATION_METHOD) var originInterpolationMethod = ORIGIN_INTERPOLATION_METHOD.cubic
export(QUAT_INTERPOLATION_METHOD) var quatInterpolationMethod = QUAT_INTERPOLATION_METHOD.slerp

class LOItem:
	var origin:Vector3
	var quat:Quat
	func _init(origin_p:Vector3, quat_p:Quat):
		self.origin = origin_p
		self.quat = quat_p

var loData = {}
var loDataKeys

var nextReplayTimeIndex:int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	if loFilename.length() > 0:
		# Try to load file at this phase only if defined.
		loadFile(loFilename)
	
func loadFile(fileName):
	loData.clear()
	loDataKeys = []

	var file = File.new()
	#var metadata = {}
	if file.open(fileName, File.READ) != OK:
		print("Can't open file " + fileName)
		return
	var line
	while not file.eof_reached():
		line = file.get_line()
		var subStrings = line.split("\t")
		if subStrings.size() < 2:
			continue
		
		if subStrings[0] == "META":
			if subStrings[1] == "END":
				break
			# TODO: Add some sanity checks here.
			# (now just skipping all checks...)
	
	line = file.get_line()
	if line != "iTOW\tOrigin_X\tOrigin_Y\tOrigin_Z\tBasis_XX\tBasis_XY\tBasis_XZ\tBasis_YX\tBasis_YY\tBasis_YZ\tBasis_ZX\tBasis_ZY\tBasis_ZZ" and line != "Uptime\tOrigin_X\tOrigin_Y\tOrigin_Z\tBasis_XX\tBasis_XY\tBasis_XZ\tBasis_YX\tBasis_YY\tBasis_YZ\tBasis_ZX\tBasis_ZY\tBasis_ZZ":
		printt("Invalid header line in " + loFilename)
		return

	while not file.eof_reached():
		# TODO: Maybe add some error checking here...
		line = file.get_line()
		var subStrings = line.split("\t")
		if (subStrings.size() >= (1 + (4 * 3))):
			var replayTime = subStrings[0].to_int()
			
			#Coordinates in Godot's native "EUS"-convention:
			var origin = Vector3(subStrings[1], subStrings[2], subStrings[3])
			var unitVecX = Vector3(subStrings[4], subStrings[5], subStrings[6])
			var unitVecY = Vector3(subStrings[7], subStrings[8], subStrings[9])
			var unitVecZ = Vector3(subStrings[10], subStrings[11], subStrings[12])

# These convert NED-coordinates to godot's "EUS" on the fly
#			var origin = Vector3(subStrings[2].to_float(), -subStrings[3].to_float(), -subStrings[1].to_float())
#			var unitVecX = Vector3(subStrings[5].to_float(), -subStrings[6].to_float(), -subStrings[4].to_float())
#			var unitVecY = Vector3(subStrings[8].to_float(), -subStrings[9].to_float(), -subStrings[7].to_float())
#			var unitVecZ = Vector3(subStrings[11].to_float(), -subStrings[12].to_float(), -subStrings[10].to_float())

			var basis = Basis(unitVecX, unitVecY, unitVecZ).orthonormalized()
#			var tr = Transform(unitVecX, unitVecY, unitVecZ, origin)
			
			var quat = Quat(basis)
			
			loData[replayTime] = LOItem.new(origin, quat)
	
	loDataKeys = loData.keys()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass

func _physics_process(_delta):
	if loData.empty():
		return
		
	var currentReplayTime:int = get_node("/root/Main").replayTime + replayTimeShift
	var currentReplayTimeFraction:float = get_node("/root/Main").replayTimeFraction
	
	if nextReplayTimeIndex < loDataKeys.size():
		for _i in range(10):
			# Maybe this faster than using bsearch every time(?)
			# Run this some rounds to allow some hickups in screen update etc.
			if nextReplayTimeIndex < loDataKeys.size() and currentReplayTime >= loDataKeys[nextReplayTimeIndex]:
				# Typical case: monotonically increasing ReplayTime
				nextReplayTimeIndex += 1
				continue
			elif nextReplayTimeIndex > 0 and currentReplayTime < loDataKeys[nextReplayTimeIndex - 1]:
				# Another typical(ish?) case: monotonically decreasing ReplayTime
				nextReplayTimeIndex -= 1
				continue
			else:
				break
		
		if (nextReplayTimeIndex > 0 and nextReplayTimeIndex < loDataKeys.size() and 
			(currentReplayTime < loDataKeys[nextReplayTimeIndex - 1] or 
				currentReplayTime >= loDataKeys[nextReplayTimeIndex])):
			# ReplayTime changed too fast
			# -> Use bsearch to find the correct index
			nextReplayTimeIndex = loDataKeys.bsearch(currentReplayTime)
	elif currentReplayTime < loDataKeys[loDataKeys.size() - 1]:
		# "Rewind" while in the last item
		nextReplayTimeIndex = loDataKeys.bsearch(currentReplayTime)
	
	var nextReplayTimeValue:int

	if nextReplayTimeIndex < loDataKeys.size():
		nextReplayTimeValue = loDataKeys[nextReplayTimeIndex]
	else:
		nextReplayTimeValue = loDataKeys[loDataKeys.size() - 1]
	
	var origin:Vector3
	var quat:Quat
	
	if nextReplayTimeIndex <= 0:
		origin = loData[nextReplayTimeValue].origin
		quat = loData[nextReplayTimeValue].quat
	elif nextReplayTimeValue == currentReplayTime:
		origin = loData[nextReplayTimeValue].origin
		quat = loData[nextReplayTimeValue].quat
	elif nextReplayTimeIndex >= loDataKeys.size() - 1:
		origin = loData[loDataKeys[loDataKeys.size() -1]].origin
		quat = loData[loDataKeys[loDataKeys.size() -1]].quat
	else:
		var lastReplayTimeIndex:int = nextReplayTimeIndex - 1
		var lastReplayTimeValue:int = loDataKeys[lastReplayTimeIndex]
		var fraction:float = float(currentReplayTime + currentReplayTimeFraction - lastReplayTimeValue) / (nextReplayTimeValue - lastReplayTimeValue)
		var origin_a:Vector3 = loData[lastReplayTimeValue].origin
		var origin_b:Vector3 = loData[nextReplayTimeValue].origin
		var quat_a:Quat = loData[lastReplayTimeValue].quat
		var quat_b:Quat = loData[nextReplayTimeValue].quat

		if nextReplayTimeIndex == 1 or nextReplayTimeIndex == loDataKeys.size() - 1:
			# linear interpolation when cubic not possible
			origin = origin_a.linear_interpolate(origin_b, fraction)
			quat = quat_a.slerp(quat_b, fraction)
		else:

			match originInterpolationMethod:
				ORIGIN_INTERPOLATION_METHOD.lastValue:
					origin = origin_a
				ORIGIN_INTERPOLATION_METHOD.nextValue:
					origin = origin_b
				ORIGIN_INTERPOLATION_METHOD.nearestValue:
					origin = origin_a if fraction < 0.5 else origin_b
				ORIGIN_INTERPOLATION_METHOD.linear:
					origin = origin_a.linear_interpolate(origin_b, fraction)
				ORIGIN_INTERPOLATION_METHOD.cubic:
					var origin_pre_a:Vector3 = loData[loDataKeys[lastReplayTimeIndex - 1]].origin
					var origin_post_b:Vector3 = loData[loDataKeys[nextReplayTimeIndex + 1]].origin
					origin = origin_a.cubic_interpolate(origin_b, origin_pre_a, origin_post_b, fraction)
				_:
					origin = origin_a

			match quatInterpolationMethod:
				QUAT_INTERPOLATION_METHOD.lastValue:
					quat = quat_a
				QUAT_INTERPOLATION_METHOD.nextValue:
					quat = quat_b
				QUAT_INTERPOLATION_METHOD.nearestValue:
					quat = quat_a if fraction < 0.5 else quat_b
				QUAT_INTERPOLATION_METHOD.slerp:
					quat = quat_a.slerp(quat_b, fraction)
				QUAT_INTERPOLATION_METHOD.slerpni:
					# Causes some strange jitter
					quat = quat_a.slerpni(quat_b, fraction)
				QUAT_INTERPOLATION_METHOD.cubic_slerp:
					# Causes even stranger jitter
					var quat_pre_a:Quat = loData[loDataKeys[lastReplayTimeIndex - 1]].quat
					var quat_post_b:Quat = loData[loDataKeys[nextReplayTimeIndex + 1]].quat
					quat = quat_a.cubic_slerp(quat_b, quat_pre_a, quat_post_b, fraction)
				_:
					quat = quat_a
	
	var basis = Basis(quat)
	
	var tr = Transform(basis)
	transform = tr
	var _discard = move_and_collide(origin - transform.origin)
#	var tr = Transform(basis, origin)
