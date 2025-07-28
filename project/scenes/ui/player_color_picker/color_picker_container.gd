class_name ColorPickerContainer
extends HBoxContainer

var chosen_color: Color = Color.WHITE
var chosen_character_set: String = "A"

@onready var chosen_color_viewer: AnimatedSprite2D = %ChosenColorViewer
@onready var animation_timer: Timer = $AnimationTimer
@onready var control_a: Control = $VBoxContainer/ControlA
@onready var control_b: Control = $VBoxContainer/ControlB
@onready var control_c: Control = $VBoxContainer/ControlC
@onready var control_d: Control = $VBoxContainer/ControlD

func _ready() -> void:
	animation_timer.timeout.connect(_on_animatation_timer_timeout)
	control_a.gui_input.connect(_on_character_option_clicked.bind("A"))
	control_b.gui_input.connect(_on_character_option_clicked.bind("B"))
	control_c.gui_input.connect(_on_character_option_clicked.bind("C"))
	control_d.gui_input.connect(_on_character_option_clicked.bind("D"))
	
	for color in PlayerCharacterOptions.PLAYER_PALETTE.colors:
		create_color_option(color)
	
	chosen_character_set = MultiplayerConfig.character_set
	chosen_color = MultiplayerConfig.color
	update_display()


func update_display() -> void:
	chosen_color_viewer.self_modulate = chosen_color
	chosen_color_viewer.material.set_shader_parameter("modulate_color", chosen_color)
	chosen_color_viewer.sprite_frames = PlayerCharacterOptions.get_character_set_sprite_frames(chosen_character_set)
	set_character_options()


func set_character_options() -> void:
	MultiplayerConfig.color = chosen_color
	MultiplayerConfig.character_set = chosen_character_set


func create_color_option(color: Color) -> void:
	var option := Button.new()
	option.custom_minimum_size = Vector2(30, 30)
	option.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var stylebox_normal := StyleBoxFlat.new()
	stylebox_normal.border_color = Color(0, 0, 0)
	stylebox_normal.border_width_top = 1
	stylebox_normal.border_width_bottom = 1
	stylebox_normal.border_width_left = 1
	stylebox_normal.border_width_right = 1
	stylebox_normal.bg_color = color
	var stylebox_focus := stylebox_normal.duplicate()
	stylebox_focus.border_color = Color(.7, .7, .7)
	var stylebox_hover := stylebox_normal.duplicate()
	stylebox_hover.border_color = Color(.7, .7, .7)
	var stylebox_pressed := stylebox_normal.duplicate()
	stylebox_pressed.border_color = Color(1, 1, 1)
	
	option.add_theme_stylebox_override("normal", stylebox_normal)
	option.add_theme_stylebox_override("pressed", stylebox_pressed)
	option.add_theme_stylebox_override("hover", stylebox_pressed)
	
	add_child(option)
	option.pressed.connect(_on_color_option_pressed.bind(color))


func _on_color_option_pressed(color: Color) -> void:
	chosen_color = color
	update_display()


func _on_character_option_clicked(event: InputEvent, character_set: String) -> void:
	if event is InputEventMouseButton:
		chosen_character_set = character_set
		update_display()


func _on_animatation_timer_timeout() -> void:
	var random_animation: String = [
		"default",
		"move",
		"dead",
		"action",
	].pick_random()
	chosen_color_viewer.play(random_animation)
