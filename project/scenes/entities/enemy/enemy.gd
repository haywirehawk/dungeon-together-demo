class_name BaseEnemy
extends CharacterBody2D

enum attack_types{
	DASH = 0,
	PROJECTILE = 1,
}

@export var projectile_scene: PackedScene
@export var attack_particles_scene: PackedScene
@export var attack_type: attack_types

@export var movement_damping := 15.0
@export var stopping_damping := 3.0
@export var move_speed := 40.0
@export var dash_attack_speed := 400.0
@export var dash_cancel_velocity := 50.0
@export var near_target_distance := 24.0
@export var target_distance := 150.0

# Timers
@onready var target_acquisition_timer: Timer = $TargetAcquisitionTimer
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var ready_attack_timer: Timer = $ReadyAttackTimer
# Components
@onready var health_component: HealthComponent = $HealthComponent
@onready var hurtbox_component: HurtboxComponent = $HurtboxComponent
@onready var hitbox_collision_shape: CollisionShape2D = %HitboxCollisionShape
# Visuals
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var visuals: Node2D = %Visuals
@onready var alert_sprite: Sprite2D = $AlertSprite
# Audio
@onready var hit_stream_player: AudioStreamPlayer2D = %HitStreamPlayer2D
@onready var attack_stream_player: AudioStreamPlayer2D = %AttackStreamPlayer2D

var impact_particles_scene: PackedScene = preload("uid://cojepff8k2jav")
var ground_particles_scene: PackedScene = preload("uid://dboeatkgfm33h")

var target_position: Vector2
var state_machine: CallableStateMachine = CallableStateMachine.new()
var default_collision_mask: int
var default_collision_layer: int
var alert_tween: Tween

var current_state: String:
	get:
		return state_machine.current_state
	set(value):
		state_machine.change_state(Callable.create(self, value))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		state_machine.add_states(state_spawn, enter_state_spawn, Callable())
		state_machine.add_states(state_normal, enter_state_normal, exit_state_normal)
		state_machine.add_states(state_ready_attack, enter_state_ready_attack, exit_state_ready_attack)
		state_machine.add_states(state_dash_attack, enter_state_dash_attack, exit_state_dash_attack)
		state_machine.add_states(state_ranged_attack, enter_state_ranged_attack, exit_state_ranged_attack)
		state_machine.add_states(state_rest, enter_state_rest, Callable())


func _ready() -> void:
	default_collision_mask = collision_mask
	default_collision_layer = collision_layer
	hitbox_collision_shape.disabled = true
	alert_sprite.scale = Vector2.ZERO
	
	if is_multiplayer_authority():
		health_component.health_hit_zero.connect(_on_health_hit_zero)
		state_machine.set_initial_state(state_spawn)
		hurtbox_component.hit_by_hitbox.connect(_on_hit_by_hitbox)


func _process(delta: float) -> void:
	state_machine.update()
	if is_multiplayer_authority():
		move_and_slide()


func enter_state_spawn() -> void:
	var tween := create_tween()
	tween.tween_property(visuals, "scale", Vector2.ONE, 0.4).from(Vector2.ZERO)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
	tween.finished.connect( func():
		state_machine.change_state(state_normal)
	)


func state_spawn() -> void:
	pass


func enter_state_normal() -> void:
	animation_player.play("run")
	if is_multiplayer_authority():
		acquire_target()
		target_acquisition_timer.start()


func state_normal() -> void:
	if is_multiplayer_authority():
		set_movement_velocity(get_physics_process_delta_time())
		check_acquire_target()
		check_can_attack()
	
	flip()


func exit_state_normal() -> void:
	animation_player.stop()


func enter_state_ready_attack() -> void:
	if is_multiplayer_authority():
		acquire_target()
		ready_attack_timer.start()
	
	animation_player.play("ready_dash")
	if alert_tween and alert_tween.is_valid():
		alert_tween.kill()
	alert_tween = create_tween()
	alert_tween.tween_property(alert_sprite, "scale", Vector2.ONE, 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func state_ready_attack() -> void:
	if is_multiplayer_authority():
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-movement_damping * get_process_delta_time()))
		if ready_attack_timer.is_stopped():
			attack_stream_player.play(0.1)
			var attack_method: Callable
			if attack_type == attack_types.DASH:
				attack_method = Callable(self, "state_dash_attack")
			elif attack_type == attack_types.PROJECTILE:
				attack_method = Callable(self, "state_ranged_attack")
			state_machine.change_state(attack_method)
	
	flip()


func exit_state_ready_attack() -> void:
	animation_player.stop()
	
	if alert_tween and alert_tween.is_valid():
		alert_tween.kill()
	alert_tween = create_tween()
	alert_tween.tween_property(alert_sprite, "scale", Vector2.ZERO, 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	


func enter_state_dash_attack() -> void:
	animation_player.play("dash")
	if is_multiplayer_authority():
		collision_mask = 1 << 0
		collision_layer = 0
		hitbox_collision_shape.disabled = false
		velocity = global_position.direction_to(target_position) * dash_attack_speed


func state_dash_attack() -> void:
	if is_multiplayer_authority():
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-stopping_damping * get_process_delta_time()))
		if velocity.length_squared() < dash_cancel_velocity * dash_cancel_velocity:
			state_machine.change_state(state_rest)


func exit_state_dash_attack() -> void:
	animation_player.stop()
	if is_multiplayer_authority():
		collision_mask = default_collision_mask
		collision_layer = default_collision_layer
		hitbox_collision_shape.disabled = true
		attack_cooldown_timer.start()


func enter_state_ranged_attack() -> void:
	animation_player.play("special")
	if is_multiplayer_authority():
		var projectile := projectile_scene.instantiate()
		projectile.damage = 1
		projectile.global_position = global_position
		projectile.start(global_position.direction_to(target_position))
		projectile.collision_layer = BaseAttack.AttackCollisionLayer.ENEMY_ATTACK
		get_parent().add_child(projectile, true)


func state_ranged_attack() -> void:
	if is_multiplayer_authority():
		await get_tree().create_timer(0.5).timeout
		state_machine.change_state(state_rest)


func exit_state_ranged_attack() -> void:
	animation_player.stop()
	
	if is_multiplayer_authority():
		attack_cooldown_timer.start()


func enter_state_rest() -> void:
	animation_player.play("RESET")


func state_rest() -> void:
	await  get_tree().create_timer(0.5).timeout
	state_machine.change_state(state_normal)


func set_movement_velocity(delta: float) -> void:
		velocity = global_position.direction_to(target_position) * move_speed


func check_acquire_target() -> void:
		if target_acquisition_timer.is_stopped():
			acquire_target()
			target_acquisition_timer.start()


func acquire_target() -> void:
	var players = get_tree().get_nodes_in_group("player")
	var nearest_player: Player = null
	var nearest_squared_distance: float
	
	for player in players:
		# Assign a starting player and distance
		if nearest_player == null:
			nearest_player = player
			nearest_squared_distance = nearest_player.global_position.distance_squared_to(global_position)
			continue
		# Compare distance with previous player
		var player_squared_distance: float = player.global_position.distance_squared_to(global_position)
		if player_squared_distance < nearest_squared_distance:
			nearest_squared_distance = player_squared_distance
			nearest_player = player
	
	if nearest_player:
		target_position = nearest_player.global_position


func check_can_attack() -> void:
		var can_attack := attack_cooldown_timer.is_stopped()\
			or global_position.distance_squared_to(target_position) < near_target_distance * near_target_distance
		
		if can_attack and global_position.distance_squared_to(target_position) < target_distance * target_distance:
			state_machine.change_state(state_ready_attack)


func flip() -> void:
	visuals.scale = Vector2.ONE if target_position.x > global_position.x else Vector2(-1, 1)


@rpc("authority", "call_local", "unreliable")
func spawn_attack_effects() -> void:
	pass


@rpc("authority", "call_local", "unreliable")
func spawn_hit_effects() -> void:
	hit_stream_player.play()
	
	var hit_particles: Node2D = impact_particles_scene.instantiate()
	hit_particles.global_position = hurtbox_component.global_position
	get_parent().add_child(hit_particles)


@rpc("authority", "call_local", "unreliable")
func spawn_death_particles() -> void:
	var death_particles: Node2D = ground_particles_scene.instantiate()
	
	var background_node: Node = Main.background_effects
	if not is_instance_valid(background_node):
		background_node = get_parent()
	background_node.add_child(death_particles)
	death_particles.global_position = global_position


func _on_health_hit_zero() -> void:
	spawn_death_particles.rpc()
	GameEvents.emit_enemy_died()
	queue_free()


func _on_hit_by_hitbox() -> void:
	spawn_hit_effects.rpc()
