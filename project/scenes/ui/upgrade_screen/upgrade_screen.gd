class_name UpgradeScreen
extends CanvasLayer

#signal upgrade_selected(upgrade: UpgradeResource)

#var upgrade_card_scene: PackedScene = preload("uid://coukvj4ntgaui")

@onready var card_container: HBoxContainer = %CardContainer
@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel

# None of this is currently used in this implementation. 
# TODO: Move card creation into this class as complexity changes?
#func set_ability_upgrades(upgrades: Array[UpgradeResource]) -> void:
	#var delay = 0
	#for upgrade in upgrades:
		#var card_instance = upgrade_card_scene.instantiate()
		#card_container.add_child(card_instance)
		#card_instance.set_ability_upgrade(upgrade)
		#card_instance.play_in(delay)
		#card_instance.selected.connect(_on_upgrade_selected.bind(upgrade))
		#delay += .2
#
#
#func _on_upgrade_selected(upgrade: UpgradeResource) -> void:
	#upgrade_selected.emit(upgrade)
	#$AnimationPlayer.play("out")
	#await $AnimationPlayer.animation_finished
	#get_tree().paused = false
	#queue_free()
