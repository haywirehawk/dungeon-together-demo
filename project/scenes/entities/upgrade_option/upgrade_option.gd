class_name UpgradeOption
extends Node2D

signal selected(index: int, for_peer_id: int)

@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_flash_sprite_component: HitFlashSpriteComponent = $HitFlashSpriteComponent
@onready var player_detection_area: Area2D = $PlayerDetectionArea
@onready var info_container: VBoxContainer = $InfoContainer
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var hit_stream_player_2d: AudioStreamPlayer2D = %HitStreamPlayer2D

var impact_particles_scene: PackedScene = preload("uid://cojepff8k2jav")
var ground_particles_scene: PackedScene = preload("uid://dboeatkgfm33h")

var upgrade_index: int
var assigned_resource: UpgradeResource
var peer_id_filter: int = -1


func _ready() -> void:
	set_peer_id_filter(peer_id_filter)
	update_info()
	
	info_container.visible = false
	
	hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)
	health_component.health_hit_zero.connect(_on_health_hit_zero)
	player_detection_area.area_entered.connect(_on_player_detection_area_entered)
	player_detection_area.area_exited.connect(_on_player_detection_area_exited)
	
	if is_multiplayer_authority():
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func set_peer_id_filter(new_peer_id: int) -> void:
	peer_id_filter = new_peer_id
	hurtbox_component.peer_id_filter = peer_id_filter
	hit_flash_sprite_component.peer_id_filter = peer_id_filter


func set_upgrade_index(index: int):
	upgrade_index = index


func set_upgrade_resource(upgrade_resource: UpgradeResource) -> void:
	assigned_resource = upgrade_resource
	update_info()


func update_info() -> void:
	if not is_instance_valid(title_label) or not is_instance_valid(description_label)\
		or assigned_resource == null:
		return
	
	title_label.text = assigned_resource.display_name
	description_label.text = assigned_resource.description


func play_in(delay: float = 0.0) -> void:
	hit_flash_sprite_component.scale = Vector2.ZERO
	
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		animation_player.play("spawn")
	)


func spawn_death_particles() -> void:
	# Prevent from playing on server's hidden nodes.
	# Check if server, then if filter is server's.
	if is_multiplayer_authority():
		if not peer_id_filter == multiplayer.get_unique_id():
			return
	
	var death_particles: Node2D = ground_particles_scene.instantiate()
	
	var background_node: Node = Main.background_effects
	if not is_instance_valid(background_node):
		background_node = get_parent()
	background_node.add_child(death_particles)
	death_particles.global_position = global_position


func despawn() -> void:
	animation_player.play("despawn")


func kill() -> void:
	spawn_death_particles()
	queue_free()


@rpc("authority", "call_local", "reliable")
func kill_all(killed_name: String) -> void:
	var upgrade_option_nodes := get_tree().get_nodes_in_group("UpgradeOption")
	
	for upgrade_option in upgrade_option_nodes:
		if upgrade_option.peer_id_filter == peer_id_filter:
			if upgrade_option.name == killed_name:
				upgrade_option.kill()
			else:
				upgrade_option.despawn()


@rpc("authority", "call_local")
func spawn_hit_effects() -> void:
	var hit_particles: Node2D = impact_particles_scene.instantiate()
	hit_particles.global_position = hurtbox_component.global_position
	get_parent().add_child(hit_particles)


func _on_health_hit_zero() -> void:
	selected.emit(upgrade_index, peer_id_filter)
	kill_all.rpc_id(MultiplayerPeer.TARGET_PEER_SERVER, name)
	
	if peer_id_filter != MultiplayerPeer.TARGET_PEER_SERVER:
		kill_all.rpc_id(peer_id_filter, name)


func _on_hit_by_hitbox() -> void:
	spawn_hit_effects.rpc_id(peer_id_filter)


func _on_player_detection_area_entered(_other_area: Area2D) -> void:
	info_container.visible = true


func _on_player_detection_area_exited(_other_area: Area2D) -> void:
	info_container.visible = false


func _on_peer_disconnected(peer_id: int) -> void:
	if peer_id == peer_id_filter:
		despawn()
