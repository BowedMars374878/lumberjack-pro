extends Control

var confirmation : bool
signal button_clicked

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func get_confirmation() -> bool:
	confirmation = false # Default to false for safety
	show()
	grab_focus()
	await button_clicked # When signal is emitted, it's safe to say that confirmation has been set
	release_focus()
	hide()
	return confirmation # Tell Lumberjack Pro the result


func _on_no_pressed() -> void:
	confirmation = false
	button_clicked.emit()


func _on_yes_pressed() -> void:
	confirmation = true
	button_clicked.emit()
