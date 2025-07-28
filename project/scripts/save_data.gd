extends Node

const PATH: String = "user://"
const DEFAULT_SETTINGS: SettingsData = preload("uid://grq286mlyh8l")

var _file_name: String = "save.res"
var _settings_name: String = "settings.tres"
var _player_data: PlayerData
var _settings_data: SettingsData


## Returns the last saved data, or creates a new resource if needed
func get_player_data() -> PlayerData:
	if _player_data == null:
		load_game()
	
	return _player_data


func set_player_data(new_data: PlayerData) -> void:
	_player_data = new_data


## Returns the last saved settings data, or creates a new resource if needed
func get_settings_data() -> SettingsData:
	if _settings_data == null:
		load_settings()
	
	return _settings_data


func set_settings_data(new_data: SettingsData) -> void:
	_settings_data = new_data


func new_game() -> void:
	_player_data = PlayerData.new()


func save_game() -> void:
	ResourceSaver.save(_player_data, PATH + _file_name)


func load_game() -> void:
	if ResourceLoader.exists(PATH + _file_name):
		_player_data = ResourceLoader.load(PATH + _file_name)
	else:
		print("No save to load, creating new player save")
		new_game()


func save_settings() -> void:
	ResourceSaver.save(_settings_data, PATH + _settings_name)


func load_settings() -> void:
	if ResourceLoader.exists(PATH + _settings_name):
		_settings_data = ResourceLoader.load(PATH + _settings_name)
	else:
		_settings_data = DEFAULT_SETTINGS.duplicate()
