class_name Player
extends CharacterBody2D

signal player_died

enum PlayerState {
	LOCKED,
	NORMAL,
	DODGE,
	MELEE,
	RANGED,
	CAST,
}

const BASE_MOVEMENT_SPEED := 120.0
const BASE_ATTACK_RATE := 0.5
const BASE_DAMAGE := 1
const MOVEMENT_DAMPING := 10.0

# Defaults
var chosen_color: Color = Color.INDIGO
var chosen_character_set: String = "A"

var projectile_scene: PackedScene = preload("uid://c0bpjakelw3q7")
var melee_scene: PackedScene = preload("uid://dnf64l10txloj")
var muzzle_flash_scene: PackedScene = preload("uid://dvo7wliaghaix")
var ground_particles_scene: PackedScene = preload("uid://45ma4nldeycb")

var input_multiplayer_authority: int
var is_dying: bool = false
var is_respawning: bool = false
var display_name: String
var use_direction_arrow: bool = true
var current_state: PlayerState = PlayerState.MELEE

# Combat tracking
var combo_is_active: bool = false
var current_combo: int = 0
var max_combo: int = 1
var kickback_amount: float = 40.0

# Components
@onready var player_input_synchronizer_component: PlayerInputSynchronizerComponent = $PlayerInputSynchronizerComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
# UI
@onready var display_name_label: Label = %DisplayNameLabel
@onready var direction_arrow: Sprite2D = %DirectionArrow
@onready var attack_cooldown_progress_bar: ProgressBar = %AttackCooldownProgressBar
# Visuals
@onready var visuals: Node2D = %Visuals
@onready var animation_player: AnimationPlayer = $AnimationPlayer
#@onready var weapon_animation_player: AnimationPlayer = %WeaponAnimationPlayer # TODO
@onready var player_sprite: AnimatedSprite2D = %PlayerSprite
@onready var weapon_root: Node2D = %WeaponRoot
@onready var melee_origin: Marker2D = %MeleeOrigin
@onready var projectile_origin: Marker2D = %ProjectileOrigin
# Timers
@onready var attack_rate_timer: Timer = %AttackRateTimer
@onready var combo_rate_timer: Timer = %ComboRateTimer
@onready var combo_delay_timer: Timer = %ComboDelayTimer
# Areas
@onready var activation_area_collision_shape: CollisionShape2D = %ActivationAreaCollisionShape
#@onready var pickup_area_collision_shape: CollisionShape2D = %PickupAreaCollisionShape
# Audio
@onready var weapon_stream_player: AudioStreamPlayer2D = %WeaponStreamPlayer
@onready var audio_listener: AudioListener2D = %AudioListener2D
@onready var hit_stream_player_2d: AudioStreamPlayer2D = %HitStreamPlayer


func _ready() -> void:
	player_input_synchronizer_component.set_multiplayer_authority(input_multiplayer_authority)
	activation_area_collision_shape.disabled =\
		not player_input_synchronizer_component.is_multiplayer_authority()
	
	if multiplayer.multiplayer_peer is OfflineMultiplayerPeer\
		or player_input_synchronizer_component.is_multiplayer_authority():
		display_name_label.visible = false
	else:
		display_name_label.text = display_name
	
	player_sprite.self_modulate = chosen_color
	player_sprite.material.set_shader_parameter("modulate_color", chosen_color)
	player_sprite.sprite_frames = PlayerCharacterOptions.get_character_set_sprite_frames(chosen_character_set)
	
	if name == str(multiplayer.get_unique_id()):
		audio_listener.make_current()
	
	if is_multiplayer_authority():
		if is_respawning:
			health_component.current_health = 1
		health_component.health_hit_zero.connect(_on_health_hit_zero)
		hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)
		#GameEvents.player_stats_changed.connect(_on_player_stats_changed)


func _process(delta: float) -> void:
	update_aim_position()
	update_cooldown_ui()
	
	var movement_vector := player_input_synchronizer_component.movement_vector
	if is_multiplayer_authority():
		if is_dying:
			global_position = Vector2.LEFT * 1000
			return
		
		var target_velocity := movement_vector * get_movement_speed()
		velocity = velocity.lerp(target_velocity, 1 - exp(-MOVEMENT_DAMPING * delta))
		move_and_slide()
		
		if player_input_synchronizer_component.is_attack_pressed\
			or combo_is_active:
			try_attack()
		
		play_movement_animation.rpc()


func get_movement_speed() -> float:
	var movement_upgrade_count := UpgradeManager.get_peer_upgrade_count(
		player_input_synchronizer_component.get_multiplayer_authority(),
		"movement_speed"
	)
	var modifier := 1 + (0.15 * movement_upgrade_count)
	
	return BASE_MOVEMENT_SPEED * modifier


func get_attack_rate() -> float:
	var attack_rate_count := UpgradeManager.get_peer_upgrade_count(
		player_input_synchronizer_component.get_multiplayer_authority(),
		"attack_rate"
	)
	var modifier := maxf((1 - (0.1 * attack_rate_count)), 0.25)
	
	return BASE_ATTACK_RATE * modifier


func get_attack_damage() -> int:
	var damage_count := UpgradeManager.get_peer_upgrade_count(
		player_input_synchronizer_component.get_multiplayer_authority(),
		"damage"
	)
	
	return BASE_DAMAGE + damage_count


func set_sprite_options(color: Color = Color.WHITE, character_set: String = "A") -> void:
	chosen_color = color
	chosen_character_set = character_set


func set_display_name(incoming_name: String) -> void:
	display_name = incoming_name


func update_aim_position() -> void:
	var aim_vector := player_input_synchronizer_component.aim_vector
	
	visuals.scale = Vector2.ONE if aim_vector.x >= 0 else Vector2(-1, 1)
	if is_zero_approx(aim_vector.length_squared()):
		direction_arrow.hide()
	else:
		direction_arrow.visible = use_direction_arrow
		weapon_root.look_at(weapon_root.global_position + aim_vector)
		direction_arrow.look_at(global_position + aim_vector)


func update_cooldown_ui() -> void:
	if not attack_rate_timer.is_stopped():
		var total := attack_rate_timer.wait_time
		var current := total - attack_rate_timer.time_left
		attack_cooldown_progress_bar.value = current / total
	else:
		attack_cooldown_progress_bar.hide()


func has_finisher() -> bool:
	return true


func try_attack() -> void:
	if not attack_rate_timer.is_stopped() or not combo_rate_timer.is_stopped():
		return
	if is_combo_over():
		return
	
	continue_combo()


func continue_combo() -> void:
	combo_is_active = true
	if current_state == PlayerState.MELEE:
		spawn_melee_attack()
	elif current_state == PlayerState.RANGED:
		spawn_projectile_attack()
		
	combo_rate_timer.start()
	play_attack_effects.rpc()


func is_combo_over() -> bool:
	if current_combo >= max_combo:
		reset_attack_combo()
		return true
	else:
		current_combo += 1
		return false


func reset_attack_combo() -> void:
	current_combo = 0
	combo_is_active = false
	if is_multiplayer_authority():
		var new_wait_time := get_attack_rate()
		var peer_id := player_input_synchronizer_component.get_multiplayer_authority()
		show_attack_cooldown_bar.rpc_id(peer_id, new_wait_time)


func start_attack_rate_timer(new_wait_time: float) -> void:
	attack_rate_timer.wait_time = new_wait_time
	attack_rate_timer.start()
	attack_cooldown_progress_bar.show()


func spawn_melee_attack() -> void:
	var melee = melee_scene.instantiate() as BaseAttack
	melee.damage = get_attack_damage()
	melee.source_peer_id = player_input_synchronizer_component.get_multiplayer_authority()
	melee.global_position = melee_origin.global_position
	melee.rotation = direction_arrow.rotation
	get_parent().add_child(melee, true)
	velocity = Vector2.ZERO
	apply_kickback()


func spawn_projectile_attack() -> void:
	var projectile = projectile_scene.instantiate() as ProjectileAttack
	projectile.damage = get_attack_damage()
	projectile.source_peer_id = player_input_synchronizer_component.get_multiplayer_authority()
	projectile.global_position = projectile_origin.global_position
	projectile.start(player_input_synchronizer_component.aim_vector)
	get_parent().add_child(projectile, true)
	apply_kickback()


func apply_kickback() -> void:
	velocity -= player_input_synchronizer_component.aim_vector * kickback_amount


@rpc("authority", "call_local", "unreliable")
func show_attack_cooldown_bar(new_wait_time: float = 1.0) -> void:
	start_attack_rate_timer(new_wait_time)


@rpc("authority", "call_local", "unreliable")
func play_movement_animation() -> void:
	var movement_vector := player_input_synchronizer_component.movement_vector
	if is_equal_approx(movement_vector.length_squared(), 0):
		animation_player.play("RESET")
		player_sprite.play("default")
	else:
		animation_player.play("run")
		player_sprite.play("move")


@rpc("authority", "call_local", "unreliable")
func play_hit_effects() -> void:
	if player_input_synchronizer_component.is_multiplayer_authority():
		GameCamera.shake(1)
		hit_stream_player_2d.play()
	
	var hit_particles: Node2D = ground_particles_scene.instantiate()
	hit_particles.color = chosen_color
	
	var background_node: Node = Main.background_effects
	if not is_instance_valid(background_node):
		background_node = get_parent()
	background_node.add_child(hit_particles)
	hit_particles.global_position = global_position
	
	hurtbox_component.disable_collisions = true
	var tween := create_tween()
	tween.set_loops(10) # 10 x (.05 + .05) = 1 second total
	tween.tween_property(visuals, "visible", false, 0.05)
	tween.tween_property(visuals, "visible", true, 0.05)
	tween.finished.connect(func():
		hurtbox_component.disable_collisions = false
	)


@rpc("authority", "call_local", "unreliable")
func play_attack_effects():
	#if weapon_animation_player.is_playing():
		#weapon_animation_player.stop()
	#weapon_animation_player.play("attack")
	
	#var muzzle_flash: Node2D = muzzle_flash_scene.instantiate()
	#muzzle_flash.global_position = projectile_origin.global_position
	#muzzle_flash.rotation = projectile_origin.global_rotation
	#get_parent().add_child(muzzle_flash)
	
	if player_input_synchronizer_component.is_multiplayer_authority():
		if is_instance_valid(GameCamera.instance):
			GameCamera.shake(1)
	
	weapon_stream_player.play()


func kill() -> void:
	if not is_multiplayer_authority():
		push_error("Cannot call kill on non-server client.")
		return
	
	_kill.rpc()
	player_died.emit()
	
	await get_tree().create_timer(0.5).timeout
	call_deferred("queue_free")


@rpc("authority", "call_local", "reliable")
func _kill() -> void:
	is_dying = true
	player_input_synchronizer_component.public_visibility = false


func _on_health_hit_zero() -> void:
	kill()


func _on_hit_by_hitbox() -> void:
	play_hit_effects.rpc()


func _on_player_stats_changed() -> void:
	pass
