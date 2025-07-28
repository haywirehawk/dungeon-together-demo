class_name SettingsData
extends Resource

# Audio
@export_range(0.0, 1.0, 0.1) var master_volume: float
@export_range(0.0, 1.0, 0.1) var sfx_volume: float
@export_range(0.0, 1.0, 0.1) var music_volume: float
# Window Sizing
@export var window_mode: DisplayServer.WindowMode


func apply_all_from_data() -> void:
	apply_audio_from_data()
	apply_window_sizing_from_data()


func apply_audio_from_data() -> void:
	var index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_linear(index, clamp(master_volume, 0, 1))
	index = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_linear(index, clamp(sfx_volume, 0, 1))
	index = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_linear(index, clamp(music_volume, 0, 1))


func apply_window_sizing_from_data() -> void:
	DisplayServer.window_set_mode(window_mode)
	if window_mode == DisplayServer.WindowMode.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)


func set_data_from_current_state() -> void:
	var index := AudioServer.get_bus_index("Master")
	master_volume = AudioServer.get_bus_volume_linear(index)
	index = AudioServer.get_bus_index("SFX")
	sfx_volume = AudioServer.get_bus_volume_linear(index)
	index = AudioServer.get_bus_index("Music")
	music_volume = AudioServer.get_bus_volume_linear(index)
	window_mode = DisplayServer.window_get_mode()
