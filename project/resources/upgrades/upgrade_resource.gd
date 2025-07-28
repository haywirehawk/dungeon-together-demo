class_name UpgradeResource
extends Resource

## The name used to reference this resource in code.
@export var id: String
## Set 0 for infinite
@export var max_quantiy: int
## Smaller numbers are rarer, larger numbers are more common. TODO: Suggested numbers
@export var weight: int
## The name that will appear in game.
@export var display_name: String
## The in game description
@export_multiline var description: String


func apply_upgrade(player: Player) -> void:
	push_error("Missing Apply Upgrade in %s" % id)


func remove_upgrade(player: Player) -> void:
	push_error("Missing Remove Upgrade in %s" % id)
