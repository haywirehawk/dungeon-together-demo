extends Node

@onready var ui_button_audio_player: AudioStreamPlayer = $UIButtonAudioPlayer


func _ready() -> void:
	_load_settings()


func register_buttons(buttons: Array) -> void:
	for button in buttons:
		button.pressed.connect(_on_button_pressed)


func _load_settings() -> void:
	SaveData.get_settings_data().apply_audio_from_data()


func _on_button_pressed():
	ui_button_audio_player.play()
