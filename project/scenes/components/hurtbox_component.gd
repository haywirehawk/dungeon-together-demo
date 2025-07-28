class_name HurtboxComponent
extends Area2D

signal hit_by_hitbox

@export var health_component: HealthComponent

var peer_id_filter: int = -1
var disable_collisions: bool


func _ready() -> void:
	area_entered.connect(_on_area_entered)
	
	if not health_component:
		push_error("Hurtbox on %s missing HealthComponent" % self.owner)


func _handle_hit(hitbox_component: HitboxComponent):
	if hitbox_component.is_hit_handled or disable_collisions:
		return
	
	hitbox_component.register_hurtbox_hit(self)
	health_component.damage(hitbox_component.damage)
	hit_by_hitbox.emit()


func _on_area_entered(other_area: Area2D) -> void:
	if not is_multiplayer_authority() or other_area is not HitboxComponent:
		return
	
	var hitbox_component: HitboxComponent = other_area
	if peer_id_filter > -1 and hitbox_component.source_peer_id != peer_id_filter:
		return
	
	_handle_hit.call_deferred(other_area)
