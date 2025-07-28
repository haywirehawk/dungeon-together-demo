class_name UpgradeCard
extends PanelContainer

signal selected(upgrade_index: int, for_peer_id: int)

var disabled = false

@onready var name_label: Label = %NameLabel
@onready var description_label: Label = %DescriptionLabel

var upgrade_index: int
var assigned_resource: UpgradeResource
var peer_id_filter: int = -1


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	focus_entered.connect(_on_focus_entered)
	
	update_info()


func play_in(delay: float = 0) -> void:
	modulate = Color.TRANSPARENT
	scale = Vector2.ZERO
	await get_tree().create_timer(delay).timeout
	$AnimationPlayer.play("in")


func play_hover() -> void:
	$HoverAnimationPlayer.play("hover")


func discard() -> void:
	$AnimationPlayer.play("discard")


func select_card() -> void:
	disabled = true
	$AnimationPlayer.play("selected")


func set_peer_id_filter(new_peer_id: int) -> void:
	peer_id_filter = new_peer_id


func set_upgrade_index(index: int):
	upgrade_index = index


func set_upgrade_resource(upgrade_resource: UpgradeResource) -> void:
	assigned_resource = upgrade_resource
	update_info()


func update_info() -> void:
	if not is_instance_valid(name_label) or not is_instance_valid(description_label)\
		or assigned_resource == null:
		return
	
	name_label.text = assigned_resource.display_name
	description_label.text = assigned_resource.description


## Emits signal on the server and removes options from the client.
@rpc("any_peer", "call_local", "reliable")
func request_selection(selected_name: String) -> void:
	if is_multiplayer_authority():
		selected.emit(upgrade_index, peer_id_filter)
		remove_cards.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, selected_name)
	
	if peer_id_filter != MultiplayerPeer.TARGET_PEER_SERVER:
		remove_cards.rpc_id(peer_id_filter, selected_name)


@rpc("authority", "call_local", "reliable")
func remove_cards(selected_name: String) -> void:
	var upgrade_card_nodes := get_tree().get_nodes_in_group("upgrade_card")
	
	for upgrade_card in upgrade_card_nodes:
		if upgrade_card.peer_id_filter == peer_id_filter:
			if upgrade_card.name == selected_name:
				upgrade_card.select_card()
			else:
				upgrade_card.discard()


func _on_gui_input(event: InputEvent) -> void:
	if disabled: return
	
	if event.is_action_pressed("accept"):
		request_selection.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, name)


func _on_mouse_entered() -> void:
	if disabled: return
	
	play_hover()


func _on_focus_entered() -> void:
	play_hover()


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == peer_id_filter:
		discard()
