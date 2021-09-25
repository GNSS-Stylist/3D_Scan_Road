extends Label


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	var fp = get_node("../../FirstPerson")
	var speed = fp.velocityMultiplier * 100.0
	self.text = """Flying speed: %.0f""" % [speed]
