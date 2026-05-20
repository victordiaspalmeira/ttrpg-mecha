class_name StatusEffect
extends Resource

const DEFAULT_ICON: Texture2D = preload("res://assets/icons/spells/teleportation_spell.png")

@export var effect_id := ""
@export var display_name := ""
@export var description := ""
@export var icon: Texture2D

## Duration in turns. -1 means permanent (until removed by other means).
@export var duration := 1

## Stat modifiers applied while this effect is active.
## Supported keys: "attack_power", "defense", "movement", "max_ap"
@export var modifiers: Dictionary = {}

## How multiple instances of the same effect_id stack.
enum StackMode { NONE, ADDITIVE }
@export var stack_mode := StackMode.NONE


## Returns the icon if set, otherwise the default fallback icon.
func get_icon() -> Texture2D:
	return icon if icon else DEFAULT_ICON


func get_modifier(stat: String) -> int:
	return modifiers.get(stat, 0)