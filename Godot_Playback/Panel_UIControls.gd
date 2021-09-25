extends Panel


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	$OptionButton_MSAA.add_item("None", get_viewport().MSAA_DISABLED)
	$OptionButton_MSAA.add_item("2x", get_viewport().MSAA_2X)
	$OptionButton_MSAA.add_item("4x", get_viewport().MSAA_4X)
	$OptionButton_MSAA.add_item("8x", get_viewport().MSAA_8X)
	$OptionButton_MSAA.add_item("16x", get_viewport().MSAA_16X)
	$OptionButton_MSAA.select(get_viewport().MSAA_4X)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	get_viewport().set_msaa($OptionButton_MSAA.get_selected_id())
	
	get_node("../Background").visible = get_node("CheckBox_Walls").pressed
	get_node("../Background_Blue").visible = get_node("CheckBox_Background_Blue").pressed
	get_node("../Background_Black").visible = get_node("CheckBox_Background_Black").pressed
	get_node("../Ground").visible = get_node("CheckBox_Ground").pressed

	get_node("../Buildings_Blue").visible = get_node("CheckBox_Buildings_Blue").pressed

	get_node("../Road_Blue").visible = get_node("CheckBox_Road_Blue").pressed

	get_node("../LOSolver_VanScanner/MB100D_Full").visible = get_node("CheckBox_Van_WithRig").pressed
	get_node("../LOSolver_VanScanner/MB100D_NoRig").visible = get_node("CheckBox_Van_WithoutRig").pressed
	get_node("../LOSolver_VanScanner/LidarAndCameraRig").visible = get_node("CheckBox_Rig").pressed

	get_node("../Plate").visible = get_node("CheckBox_Plate").pressed
	get_node("../CalibGround").visible = get_node("CheckBox_CalibGround").pressed
	get_node("../CalibBox").visible = get_node("CheckBox_CalibBox").pressed
	get_node("../CalibBox_Blue").visible = get_node("CheckBox_CalibBox_Blue").pressed
	get_node("../LOSolver_VanScanner/FrontBlueMask").visible = get_node("CheckBox_FrontMask_Blue").pressed

	get_node("../LOSolver_CameraRigAndCar/Car/Car_White").visible = get_node("CheckBox_Car").pressed
	get_node("../LOSolver_CameraRigAndCar/Car/Car_Blue").visible = get_node("CheckBox_Car_Blue").pressed
