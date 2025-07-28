extends Control

var main_scene: PackedScene = preload("uid://ddpbjchb1i7gf")
var options_menu_scene: PackedScene = preload("uid://b80ylttiln1rp")

@onready var singleplayer_button: Button = $VBoxContainer/SingleplayerButton
@onready var multiplayer_button: Button = $VBoxContainer/MultiplayerButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var options_button: Button = $VBoxContainer/OptionsButton

@onready var multiplayer_menu_scene: PackedScene = load("uid://c5swte0kfe2fx")


func _ready() -> void:
	singleplayer_button.pressed.connect(_on_singleplayer_button_pressed)
	multiplayer_button.pressed.connect(_on_multiplayer_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	
	UIAudioManager.register_buttons([
		singleplayer_button,
		multiplayer_button,
		options_button,
		quit_button,
	])
	
	if OS.has_feature("web"):
		quit_button.hide()


func _on_singleplayer_button_pressed() -> void:
	get_tree().change_scene_to_packed(main_scene)


func _on_multiplayer_button_pressed() -> void:
	get_tree().change_scene_to_packed(multiplayer_menu_scene)


func _on_options_button_pressed() -> void:
	var options_menu := options_menu_scene.instantiate()
	add_child(options_menu)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
