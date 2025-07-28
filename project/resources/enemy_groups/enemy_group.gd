class_name EnemyGroup
extends Resource

## The name used to reference this resource in code.
@export var id: String
## Set 0 for infinite
@export var enemies: Dictionary[PackedScene, int]
