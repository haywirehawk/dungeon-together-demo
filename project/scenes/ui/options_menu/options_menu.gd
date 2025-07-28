extends CanvasLayer

#var old_master_volume: float
#var old_sfx_volume: float
#var old_music_volume: float
#var old_fullscreen_state: DisplayServer.WindowMode

var settings_data: SettingsData

# Master Volume
@onready var master_down_button: Button = %MasterDownButton
@onready var master_label: Label = %MasterLabel
@onready var master_slider: HSlider = %MasterProgressBar
@onready var master_up_button: Button = %MasterUpButton
# SFX Volume
@onready var sfx_down_button: Button = %SFXDownButton
@onready var sfx_label: Label = %SFXLabel
@onready var sfx_slider: HSlider = %SFXProgressBar
@onready var sfx_up_button: Button = %SFXUpButton
# Music Volume
@onready var music_down_button: Button = %MusicDownButton
@onready var music_label: Label = %MusicLabel
@onready var music_slider: HSlider = %MusicProgressBar
@onready var music_up_button: Button = %MusicUpButton
# Window Size
@onready var fullscreen_button: Button = %FullscreenButton

@onready var default_button: Button = %DefaultButton
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton


func _ready() -> void:
	update_display()
	#set_old_values()
	settings_data = SaveData.get_settings_data()
	
	master_slider.value_changed.connect(_on_slider_value_changed.bind("Master"))
	master_down_button.pressed.connect(_on_down_button_pressed.bind("Master"))
	master_up_button.pressed.connect(_on_up_button_pressed.bind("Master"))
	
	sfx_slider.value_changed.connect(_on_slider_value_changed.bind("SFX"))
	sfx_down_button.pressed.connect(_on_down_button_pressed.bind("SFX"))
	sfx_up_button.pressed.connect(_on_up_button_pressed.bind("SFX"))
	
	music_slider.value_changed.connect(_on_slider_value_changed.bind("Music"))
	music_down_button.pressed.connect(_on_down_button_pressed.bind("Music"))
	music_up_button.pressed.connect(_on_up_button_pressed.bind("Music"))
	
	fullscreen_button.pressed.connect(_on_fullscreen_button_pressed)
	default_button.pressed.connect(_on_default_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	UIAudioManager.register_buttons([
		master_down_button,
		master_up_button,
		sfx_down_button,
		sfx_up_button,
		music_down_button,
		music_up_button,
		fullscreen_button,
		default_button,
		confirm_button,
		cancel_button
	])


#func set_old_values() -> void:
	#old_master_volume = get_bus_volume("Master")
	#old_sfx_volume = get_bus_volume("SFX")
	#old_music_volume = get_bus_volume("Music")
	#old_fullscreen_state = DisplayServer.window_get_mode()
#
#
#func revert_to_old_values() -> void:
	#set_bus_volume("Master", old_master_volume)
	#set_bus_volume("SFX", old_sfx_volume)
	#set_bus_volume("Music", old_music_volume)
	#if old_fullscreen_state == DisplayServer.WINDOW_MODE_FULLSCREEN:
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	#else:
		#DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		#DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func update_display() -> void:
	master_slider.value = get_bus_volume("Master")
	sfx_slider.value = get_bus_volume("SFX")
	music_slider.value = get_bus_volume("Music")
	fullscreen_button.text = "Change to Fullscreen"
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		fullscreen_button.text = "Change to Windowed"


func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	return AudioServer.get_bus_volume_linear(index)


func change_bus_volume(bus_name: String, linear_change: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	var current_volume := get_bus_volume(bus_name)
	AudioServer.set_bus_volume_linear(index, clamp(current_volume + linear_change, 0, 1))
	
	update_display()


func set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_linear(index, clamp(value, 0, 1))
	
	update_display()


func _on_slider_value_changed(value: float, bus_name: String) -> void:
	set_bus_volume(bus_name, value)


func _on_down_button_pressed(bus_name: String) -> void:
	change_bus_volume(bus_name, -0.1)


func _on_up_button_pressed(bus_name: String) -> void:
	change_bus_volume(bus_name, 0.1)


func _on_fullscreen_button_pressed() -> void:
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	
	call_deferred("update_display")


func _on_default_button_pressed() -> void:
	SaveData.DEFAULT_SETTINGS.apply_all_from_data()
	update_display()


func _on_confirm_button_pressed() -> void:
	settings_data.set_data_from_current_state()
	SaveData.set_settings_data(settings_data)
	SaveData.save_settings()
	queue_free()


func _on_cancel_button_pressed() -> void:
	#revert_to_old_values()
	settings_data.apply_all_from_data()
	queue_free()
