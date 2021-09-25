extends CheckBox

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var pauseStartTime

# Called when the node enters the scene tree for the first time.
func _ready():
	pauseStartTime = OS.get_ticks_msec()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	# Pausing is now done in main just by setting replaySpeed to 0
	# when paused. This allows for some processing still happen
	# (like changing alphas of the objects)

	if Input.is_action_just_pressed("pause"):
		self.pressed = !self.pressed

	return
