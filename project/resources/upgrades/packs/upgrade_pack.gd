class_name UpgradePack
extends Resource

## The name used to reference this resource in code.
@export var id: String
## Set 0 for infinite
@export var included_upgrades: Array[UpgradeResource]
## The name that will appear in game.
@export var display_name: String
## The in game description
@export_multiline var description: String
