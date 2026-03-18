extends Control

@onready var main = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if main.point_selected:
		draw_circle(main.selected_point, 3, Color.GREEN)
		draw_line(main.selected_point, get_global_mouse_position(), Color.GREEN)
