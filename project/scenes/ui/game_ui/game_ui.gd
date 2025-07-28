class_name GameUI
extends CanvasLayer

@export var enemy_manager: EnemyManager
@export var lobby_manager: LobbyManager
@export var upgrade_manager: UpgradeManager

var player_slot_ids: Array[int] = []
var round_complete: bool

# Round Info
@onready var round_info_container: VBoxContainer = %RoundInfoContainer
@onready var round_label: Label = %RoundLabel
@onready var timer_label: Label = %TimerLabel
# Player Info
@onready var local_player_container: PlayerInfoContainer = %LocalPlayerContainer
@onready var remote_player_container_1: PlayerInfoContainer = %RemotePlayerContainer1
@onready var remote_player_container_2: PlayerInfoContainer = %RemotePlayerContainer2
@onready var remote_player_container_3: PlayerInfoContainer = %RemotePlayerContainer3
@onready var player_slot_containers: Array[PlayerInfoContainer] = [
	local_player_container,
	remote_player_container_1,
	remote_player_container_2,
	remote_player_container_3,
]
# Lobby Info
@onready var ready_up_container: VBoxContainer = %ReadyUpContainer
@onready var ready_count_label: Label = %ReadyCountLabel
@onready var ready_label: Label = %ReadyLabel
@onready var not_ready_label: Label = %NotReadyLabel
# Upgrade Select Info
@onready var upgrade_info_container: VBoxContainer = %UpgradeInfoContainer
@onready var upgrade_label: Label = %UpgradeLabel
@onready var upgrade_count_label: Label = %UpgradeCountLabel


func _ready() -> void:
	enemy_manager.round_changed.connect(_on_round_changed)
	enemy_manager.round_completed.connect(_on_round_completed)
	lobby_manager.self_peer_ready.connect(_on_self_peer_ready)
	lobby_manager.lobby_closed.connect(_on_lobby_closed)
	lobby_manager.peer_ready_states_changed.connect(_on_peer_ready_states_changed)
	
	var is_single_player := multiplayer.multiplayer_peer is OfflineMultiplayerPeer
	round_info_container.visible = is_single_player
	ready_up_container.visible = not is_single_player
	ready_label.hide()
	not_ready_label.show()
	upgrade_info_container.hide()
	remote_player_container_1.hide()
	remote_player_container_2.hide()
	remote_player_container_3.hide()


func _process(delta: float) -> void:
	set_round_info()


func set_round_info() -> void:
	var time_remaining := enemy_manager.get_round_time_remaining()
	
	if time_remaining == 0:
		if round_complete:
			timer_label.text = "Success!"
		else:
			timer_label.text = "Kill Remaining Enemies"
		return
	round_complete = false
	timer_label.text = str(ceili(time_remaining))


func connect_player(player: Player) -> void:
	(func():
		set_player_slot_ids()
		var peer_id := player.input_multiplayer_authority
		if multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
			local_player_container.display_name.text = "Player"
			local_player_container.player_sprite.material.set_shader_parameter("modulate_color", player.chosen_color)
			local_player_container.player_sprite.sprite_frames = PlayerCharacterOptions.get_character_set_sprite_frames(player.chosen_character_set)
		else:
			var container := get_player_info_container(peer_id)
			container.display_name.text = player.display_name
			container.player_sprite.material.set_shader_parameter("modulate_color", player.chosen_color)
			container.player_sprite.sprite_frames = PlayerCharacterOptions.get_character_set_sprite_frames(player.chosen_character_set)
			container.show()
		player.health_component.health_changed.connect(_on_health_changed.bind(peer_id))
		update_health(peer_id, player.health_component.current_health, player.health_component.max_health)
	).call_deferred()


# TODO: Handle player disconnects. This is untested, need a way to make sure the player icon/name/signals are correctly applied.
func reset_remote_players() -> void:
	set_player_slot_ids()
	remote_player_container_1.hide()
	remote_player_container_2.hide()
	remote_player_container_3.hide()
	
	for id in player_slot_ids:
		if id == multiplayer.get_unique_id():
			continue
		get_player_info_container(id).show()


func update_health(peer_id: int, current_health: int, max_health: int) -> void:
	var container := get_player_info_container(peer_id)
	container.health_bar.value = float(current_health) / max_health if max_health != 0 else 0.0


func update_status(peer_id: int, alive: bool = true) -> void:
	var container := get_player_info_container(peer_id)
	if alive:
		container.player_sprite.play("default")
	else:
		container.player_sprite.play("dead")


func set_player_slot_ids() -> void:
	var new_slot_assignments: Array[int] = []
	new_slot_assignments.push_back(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		new_slot_assignments.push_back(peer_id)
	player_slot_ids = new_slot_assignments


func get_player_info_container(peer_id) -> PlayerInfoContainer:
	var container: PlayerInfoContainer = player_slot_containers[get_player_slot(peer_id)]
	return container


func get_player_slot(peer_id) -> int:
	return player_slot_ids.find(peer_id)


@rpc("authority", "call_local", "unreliable")
func round_completed() -> void:
	round_complete = true


func _on_round_changed(round_number: int) -> void:
	round_label.text = "Round %s" % round_number
	round_complete = false


func _on_round_completed() -> void:
	round_completed.rpc()


func _on_health_changed(current_health: int, max_health: int, peer_id: int) -> void:
	update_health(peer_id, current_health, max_health)
	update_status(peer_id, current_health > 0)


func _on_self_peer_ready() -> void:
	ready_label.visible = true
	not_ready_label.visible = false


func _on_lobby_closed() -> void:
	ready_up_container.visible = false
	round_info_container.visible = true


func _on_peer_ready_states_changed(ready_count: int, total_count: int) -> void:
	ready_count_label.text = "%d/%d READY" % [ready_count, total_count]
