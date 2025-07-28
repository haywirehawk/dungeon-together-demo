class_name FloatingEnemy
extends BaseEnemy


func set_movement_velocity(delta: float) -> void:
	var desired_velocity = global_position.direction_to(target_position) * move_speed
	velocity = velocity.lerp(desired_velocity, 1 - exp(-movement_damping * delta))
