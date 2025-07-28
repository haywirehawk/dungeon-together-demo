class_name HitboxComponent
extends Area2D

signal hurtbox_hit(hurtbox_component: HurtboxComponent)

var damage: int = 1
var source_peer_id: int
var is_hit_handled: bool


func register_hurtbox_hit(hurtbox_component: HurtboxComponent):
	hurtbox_hit.emit(hurtbox_component)
