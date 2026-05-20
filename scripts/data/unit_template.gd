class_name UnitTemplate
extends Resource

@export var template_id := ""
@export var display_name := ""
@export var portrait: Texture2D

@export var class_data: ClassData

## Primary weapon (overrides the class default if set)
@export var primary_weapon: WeaponData

## Secondary weapon (optional)
@export var secondary_weapon: WeaponData

## Team affiliation
@export var team_id := "player"


func get_display_name() -> String:
	if display_name:
		return display_name
	if class_data:
		return class_data.display_name
	return template_id