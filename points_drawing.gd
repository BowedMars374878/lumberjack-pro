extends Control

@onready var main = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _draw() -> void:
	var current_frame : int = main.video_player.current_frame
	
	for point in main.points:
		if point.frame_time == current_frame:
			draw_circle(point.screen_position, 3, Color.DEEP_SKY_BLUE)
		else:
			draw_circle(point.screen_position, 3, Color.SKY_BLUE)
