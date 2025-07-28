extends Node

signal enemy_died
signal player_stats_changed(player_id: int, player_data: PlayerData)
signal player_equipment_changed(player_id: int, new_equipment)


func emit_enemy_died() -> void:
	enemy_died.emit()


func emit_player_stats_changed(player_id: int, player_data: PlayerData) -> void:
	player_stats_changed.emit(player_id, player_data)


func emit_player_equipment_changed(player_id: int, new_equipment) -> void:
	player_equipment_changed.emit(player_id, new_equipment)
