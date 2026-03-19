extends Control

enum GraphMode { POSITION_X, POSITION_Y, VELOCITY_X, VELOCITY_Y }
enum PointAxis { X, Y }
var graph_mode : GraphMode = GraphMode.POSITION_X
var point_axis : PointAxis = PointAxis.X

@onready var main : Control = get_parent()
@onready var graph_label : Label = $GraphLabel
@onready var vertical_indicator_container = $VBoxContainer
@onready var horizontal_indicator_container = $HBoxContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _draw() -> void:
	var bounds : Dictionary
	
	if len(main.points) > 0:
		if graph_mode == GraphMode.POSITION_X:
			bounds = get_position_data()
		elif graph_mode == GraphMode.POSITION_Y:
			bounds = get_position_data()
		elif graph_mode == GraphMode.VELOCITY_X:
			bounds = get_velocity_data()
		elif graph_mode == GraphMode.VELOCITY_Y:
			bounds = get_velocity_data()
		
		if bounds == {}:
			main.error_logger.text = "Graph mode data returned empty."
			return
	
	var right_bound = size.x
	var vertical_line_distance = size.y / 12
	
	for i in range(1, 12):
		draw_line(
			Vector2(0, vertical_line_distance * i),
			Vector2(right_bound, vertical_line_distance * i),
			Color.LIGHT_GRAY
		)
	
	var bottom_bound = size.y
	var horizontal_line_distance = size.x / 12
	
	for i in range(1, 12):
		draw_line(
			Vector2(horizontal_line_distance * i, 0),
			Vector2(horizontal_line_distance * i, bottom_bound),
			Color.LIGHT_GRAY
		)
	
	if bounds == {}:
		return
	
	var iterations = 0
	
	for child in vertical_indicator_container.get_children():
		iterations += 1
		child.text = str(snapped(bounds.max_var - iterations * bounds.increment_var, 0.01))
	
	iterations = 0
	
	for child in horizontal_indicator_container.get_children():
		iterations += 1
		child.text = str(snapped(iterations * bounds.increment_time, 0.01))
	
	var pixel_to_meter_scale : Vector2 = Vector2(
		size.x / (bounds.max_time - bounds.min_time),
		size.y / (bounds.max_var - bounds.min_var)
	)
	
	var minimums : Vector2 = Vector2(bounds.min_time, bounds.min_var)
	
	for point in bounds.points:
		var point_position : Vector2 = point - minimums
		point_position *= pixel_to_meter_scale
		point_position.y = size.y - point_position.y # Since lower numbers would otherwise be at the top of the screen
		draw_circle(point_position, 3, Color.RED)


func get_position_data() -> Dictionary:
	var points_to_draw : Array[Vector2] = []
	
	var min_position : float = INF
	var max_position : float = -INF
	var min_time : float = INF
	var max_time : float = -INF
	
	for point in main.points:
		var point_position : float
		
		if point_axis == PointAxis.X:
			point_position = point.get_position().x
		if point_axis == PointAxis.Y:
			point_position = point.get_position().y
		
		if point_position < min_position:
			min_position = point_position
		if point_position > max_position:
			max_position = point_position
		
		if point.time < min_time:
			min_time = point.time
		if point.time > max_time:
			max_time = point.time
		
		points_to_draw.append(Vector2(point.time, point_position))
	
	var position_range : float = max_position - min_position
	var time_range : float = max_time - min_time
	
	max_position += position_range * .1
	min_position -= position_range * .1
	max_time += time_range * .1
	min_time -= time_range * .1
	
	var increment_position = position_range * 0.1
	var increment_time = time_range * 0.1
	
	return {
		"min_var": min_position,
		"max_var": max_position,
		"min_time": min_time,
		"max_time": max_time,
		"increment_var": increment_position,
		"increment_time": increment_time,
		"points": points_to_draw
	}


func get_velocity_data() -> Dictionary:
	var velocity_points : Array[Vector2] = []
	var points_to_draw : Array[Vector2] = []
	
	var min_velocity : float = INF
	var max_velocity : float = -INF
	var min_time : float = INF
	var max_time : float = -INF
	
	var previous_position : float
	var previous_time : float = main.points[0].time
	var previous_velocities : Array[float] = []
	
	if point_axis == PointAxis.X:
		previous_position = main.points[0].get_position().x
	if point_axis == PointAxis.Y:
		previous_position = main.points[0].get_position().y
	
	for i in range(1, len(main.points)):
		var point = main.points[i]
		var point_position : float
		
		if point_axis == PointAxis.X:
			point_position = point.get_position().x
		if point_axis == PointAxis.Y:
			point_position = point.get_position().y
		
		previous_velocities.append((point_position - previous_position)/(point.time - previous_time))
		var average_velocity : float = 0
		
		for velocity in previous_velocities:
			average_velocity += velocity
		average_velocity /= len(previous_velocities)
		
		velocity_points.append(Vector2(point.time, average_velocity))
		previous_position = point_position
		previous_time = point.time
		
		if len(previous_velocities) >= 3:
			previous_velocities.remove_at(0)
	
	for point in velocity_points:
		
		if point.y < min_velocity:
			min_velocity = point.y
		if point.y > max_velocity:
			max_velocity = point.y
		
		if point.x < min_time:
			min_time = point.x
		if point.x > max_time:
			max_time = point.x
		
		points_to_draw.append(point)
	
	var velocity_range : float = max_velocity - min_velocity
	var time_range : float = max_time - min_time
	
	max_velocity += velocity_range * .1
	min_velocity -= velocity_range * .1
	max_time += time_range * .1
	min_time -= time_range * .1
	
	var increment_velocity = velocity_range * 0.1
	var increment_time = time_range * 0.1
	
	return {
		"min_var": min_velocity,
		"max_var": max_velocity,
		"min_time": min_time,
		"max_time": max_time,
		"increment_var": increment_velocity,
		"increment_time": increment_time,
		"points": points_to_draw
	}


func _on_change_mode_pressed() -> void:
	if graph_mode == GraphMode.POSITION_X:
		graph_label.text = "Y Position vs. Time"
		graph_mode = GraphMode.POSITION_Y
		point_axis = PointAxis.Y
	elif graph_mode == GraphMode.POSITION_Y:
		graph_label.text = "X Velocity vs. Time"
		graph_mode = GraphMode.VELOCITY_X
		point_axis = PointAxis.X
	elif graph_mode == GraphMode.VELOCITY_X:
		graph_label.text = "Y Velocity vs. Time"
		graph_mode = GraphMode.VELOCITY_Y
		point_axis = PointAxis.Y
	elif graph_mode == GraphMode.VELOCITY_Y:
		graph_label.text = "X Position vs. Time"
		graph_mode = GraphMode.POSITION_X
		point_axis = PointAxis.X
	
	queue_redraw()
