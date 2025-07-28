class_name PauseMenu
extends CanvasLayer

signal quit_to_menu_requested

@export var upgrade_manager: UpgradeManager

var options_menu_scene: PackedScene = preload("uid://b80ylttiln1rp")

var current_paused_peer: int = -1
var locked: bool = false

@onready var pause_information_label: Label = %PauseInformationLabel
@onready var unpause_button: Button = %UnpauseButton
@onready var options_button: Button = %OptionsButton
@onready var quit_to_menu_button: Button = %QuitToMenuButton


func _ready() -> void:
	unpause_button.pressed.connect(_on_unpause_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	quit_to_menu_button.pressed.connect(_on_quit_to_menu_pressed)
	
	UIAudioManager.register_buttons([
		unpause_button,
		options_button,
		quit_to_menu_button,
	])
	
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		upgrade_manager.upgrade_selection_started.connect(_on_upgrade_selection_started)
		upgrade_manager.upgrade_selection_completed.connect(_on_upgrade_selection_completed)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused and not locked:
			request_unpause.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		else:
			request_pause.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)
		get_viewport().set_input_as_handled()


@rpc("any_peer", "call_local", "reliable")
func request_pause(lock: bool = false) -> void:
	if current_paused_peer > -1:
		return
	locked = lock
	pause.rpc(multiplayer.get_remote_sender_id(), locked)


@rpc("any_peer", "call_local", "reliable")
func request_unpause() -> void:
	if current_paused_peer != multiplayer.get_remote_sender_id():
		return
	unpause.rpc()


@rpc("authority", "call_local", "reliable")
func pause(paused_peer: int, hidden: bool = false) -> void:
	get_tree().paused = true
	current_paused_peer = paused_peer
	if hidden: return
	
	visible = true
	var is_controlling_player := multiplayer.get_unique_id() == current_paused_peer
	
	unpause_button.disabled = not is_controlling_player
	options_button.disabled = not is_controlling_player
	
	if is_controlling_player:
		pause_information_label.text = ""
	else:
		# TODO: Get player's display name.
		pause_information_label.text = "Paused by another player."


@rpc("authority", "call_local", "reliable")
func unpause() -> void:
	get_tree().paused = false
	visible = false
	current_paused_peer = -1
	locked = false


func _on_unpause_button_pressed() -> void:
	request_unpause.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _on_options_button_pressed() -> void:
	var options_menu := options_menu_scene.instantiate()
	add_child(options_menu)


func _on_quit_to_menu_pressed() -> void:
	quit_to_menu_requested.emit()


func _on_upgrade_selection_started() -> void:
	request_pause.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, true)


func _on_upgrade_selection_completed() -> void:
	request_unpause.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER)


func _on_peer_disconnected(peer_id: int) -> void:
	if current_paused_peer == peer_id:
		unpause.rpc()
		# TODO: Investigate keeping game paused and allowing anyone else to unpause
		# also sending a notification to the other players that someone disconnected
