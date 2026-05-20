class_name EncounterData
extends Resource

@export var encounter_id := ""
@export var display_name := ""
@export var grid_radius := 0
@export var teams: Array[TeamData] = []
@export var spawns: Array[EncounterSpawn] = []


func get_team_data(team_id: String) -> TeamData:
	for t in teams:
		if t.team_id == team_id:
			return t
	return null


func get_player_team() -> TeamData:
	for t in teams:
		if t.is_player:
			return t
	return null


func get_enemy_teams() -> Array:
	var result: Array = []
	for t in teams:
		if not t.is_player:
			result.append(t)
	return result
