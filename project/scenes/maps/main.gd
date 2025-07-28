class_name Main
extends Node

const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu/main_menu.tscn"
const ENEMY_UIDS := {
	"bat": "uid://bf5ooyi0qb45o",
	"archer": "uid://d055b30juorq6",
	"rat": "uid://wm6kek8gew4r",
}

static var background_effects: Node2D

var player_scene: PackedScene = preload("uid://kdgtvcxs8ox4")

@onready var game_camera: GameCamera = $GameCamera
@onready var multiplayer_spawner: MultiplayerSpawner = $MultiplayerSpawner
@onready var center_position: Marker2D = $CenterPosition
@onready var game_ui: GameUI = $GameUI
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var enemy_manager: EnemyManager = $EnemyManager
@onready var lobby_manager: LobbyManager = $LobbyManager
@onready var _background_effects: Node2D = $BackgroundEffects

var player_list: Dictionary[int, Player] = {}
var dead_peers: Array[int] = []
## Key is player's Peer ID, data is display_name, color, character_set
var player_data_dictionary: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	background_effects = _background_effects
	set_auto_spawn_list()
	
	multiplayer_spawner.spawn_function = func(data):
		var player = player_scene.instantiate() as Player
		player.set_display_name(data.display_name)
		player.set_sprite_options(data.color, data.character_set)
		player.name = str(data.peer_id)
		player.input_multiplayer_authority = data.peer_id
		player.global_position = center_position.global_position
		if data.peer_id == multiplayer.get_unique_id():
			game_camera.set_target(player)
		#if multiplayer.get_unique_id() == data.peer_id:
		game_ui.connect_player(player)
		
		if is_multiplayer_authority():
			if data.is_respawning:
				player.is_respawning = true
			player.player_died.connect(_on_player_died.bind(data.peer_id))
		
		player_list[data.peer_id] = player
		return player
	
	peer_ready.rpc_id(1, MultiplayerConfig.display_name, MultiplayerConfig.color, MultiplayerConfig.character_set)
	
	pause_menu.quit_to_menu_requested.connect(_on_quit_to_menu_requested)
	lobby_manager.all_peers_readied.connect(_on_all_peers_readied)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if is_multiplayer_authority():
		enemy_manager.round_completed.connect(_on_round_completed)
		enemy_manager.game_completed.connect(_on_game_completed)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func set_auto_spawn_list() -> void:
	for enemy in ENEMY_UIDS:
		multiplayer_spawner.add_spawnable_scene(ENEMY_UIDS[enemy])


@rpc("any_peer", "call_local", "reliable")
func peer_ready(display_name: String, color: Color, character_set: String) -> void:
	var sender_id = multiplayer.get_remote_sender_id()
	player_data_dictionary[sender_id] = {
		"display_name": display_name,
		"color": color,
		"character_set": character_set
	}
	multiplayer_spawner.spawn({
		"peer_id": sender_id,
		"display_name": display_name,
		"color": color,
		"character_set": character_set,
		"is_respawning": false,
	})
	
	enemy_manager.synchronize(sender_id)


func respawn_dead_peers() -> void:
	var all_peers := get_all_peers()
	for peer_id in dead_peers:
		# If a dead player has disconnected, ignores them on respawn
		if not all_peers.has(peer_id):
			continue
		multiplayer_spawner.spawn({
			"peer_id": peer_id,
			"display_name": player_data_dictionary[peer_id].display_name,
			"color": player_data_dictionary[peer_id]["color"],
			"character_set": player_data_dictionary[peer_id]["character_set"],
			"is_respawning": true
		})
	dead_peers.clear()


func check_game_over() -> void:
	var is_game_over := true
	# If a peer_id is not in the dead list, that means one is alive still.
	for peer_id in get_all_peers():
		if not dead_peers.has(peer_id):
			is_game_over = false
			break
	
	if is_game_over:
		await get_tree().create_timer(2.0).timeout
		end_game()


func end_game():
	get_tree().paused = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func get_all_peers() -> PackedInt32Array:
	var all_peers := multiplayer.get_peers()
	all_peers.push_back(multiplayer.get_unique_id())
	return all_peers


func _on_player_died(peer_id: int) -> void:
	dead_peers.append(peer_id)
	if peer_id == multiplayer.get_unique_id():
		game_camera.set_target(center_position)
		
	check_game_over()


func _on_round_completed() -> void:
	respawn_dead_peers()


func _on_game_completed() -> void:
	end_game()


func _on_quit_to_menu_requested() -> void:
	end_game()


func _on_all_peers_readied() -> void:
	lobby_manager.close_lobby()
	enemy_manager.start()


func _on_server_disconnected() -> void:
	end_game()


func _on_peer_disconnected(peer_id: int) -> void:
	if player_list.has(peer_id):
		var player := player_list[peer_id]
		if is_instance_valid(player):
			player_list[peer_id].kill()
		player_list.erase(peer_id)
	game_ui.reset_remote_players()
