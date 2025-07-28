class_name PlayerInputSynchronizerComponent
extends MultiplayerSynchronizer

@export var aim_root: Node2D

var movement_vector := Vector2.ZERO
var aim_vector: Vector2 = Vector2.RIGHT
var mouse_aim_vector: Vector2 = Vector2.RIGHT
var joypad_aim_vector: Vector2 = Vector2.RIGHT # TODO: Fix joypad analog stick aiming
var is_attack_pressed: bool
var joystick_mode: bool


func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		gather_input()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion:
		joystick_mode = true
	else:
		joystick_mode = false


func gather_input() -> void:
	movement_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.2)
	mouse_aim_vector = aim_root.global_position.direction_to(aim_root.get_global_mouse_position())
	joypad_aim_vector = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	is_attack_pressed = Input.is_action_pressed("attack")
	
	if joystick_mode:
		aim_vector = joypad_aim_vector
	else:
		aim_vector = mouse_aim_vector
		# Restricts keyboard movement to cardinals to avoid unintended joypad inputs.
		movement_vector = movement_vector.snapped(Vector2(1.0, 1.0)).normalized()
