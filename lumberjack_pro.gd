extends Control

const version_number = 1.3

var base_directory : String = OS.get_system_dir(OS.SYSTEM_DIR_MOVIES)
var file_types : PackedStringArray = PackedStringArray(["*"])
var file_extension : PackedStringArray = PackedStringArray(["*.lumber"])

var selected_tool : String = "cursor" ## The currently selected tool.
var selected_point : Vector2 = Vector2(-1, -1) ## The currently selected point (used by the Ruler Tool).
var point_selected : bool = false ## Whether a starting point is currently selected for the Ruler Tool.
var meter_length : float ## The length of a meter in pixels.
var second_length : float ## The length of a second in frames (the fps).

var video_loaded = false
var temp_video_path
var video_path
var video_player_degrees : int = 0
var frames_to_skip : int = 0

var points : Array[Point] = []

@onready var error_logger : Label = $Panel/ErrorLog
@onready var video_player : VideoPlayback = $VideoPlayerCenter/VideoPlayer
@onready var video_player_box : ColorRect = $VideoPlayerCenter/VideoPlayer/ColorRect
@onready var video_timeline : HSlider = $TimelineBar
@onready var graph: ColorRect = $Graph

@onready var eraser_button : Button = $EraserTool
@onready var pencil_button : Button = $PencilTool
@onready var ruler_button : Button = $SetScaleTool
@onready var cursor_button : Button = $CursorTool

@onready var play_button : Button = $PlayButton
@onready var play_icon : TextureRect = $PlayButton/Play
@onready var pause_icon : TextureRect = $PlayButton/Pause

@onready var point_renderer : Control = $PointsDrawing

@onready var video_default_size : Vector2i = video_player.size
@onready var video_size : Vector2i = video_player.size

@onready var frames_edit : LineEdit = $Panel2/LineEdit

## Class for storing data about a point.
class Point:
	var screen_position : Vector2 ## Position in pixels of where the click occurred.
	var original_screen_position : Vector2
	var frame_time : int ## Time in frames.
	var time : float ## Time in seconds.
	var position_scale : float
	var video_scale : Vector2
	
	func _init(screen_coordinates : Vector2, frame : int, second: float, pos_scale : float, video_player_size : Vector2, original_screen_coordinates : Vector2 = screen_coordinates):
		self.screen_position = screen_coordinates
		self.original_screen_position = original_screen_coordinates
		self.frame_time = frame
		self.time = second
		self.position_scale = pos_scale
		self.video_scale = video_player_size
	
	func get_position() -> Vector2:
		return Vector2(screen_position.x / position_scale, (video_scale.y - screen_position.y) / position_scale)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	error_logger.text = ""
	cursor_button.button_pressed = true
	play_icon.show()
	pause_icon.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if video_loaded:
		if selected_tool == "cursor":
			return
	
	if Input.is_action_just_pressed("m1"):
		handle_click()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("play"):
		_on_play_button_pressed()
	if event.is_action_pressed("erase"):
		eraser_button.button_pressed = true
		_on_eraser_tool_pressed()
	if event.is_action_pressed("scale"):
		ruler_button.button_pressed = true
		_on_set_scale_tool_pressed()
	if event.is_action_pressed("add"):
		pencil_button.button_pressed = true
		_on_pencil_tool_pressed()
	if event.is_action_pressed("cursor"):
		cursor_button.button_pressed = true
		_on_cursor_tool_pressed()
	if event.is_action_pressed("next_frame"):
		_on_next_frame_pressed()
	if event.is_action_pressed("save"):
		_on_save_pressed()
	if event.is_action_pressed("rotate"):
		_on_rotate_pressed()


func handle_click() -> void:
	var mouse_location : Vector2 = get_global_mouse_position()
	
	if mouse_location.x > video_size.x or mouse_location.y > video_size.y:
		return
	
	if selected_tool == "set_scale":
		if !point_selected:
			selected_point = mouse_location # Sets a first point if there isn't one already
			point_selected = true
		else:
			meter_length = selected_point.distance_to(mouse_location)
			point_selected = false
			selected_point = Vector2(-1, -1)
			
			for point in points:
				point.position_scale = meter_length
			
			point_renderer.queue_redraw()
			graph.queue_redraw()
	
	elif selected_tool == "pencil":
		if meter_length == 0.0:
			error_logger.text = "Use the ruler tool to set a scale first!" # Can't graph points without first setting the scale
			return
		else:
			for point in points:
				if point.frame_time == video_player.current_frame:
					error_logger.text = "You already have a point for this frame!"
					return
			
			var frame_time =  video_player.current_frame
			
			points.append(Point.new(mouse_location, frame_time, frame_time / second_length, meter_length, video_player.size))
			
			for i in range(frames_to_skip):
				video_player.next_frame()
				video_player.current_frame += 1
				
			point_renderer.queue_redraw()
			graph.queue_redraw()
	
	elif selected_tool == "eraser":
		var nearest_point : Point
		var shortest_distance : float
		
		for point in points:
			if nearest_point == null:
				nearest_point = point
				shortest_distance = nearest_point.screen_position.distance_to(mouse_location)
			elif point.screen_position.distance_to(mouse_location) < shortest_distance:
				nearest_point = point
				shortest_distance = nearest_point.screen_position.distance_to(mouse_location)
		
		if shortest_distance < 3:
			points.erase(nearest_point)
			point_renderer.queue_redraw()
			graph.queue_redraw()


func _on_import_button_pressed() -> void:
	var error : Error = DisplayServer.file_dialog_show("Open video", base_directory, "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, file_types, _on_file_selected)
	if error:
		error_logger.text = "Error with file selection."


func _on_file_selected(success: bool, filepaths: PackedStringArray, chosen_filetype: int) -> void:
	if success == false:
		error_logger.text = "File selection cancelled by user."
		return
	
	temp_video_path = filepaths[0]
	video_player.set_video_path(filepaths[0])


func _on_eraser_tool_pressed() -> void:
	selected_tool = "eraser"


func _on_set_scale_tool_pressed() -> void:
	selected_tool = "set_scale"


func _on_pencil_tool_pressed() -> void:
	selected_tool = "pencil"


func _on_cursor_tool_pressed() -> void:
	selected_tool = "cursor"


func _on_video_loaded() -> void:
	video_timeline.max_value = video_player.get_video_frame_count()
	video_timeline.value = 0
	second_length = video_player.get_video_framerate()
	video_path = temp_video_path
	video_loaded = true
	video_player.pause()
	point_renderer.queue_redraw()
	graph.queue_redraw()
	play_button.button_pressed = false


func _on_video_player_next_frame_called(frame_nr: int) -> void:
	video_timeline.value = frame_nr
	point_renderer.queue_redraw()


func _on_play_button_pressed() -> void:
	if !video_loaded:
		play_button.button_pressed = false # Video can't play unless it's open
		error_logger.text = "No video loaded!"
		return
	
	if play_button.button_pressed:
		play_icon.hide()
		pause_icon.show()
		video_player.play()
	
	else:
		pause_icon.hide()
		play_icon.show()
		video_player.pause()


func _on_timeline_bar_drag_ended(value_changed: bool) -> void:
	video_player.seek_frame(video_timeline.value) # Update on drag ended for performance reasons
	pause_icon.hide()
	play_icon.show()
	video_player.pause()
	point_renderer.queue_redraw()
	graph.queue_redraw()
	play_button.button_pressed = false


func _on_next_frame_pressed() -> void:
	if !video_loaded:
		play_button.button_pressed = false # Video can't play unless it's open
		error_logger.text = "No video loaded!"
		return
	
	video_player.next_frame()
	video_player.current_frame += 1


func _on_save_pressed() -> void:
	var error : Error = DisplayServer.file_dialog_show("Save graph", base_directory, "", false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, file_extension, save_to_file)
	if error:
		error_logger.text = "Error with file selection."


func save_to_file(success: bool, filepaths: PackedStringArray, chosen_filetype: int) -> void:
	if success == false:
		error_logger.text = "File selection cancelled by user."
		return
	
	var filepath : String = filepaths[0]
	if !filepath.ends_with(".lumber"):
		filepath += ".lumber"
	
	var save_file = FileAccess.open(filepath, FileAccess.WRITE)
	
	var graph_info = {
		"version_number": version_number,
		"video_scale_x": video_size.x,
		"video_scale_y": video_size.y,
		"meter_length": meter_length,
		"video_path": video_path,
		"video_player_degrees": video_player_degrees,
		"frames_to_skip": frames_to_skip
	}
	
	# JSON provides a static method to serialized JSON string.
	var info_string = JSON.stringify(graph_info)

	# Store the save dictionary as a new line in the save file.
	save_file.store_line(info_string)
	
	for point : Point in points:
		var save_dict = {
			"screen_position_x": point.screen_position.x,
			"screen_position_y": point.screen_position.y,
			"original_screen_position_x": point.original_screen_position.x,
			"original_screen_position_y": point.original_screen_position.y,
			"time": point.time,
			"frame_time": point.frame_time,
		}
		
		# JSON provides a static method to serialized JSON string.
		var json_string = JSON.stringify(save_dict)

		# Store the save dictionary as a new line in the save file.
		save_file.store_line(json_string)


func _on_load_pressed() -> void:
	var error : Error = DisplayServer.file_dialog_show("Load graph", base_directory, "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, file_extension, load_from_file)
	if error:
		error_logger.text = "Error with file selection."


func load_from_file(success: bool, filepaths: PackedStringArray, chosen_filetype: int) -> void:
	if success == false:
		error_logger.text = "File selection cancelled by user."
		return
	
	var filepath : String = filepaths[0]
	
	if not FileAccess.file_exists(filepath):
		return # Error! We don't have a save to load.
	
	var save_file = FileAccess.open(filepath, FileAccess.READ)

	# Creates the helper class to interact with JSON.
	var json = JSON.new()
	var parse_result = json.parse(save_file.get_line())
	
	if not parse_result == OK:
		error_logger.text = "Failed to load file: Error parsing json."
		return
	
	save_file.seek(0) # Move back to the start of the file to begin reading
	if json.data.has("version_number"):
		load_file(save_file)
	else:
		legacy_load_file(save_file)


func load_file(save_file) -> void:
	var graph_info = save_file.get_line()
	var json = JSON.new()
	var graph_parse_result = json.parse(graph_info)
	var graph_data = json.data
	
	video_size = Vector2(graph_data.video_scale_x, graph_data.video_scale_y)
	meter_length = graph_data.meter_length
	frames_to_skip = graph_data.frames_to_skip
	frames_edit.text = str(frames_to_skip)
	
	if graph_data.has("video_path") and graph_data.video_path != null:
		if FileAccess.file_exists(graph_data.video_path):
			video_path = graph_data.video_path
			_on_file_selected(true, PackedStringArray([video_path]), 0)
			
			video_player_degrees = graph_data.video_player_degrees
			rotate_video_player()
		else:
			error_logger.text = "Failed to find saved video at filepath."
	
	points = []
	
	# Load the file line by line and process that dictionary to restore
	# the object it represents.
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		
		# Check if there is any error while parsing the JSON string, skip in case of failure.
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		
		# Get the data from the JSON object.
		var point_data = json.data
		# And load it as a point.
		points.append(Point.new(Vector2(point_data.screen_position_x, point_data.screen_position_y), point_data.frame_time, point_data.time, meter_length, video_size, Vector2(point_data.original_screen_position_x, point_data.original_screen_position_y)))
	
	point_renderer.queue_redraw()
	graph.queue_redraw()


func legacy_load_file(save_file) -> void:
	points = []

	# Load the file line by line and process that dictionary to restore
	# the object it represents.
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		
		# Creates the helper class to interact with JSON.
		var json = JSON.new()
		
		# Check if there is any error while parsing the JSON string, skip in case of failure.
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		
		# Get the data from the JSON object.
		var point_data = json.data
		
		var point_position : Vector2 = Vector2(point_data.screen_position_x, point_data.screen_position_y)
		point_position.y = point_position.y * 500 / 340 # The video player size changed since v1.2.1
		
		# And load it as a point.
		points.append(Point.new(point_position, point_data.frame_time, point_data.time, point_data.position_scale, Vector2(point_data.video_scale_x, point_data.video_scale_y), point_position))
	
	point_renderer.queue_redraw()
	graph.queue_redraw()


func rotate_video_player():
	if (video_player_degrees / 90) % 2 != 0:
		video_player.rotation_degrees = video_player_degrees
		video_size = Vector2(video_default_size.y, video_default_size.x)
		
		if video_player_degrees == 270:
			for point in points:
				point.screen_position = Vector2(point.original_screen_position.y, point.original_screen_position.x)
		else:
			for point in points:
				point.screen_position = Vector2(video_size.x - point.original_screen_position.y, video_size.y - point.original_screen_position.x)
	else:
		video_player.rotation_degrees = video_player_degrees
		video_size = video_default_size
		
		if video_player_degrees == 180:
			for point in points:
				point.screen_position = Vector2(video_size) - point.original_screen_position
		else:
			for point in points:
				point.screen_position = point.original_screen_position
	
	video_player.size = video_size
	video_player_box.size = video_size
	
	video_player_box.pivot_offset = video_size / 2
	video_player.pivot_offset = video_size / 2
	
	video_player.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	video_player_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	
	point_renderer.queue_redraw()
	graph.queue_redraw()


func _on_rotate_pressed() -> void:
	video_player_degrees += 90
	if video_player_degrees == 360:
		video_player_degrees = 0
	rotate_video_player()


func _on_line_edit_text_changed(new_text: String) -> void:
	frames_to_skip = int(new_text)
