class_name EnemyManager
extends Node

# Should only be called on server
signal round_changed(round_number: int)
signal round_completed
signal game_completed

const ROUND_BASE_TIME: int = 10
const ROUND_GROWTH: int = 5
const BASE_ENEMY_SPAWN_TIME: float = 2
const ENEMY_SPAWN_TIME_GROWTH: float = -.15
const MAX_ROUNDS: int = 10

@export var upgrade_manager: UpgradeManager
@export var enemy_scene: PackedScene
@export var starting_enemy_group: EnemyGroup
@export var enemy_spawn_root: Node
@export var spawn_rect: ReferenceRect

var enemy_spawn_pool: WeightedTable = WeightedTable.new()
var tier_1_enemy_group: EnemyGroup = preload("uid://da5qi4qeny8j0")
var tier_2_enemy_group: EnemyGroup = preload("uid://bc26u622gnlqq")
var tier_3_enemy_group: EnemyGroup = preload("uid://hb0mgcn0l6o3")


@onready var spawn_interval_timer: Timer = $SpawnIntervalTimer
@onready var round_timer: Timer = $RoundTimer

var _round_count: int
var round_count: int:
	get:
		return _round_count
	set(value):
		_round_count = value
		round_changed.emit(_round_count)
var spawned_enemies: int


func _ready() -> void:
	add_enemies_to_pool(starting_enemy_group)
	
	spawn_interval_timer.timeout.connect(_on_spawn_interval_timer_timeout)
	round_timer.timeout.connect(_on_round_timer_timeout)
	GameEvents.enemy_died.connect(_on_enemy_died)
	upgrade_manager.upgrade_selection_completed.connect(_on_upgrade_selection_completed)


func start() -> void:
	if is_multiplayer_authority():
		begin_round()


## Called by server to sync round data to clients
func synchronize(to_peer_id: int = -1) -> void:
	if not is_multiplayer_authority():
		return
	
	var data = {
		"round_timer_is_running": !round_timer.is_stopped(),
		"round_timer_time_left": round_timer.time_left,
		"round_count": round_count
	}
	
	if to_peer_id > -1 and to_peer_id != 1:
		_synchronize.rpc_id(to_peer_id, data)
	else:
		_synchronize.rpc(data)


@rpc("authority", "call_remote", "reliable")
func _synchronize(data: Dictionary) -> void:
	var wait_time: float = data["round_timer_time_left"]
	if wait_time > 0:
		round_timer.wait_time = wait_time
	if data["round_timer_is_running"]:
		round_timer.start()
	round_count = data["round_count"]


func get_round_time_remaining() -> float:
	return round_timer.time_left


func get_random_spawn_position() -> Vector2:
	var x = randf_range(0, spawn_rect.size.x)
	var y = randf_range(0, spawn_rect.size.y)
	
	return spawn_rect.global_position + Vector2(x, y)


func set_spawn_pool(new_enemy_group: EnemyGroup) -> void:
	for enemy in new_enemy_group.enemies:
		enemy_spawn_pool.add_item(enemy, new_enemy_group.enemies[enemy])


func add_enemies_to_pool(new_enemy_group: EnemyGroup = null, new_enemy = null) -> void:
	if new_enemy_group:
		for enemy in new_enemy_group.enemies:
			enemy_spawn_pool.add_item(enemy, new_enemy_group.enemies[enemy])
	#if new_enemy:
		#enemy_spawn_pool.add_item(new_enemy, 10)


func reset_spawn_pool() -> void:
	enemy_spawn_pool.clear()


func check_spawn_pool_tier() -> void:
	@warning_ignore("integer_division")
	match round(round_count / 2):
		1: return
		2: set_spawn_pool(tier_1_enemy_group)
		3: set_spawn_pool(tier_2_enemy_group)
		4: set_spawn_pool(tier_3_enemy_group)
		5: set_spawn_pool(tier_3_enemy_group)


func spawn_enemy() -> void:
	var selected_enemy = enemy_spawn_pool.pick_item()
	var enemy = selected_enemy.instantiate() as Node2D
	enemy.global_position = get_random_spawn_position()
	enemy_spawn_root.add_child(enemy, true)
	spawned_enemies += 1


func begin_round() -> void:
	round_count += 1
	round_timer.wait_time = ROUND_BASE_TIME + ((round_count - 1) * ROUND_GROWTH)
	round_timer.start()
	
	check_spawn_pool_tier()
	
	spawn_interval_timer.wait_time = BASE_ENEMY_SPAWN_TIME + ((round_count - 1) * ENEMY_SPAWN_TIME_GROWTH)
	spawn_interval_timer.start()
	synchronize()


func check_round_completion():
	if not round_timer.is_stopped():
		return
	
	if spawned_enemies == 0:
		if round_count == MAX_ROUNDS:
			complete_game()
		else:
			round_completed.emit()


func complete_game() -> void:
	await get_tree().create_timer(2).timeout
	game_completed.emit()
	


func _on_spawn_interval_timer_timeout() -> void:
	if is_multiplayer_authority():
		spawn_enemy()
		spawn_interval_timer.start()


func _on_round_timer_timeout() -> void:
	if not is_multiplayer_authority():
		return
	spawn_interval_timer.stop()
	check_round_completion()


func _on_enemy_died() -> void:
	spawned_enemies -= 1
	check_round_completion()


func _on_upgrade_selection_completed() -> void:
	begin_round()
