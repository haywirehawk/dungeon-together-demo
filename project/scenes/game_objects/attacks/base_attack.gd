class_name BaseAttack
extends Node2D

enum AttackCollisionLayer {
	ENEMY_ATTACK = 4,
	PLAYER_ATTACK = 256,
}

var source_peer_id: int
var damage: int = 1
var collision_layer: AttackCollisionLayer = AttackCollisionLayer.PLAYER_ATTACK

@onready var hitbox_component: HitboxComponent = $HitboxComponent


func _ready() -> void:
	hitbox_component.source_peer_id = source_peer_id
	hitbox_component.damage = damage
	hitbox_component.collision_layer = collision_layer
	
	hitbox_component.hurtbox_hit.connect(_on_hurtbox_hit)


## Override to alter what happens after the first collision
func register_collision() -> void:
	hitbox_component.is_hit_handled = true


func kill() -> void:
	if is_multiplayer_authority():
		queue_free()


func _on_hurtbox_hit(hurtbox_component: HurtboxComponent) -> void:
	register_collision()
