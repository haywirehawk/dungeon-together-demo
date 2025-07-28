class_name UpgradeManager
extends Node

signal upgrade_selection_started
signal upgrade_selection_completed

static var instance: UpgradeManager

@export var enemy_manager: EnemyManager
@export var spawn_position: Node2D
@export var spawn_root: Node
@export var upgrade_packs: Array[UpgradePack]

var upgrade_option_scene: PackedScene = preload("uid://dma5rffw75fnx")
var upgrade_screen_scene: PackedScene = preload("uid://cwgan6liwytel")
var upgrade_card_scene: PackedScene = preload("uid://coukvj4ntgaui")
var peer_id_to_upgrade_options: Dictionary[int, Array] = {}
var peer_id_to_upgrades_acquired: Dictionary[int, Dictionary] = {}
var outstanding_peers_to_upgrade: Array[int] = []
var upgrade_pool: WeightedTable = WeightedTable.new()
var available_upgrades: Array[UpgradeResource] = []
var upgrade_screen: UpgradeScreen


## Returns a count of the given upgrade owned by the given peer.
static func get_peer_upgrade_count(peer_id: int, upgrade_id: String) -> int:
	if not is_instance_valid(instance):
		return 0
	
	if not instance.peer_id_to_upgrades_acquired.has(peer_id):
		return 0
	
	if not instance.peer_id_to_upgrades_acquired[peer_id].has(upgrade_id):
		return 0
	
	return instance.peer_id_to_upgrades_acquired[peer_id][upgrade_id]


## Returns a true/false on if the given peer owns any of the given upgrade.
static func peer_has_upgrade(peer_id: int, upgrade_id: String) -> bool:
	return get_peer_upgrade_count(peer_id, upgrade_id) > 0


func _ready() -> void:
	instance = self
	enemy_manager.round_completed.connect(_on_round_completed)
	set_upgrade_pool()
	
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconeected)


# TODO: Expand setup to include other packs, keeping them in sync
func set_upgrade_pool() -> void:
	upgrade_pool.clear()
	for pack in upgrade_packs:
		for item in pack.included_upgrades:
			upgrade_pool.add_item(item, item.weight)


func pick_upgrades() -> Array[UpgradeResource]:
	var chosen_upgrades: Array[UpgradeResource] = []
	for i in 3:
		if upgrade_pool.items.size() == chosen_upgrades.size():
			break
		var chosen_upgrade = upgrade_pool.pick_item(chosen_upgrades)
		chosen_upgrades.append(chosen_upgrade)
	
	return chosen_upgrades


func generate_upgrade_options() -> void:
	peer_id_to_upgrade_options.clear()
	
	var connected_peer_ids := multiplayer.get_peers()
	connected_peer_ids.append(MultiplayerPeer.TARGET_PEER_SERVER)
	for connected_peer_id in connected_peer_ids:
		outstanding_peers_to_upgrade.append(connected_peer_id)
		
		var chosen_upgrades := pick_upgrades()
		
		peer_id_to_upgrade_options[connected_peer_id] = chosen_upgrades
		var upgrade_options := create_upgrade_options(chosen_upgrades)
		var selected_upgrades: Array = []
		for i in upgrade_options.size():
			var upgrade_option := upgrade_options[i]
			var upgrade_resource := chosen_upgrades[i] as UpgradeResource
			var uid := ResourceUID.create_id()
			upgrade_option.name = str(uid)
			upgrade_option.set_peer_id_filter(connected_peer_id)
			
			selected_upgrades.append({
				"name": upgrade_option.name,
				"id": upgrade_resource.id,
			})
			
			upgrade_option.visible = connected_peer_id == MultiplayerPeer.TARGET_PEER_SERVER
		
		if not connected_peer_id == MultiplayerPeer.TARGET_PEER_SERVER:
			set_upgrade_options.rpc_id(connected_peer_id, selected_upgrades)


func create_upgrade_options(upgrade_resources: Array[UpgradeResource]) -> Array[UpgradeCard]:
	var result: Array[UpgradeCard] =[]
	
	if upgrade_screen == null:
		upgrade_screen = upgrade_screen_scene.instantiate()
		add_child(upgrade_screen)
	
	for i in range(upgrade_resources.size()):
		var upgrade_card: UpgradeCard = upgrade_card_scene.instantiate()
		upgrade_card.set_upgrade_index(i)
		upgrade_card.set_upgrade_resource(upgrade_resources[i])
		
		upgrade_screen.card_container.add_child(upgrade_card)
		upgrade_card.play_in(i * 0.2)
		
		upgrade_card.selected.connect(_on_upgrade_selected)
		result.append(upgrade_card)
	
	return result


func update_upgrade_screen_text() -> void:
	var title: String = "Upgrade Selected"
	var description: String
	var connected_peer_ids := multiplayer.get_peers()
	connected_peer_ids.append(MultiplayerPeer.TARGET_PEER_SERVER)
	var peers_remaining := outstanding_peers_to_upgrade.size()
	var plural := "s" if peers_remaining > 1 else ""
	
	for peer in connected_peer_ids:
		if outstanding_peers_to_upgrade.has(peer):
			continue
		description = "Waiting on others. %d player%s remaining." % [peers_remaining, plural]
		set_upgrade_screen_text.rpc_id(peer, title, description)


@rpc("authority", "call_local", "reliable")
func set_upgrade_screen_text(title: String, description: String) -> void:
	upgrade_screen.title_label.text = title
	upgrade_screen.description_label.text = description


@rpc("authority", "call_local", "reliable")
func remove_upgrade_screen() -> void:
	upgrade_screen.queue_free()


@rpc("authority", "call_local", "reliable")
func set_upgrade_options(selected_upgrades: Array) -> void:
	var upgrade_resources: Array[UpgradeResource] = []
	for upgrade in selected_upgrades:
		var resource_index := upgrade_pool.items.find_custom( func(item):
			return item.item.id == upgrade.id
		)
		upgrade_resources.append(upgrade_pool.items[resource_index].item)
	
	var created_nodes := create_upgrade_options(upgrade_resources)
	for i in created_nodes.size():
		created_nodes[i].name = selected_upgrades[i].name


func handle_upgrade_selected(upgrade_index: int, for_peer_id: int) -> void:
	if not peer_id_to_upgrades_acquired.has(for_peer_id):
		peer_id_to_upgrades_acquired[for_peer_id] = {}
	
	var upgrade_dictionary := peer_id_to_upgrades_acquired[for_peer_id]
	var chosen_upgrade = peer_id_to_upgrade_options[for_peer_id][upgrade_index]
	var upgrade_count: int = 0
	if upgrade_dictionary.has(chosen_upgrade.id):
		upgrade_count = upgrade_dictionary[chosen_upgrade.id]
	
	upgrade_dictionary[chosen_upgrade.id] = upgrade_count + 1
	
	outstanding_peers_to_upgrade.erase(for_peer_id)
	
	check_upgrades_complete()


func check_upgrades_complete() -> void:
	if outstanding_peers_to_upgrade.size() > 0:
		return
	
	remove_upgrade_screen.rpc()
	upgrade_selection_completed.emit()


func _on_round_completed() -> void:
	await get_tree().create_timer(2.0).timeout
	generate_upgrade_options()
	upgrade_selection_started.emit()


func _on_upgrade_selected(upgrade_index: int, for_peer_id: int) -> void:
	if for_peer_id > -1:
		handle_upgrade_selected(upgrade_index, for_peer_id)
	update_upgrade_screen_text()


func _on_peer_disconeected(peer_id: int) -> void:
	if outstanding_peers_to_upgrade.has(peer_id):
		outstanding_peers_to_upgrade.erase(peer_id)
	
