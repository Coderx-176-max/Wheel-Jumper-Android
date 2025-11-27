extends CanvasLayer

# Signals to communicate with player
signal movement_input(direction: Vector2)
signal jump_pressed
signal jump_released

# Node references
@onready var joystick_base: ColorRect = $JoystickContainer/JoystickBase
@onready var joystick_handle: ColorRect = $JoystickContainer/JoystickBase/JoystickHandle
@onready var left_button: Button = $ButtonsContainer/LeftButton
@onready var right_button: Button = $ButtonsContainer/RightButton
@onready var jump_button: Button = $ButtonsContainer/JumpButton

# Joystick variables
var joystick_active: bool = false
var joystick_radius: float = 50.0
var joystick_touch_index: int = -1

# Button states
var left_pressed: bool = false
var right_pressed: bool = false

func _ready():
	# Connect button signals
	left_button.pressed.connect(_on_left_pressed)
	left_button.released.connect(_on_left_released)
	
	right_button.pressed.connect(_on_right_pressed)
	right_button.released.connect(_on_right_released)
	
	jump_button.pressed.connect(_on_jump_pressed)
	jump_button.released.connect(_on_jump_released)
	
	# Hide on non-touch devices
	if not OS.has_touchscreen_ui_hint():
		hide()
	
	# Reset joystick position
	_reset_joystick()

func _input(event):
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)

func _handle_touch_event(event: InputEventScreenTouch):
	if event.pressed:
		# Check if touch is in joystick area
		var joystick_area = Rect2(
			joystick_base.global_position, 
			joystick_base.size
		)
		
		if joystick_area.has_point(event.position) and joystick_touch_index == -1:
			joystick_active = true
			joystick_touch_index = event.index
			_update_joystick(event.position)
	else:
		# Check if this is the joystick touch being released
		if event.index == joystick_touch_index:
			joystick_active = false
			joystick_touch_index = -1
			_reset_joystick()

func _handle_drag_event(event: InputEventScreenDrag):
	if joystick_active and event.index == joystick_touch_index:
		_update_joystick(event.position)

func _update_joystick(touch_position: Vector2):
	var joystick_center = joystick_base.global_position + joystick_base.size / 2
	var direction = touch_position - joystick_center
	var distance = direction.length()
	
	# Clamp to joystick radius
	if distance > joystick_radius:
		direction = direction.normalized() * joystick_radius
	
	# Update handle position
	joystick_handle.position = direction - Vector2(25, 25)
	
	# Calculate normalized direction (-1 to 1)
	var normalized_direction = direction / joystick_radius
	
	# Combine with button input
	var final_direction = Vector2(normalized_direction.x, normalized_direction.y)
	if left_pressed:
		final_direction.x = -1.0
	elif right_pressed:
		final_direction.x = 1.0
	
	movement_input.emit(final_direction)

func _reset_joystick():
	joystick_handle.position = Vector2(-25, -25)  # Center position
	
	# Only emit stop if buttons aren't pressed
	if not left_pressed and not right_pressed:
		movement_input.emit(Vector2.ZERO)
	else:
		# If buttons are pressed, use button direction
		var direction = Vector2.ZERO
		if left_pressed:
			direction.x = -1.0
		elif right_pressed:
			direction.x = 1.0
		movement_input.emit(direction)

func _on_left_pressed():
	left_pressed = true
	_update_movement_from_buttons()

func _on_left_released():
	left_pressed = false
	_update_movement_from_buttons()

func _on_right_pressed():
	right_pressed = true
	_update_movement_from_buttons()

func _on_right_released():
	right_pressed = false
	_update_movement_from_buttons()

func _on_jump_pressed():
	jump_pressed.emit()

func _on_jump_released():
	jump_released.emit()

func _update_movement_from_buttons():
	if joystick_active:
		return  # Joystick takes priority
	
	var direction = Vector2.ZERO
	if left_pressed:
		direction.x = -1.0
	elif right_pressed:
		direction.x = 1.0
	
	movement_input.emit(direction)

# Public method to enable/disable controls
func set_controls_enabled(enabled: bool):
	if enabled:
		show()
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		hide()
		process_mode = Node.PROCESS_MODE_DISABLED
