extends CharacterBody2D

signal facing_direction_changed(direction: float)

@export var speed: float = 100.0
@export var jump_strength: float = -200.0
var gravity_factor: float = 1.0
var in_water: bool = false
var water_timer: float = 0.0
const WATER_DURATION: float = 2.0
const SINK_SPEED: float = 10.0
const WATER_DRAG: float = 0.5
const ENTRY_SPEED: float = 100.0
@export var collision_offset: float = 5.0
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.3

# New variable for touch movement persistence
var touch_move_direction: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var animated_sprite2: AnimatedSprite2D = $AnimatedSprite2D2
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var footstep_player: AudioStreamPlayer = $footstep
@onready var pause_panel: Panel = $PausePanel
@onready var resume_button: Button = $PausePanel/ResumeButton
@onready var quit_button: Button = $PausePanel/QuitButton

var is_teleporting: bool = false

func _ready() -> void:
	add_to_group("player")
	print("Player added to 'player' group")
	
	# Reset water state on scene load
	in_water = false
	water_timer = 0.0
	footstep_timer = 0.0
	is_teleporting = false
	touch_move_direction = 0.0 # Reset touch movement
	
	if animated_sprite:
		animated_sprite.play("idle")
	
	# Safely check for Global singleton to prevent crashes if running standalone
	if get_node_or_null("/root/Global"):
		print("Player _ready() called. Current Global.spawn_point: ", Global.spawn_point)
		if Global.spawn_point != Vector2.ZERO:
			global_position = Global.spawn_point
			velocity = Vector2.ZERO
			print("Respawned at checkpoint: ", global_position)
		else:
			print("No checkpoint set, using default position: ", global_position)
	else:
		print("Global singleton not found, skipping spawn point logic.")
	
	# Initialize pause menu
	if pause_panel:
		pause_panel.hide()
		pause_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		print("PausePanel found, hidden, and set to PROCESS_MODE_WHEN_PAUSED")
	else:
		push_error("PausePanel not found!")
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
		resume_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		print("ResumeButton found, signal connected, and set to PROCESS_MODE_WHEN_PAUSED")
	else:
		push_error("ResumeButton not found!")
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)
		quit_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		print("QuitButton found, signal connected, and set to PROCESS_MODE_WHEN_PAUSED")
	else:
		push_error("QuitButton not found!")
	
	# Existing debug checks
	if animated_sprite == null:
		push_error("AnimatedSprite node not found!")
	if collision_shape == null:
		push_error("CollisionShape2D node not found!")
	if footstep_player == null:
		push_error("Footstep AudioStreamPlayer node not found!")

# Handle Touch Inputs here
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		# Check for Double Tap (Movement)
		if event.double_tap:
			var viewport_center = get_viewport_rect().size.x / 2.0
			
			if event.position.x > viewport_center:
				# Double tap right side -> Move Right
				touch_move_direction = 1.0
				print("Touch: Double Tap Right -> Moving Right")
			else:
				# Double tap left side -> Move Left
				touch_move_direction = -1.0
				print("Touch: Double Tap Left -> Moving Left")
				
		# Check for Single Tap (Jump)
		# Note: Logic dictates if it's NOT a double tap processed yet, we jump.
		# In Godot, the first tap of a double tap is also sent as a press.
		# We allow jumping on the first tap for responsiveness.
		else:
			if is_on_floor() or in_water:
				velocity.y = jump_strength
				print("Touch: Single Tap -> Jump")

# Keep global inputs (like Pause or Debug keys) in _input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("FUCK YOU"):
		enter_water()
		print("Test: Entered water via Down Arrow")
	if event.is_action_pressed("ui_cancel"):  # Esc key
		toggle_pause()

func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	
	# print("Player position: ", global_position) # Commented out to reduce log spam
	
	if in_water:
		velocity.y = SINK_SPEED
		
		# Get direction from Input (Keyboard/Gamepad)
		var direction: float = Input.get_axis("left", "right")
		
		# If no Keyboard input, use Touch input
		if direction == 0:
			direction = touch_move_direction
			
		velocity.x = direction * speed * WATER_DRAG
		
		if animated_sprite:
			animated_sprite.flip_h = direction > 0 if direction != 0 else animated_sprite.flip_h
			animated_sprite.play("swimming")
			update_collision_position(direction)
			
		water_timer += delta
		if water_timer >= WATER_DURATION and not is_teleporting:
			print("Drowning!")
			die()
	else:
		if not is_on_floor():
			velocity += get_gravity() * gravity_factor * delta

		# Keyboard Jump
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = jump_strength
			print("Jumped via Keyboard!")

		# Movement Logic
		var direction: float = Input.get_axis("left", "right")
		
		# If no Keyboard input, use Touch input
		if direction == 0:
			direction = touch_move_direction

		# Visuals
		if animated_sprite:
			if direction != 0:
				animated_sprite.flip_h = direction > 0
				emit_signal("facing_direction_changed", 1.0 if direction > 0 else -1.0)
			
			if not is_on_floor():
				animated_sprite.play("jumping")
			elif direction != 0:
				animated_sprite.play("walking")
			else:
				animated_sprite.play("idle")
			update_collision_position(direction)

		# Physics Application
		if direction != 0:
			velocity.x = direction * speed
			if is_on_floor() and footstep_player:
				footstep_timer += delta
				if footstep_timer >= FOOTSTEP_INTERVAL:
					footstep_player.play()
					footstep_timer = 0.0
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			footstep_timer = 0.0

	move_and_slide()

func update_collision_position(direction: float) -> void:
	if collision_shape:
		if direction > 0:
			collision_shape.position.x = collision_offset
		elif direction < 0:
			collision_shape.position.x = -collision_offset
		else:
			collision_shape.position.x = 0

func enter_water() -> void:
	in_water = true
	water_timer = 0.0
	velocity.x = 0
	velocity.y = ENTRY_SPEED
	# When entering water, we might want to stop auto-running
	touch_move_direction = 0.0 
	if animated_sprite:
		animated_sprite.play("swimming")
	footstep_timer = 0.0
	print("Entered water!")

func exit_water() -> void:
	in_water = false
	velocity.y = 0
	water_timer = 0.0
	footstep_timer = 0.0
	if animated_sprite:
		animated_sprite.play("idle")
	print("Exited water!")

func die() -> void:
	if is_teleporting:
		print("Player is teleporting, skipping die()")
		return
	
	print("Player died, reloading scene.")
	
	if get_node_or_null("/root/Global"):
		print("Reloading with spawn point: ", Global.spawn_point)
		
	var error = get_tree().reload_current_scene()
	if error != OK:
		push_error("Failed to reload scene, error code: ", error)

func set_gravity_factor(factor: float) -> void:
	gravity_factor = factor
	print("Gravity factor set to: ", gravity_factor)

func get_gravity_factor() -> float:
	return gravity_factor

func get_facing_direction() -> float:
	var facing = 1.0 if animated_sprite.flip_h else -1.0
	print("Player facing direction: ", facing, " (flip_h: ", animated_sprite.flip_h, ")")
	return facing

# Toggle function
func toggle_pause() -> void:
	if pause_panel.visible:
		pause_panel.hide()
		get_tree().paused = false
		print("Resumed!")
	else:
		pause_panel.show()
		get_tree().paused = true
		print("Paused!")

func _on_resume_button_pressed() -> void:
	print("Resume button pressed!")
	toggle_pause()

func _on_quit_button_pressed() -> void:
	print("Quit button pressed!")
	get_tree().quit()

func _on_settings_button_pressed() -> void:
	pass
