extends Node

var state_machine: CallableStateMachine = CallableStateMachine.new()
var current_state: String:
	get:
		return state_machine.current_state
	set(value):
		state_machine.change_state(Callable.create(self, value))


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		state_machine.add_states(Callable(), Callable(), Callable())


func enter_spawn_state() -> void:
	pass


func spawn_state() -> void:
	pass


func enter_idle_state() -> void:
	pass


func idle_state() -> void:
	pass


func exit_idle_state() -> void:
	pass


func enter_cast_state() -> void:
	pass


func cast_state() -> void:
	pass


func exit_cast_state() -> void:
	pass
