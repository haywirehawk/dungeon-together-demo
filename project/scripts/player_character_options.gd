class_name PlayerCharacterOptions
extends Node

static var PLAYER_PALETTE = preload("uid://dthjkjkh6yhb8")
static var _CHARACTER_A_SPRITE_FRAMES = preload("uid://dhv86p7cdg0ay")
static var _CHARACTER_B_SPRITE_FRAMES = preload("uid://x6p77n1qjwf8")
static var _CHARACTER_C_SPRITE_FRAMES = preload("uid://dt06n400xyk27")
static var _CHARACTER_D_SPRITE_FRAMES = preload("uid://ov5soqrsb5vc")

static var _character_set_frames: Dictionary = {
	"A": _CHARACTER_A_SPRITE_FRAMES,
	"B": _CHARACTER_B_SPRITE_FRAMES,
	"C": _CHARACTER_C_SPRITE_FRAMES,
	"D": _CHARACTER_D_SPRITE_FRAMES,
}

static func get_character_set_sprite_frames(character_set: String) -> SpriteFrames:
	if _character_set_frames.has(character_set):
		return _character_set_frames[character_set]
	else:
		return null
