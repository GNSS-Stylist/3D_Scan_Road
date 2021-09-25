extends Spatial

enum KEY { up, down, left, right, a, b }

var keyBuffer = []
var compareBuffer = [ KEY.up, KEY.up, KEY.down, KEY.down, KEY.left, KEY.right, KEY.left, KEY.right, KEY.b, KEY.a]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func _process(_delta):
	pass


func _physics_process(_delta):
	pass
#	if (!get_tree().paused):
#		transform = transform.rotated(Vector3.UP, delta * 0.5)
