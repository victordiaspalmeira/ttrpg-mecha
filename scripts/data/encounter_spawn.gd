class_name EncounterSpawn
extends Resource

## Optional UnitTemplate. Overrides class_data, weapon, and team.
@export var template: UnitTemplate

@export var class_data: ClassData
@export var team_id := "player"
@export var q := 0
@export var r := 0


func get_class_data() -> ClassData:
	if template and template.class_data:
		return template.class_data
	return class_data


func get_team_id() -> String:
	if template:
		return template.team_id
	return team_id


func get_primary_weapon() -> WeaponData:
	if template and template.primary_weapon:
		return template.primary_weapon
	return null


func get_secondary_weapon() -> WeaponData:
	if template and template.secondary_weapon:
		return template.secondary_weapon
	return null
