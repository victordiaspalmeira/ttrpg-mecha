extends Node

var selected_encounter: Resource = null
var encounters: Array = []


func _ready() -> void:
	_load_encounters()


func _load_encounters() -> void:
	# Busca todos os arquivos .tres na pasta de encontros
	var dir := DirAccess.open("res://data/encounters/")
	if not dir:
		push_error("GameManager: Could not open encounters directory.")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".remap"):
			var clean_name := file_name.trim_suffix(".remap")
			var path := "res://data/encounters/" + clean_name
			var encounter := load(path) as Resource
			if encounter and encounter.get("display_name") != null:
				encounters.append(encounter)
		file_name = dir.get_next()
	dir.list_dir_end()


func start_encounter(encounter: Resource) -> void:
	selected_encounter = encounter
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")


func quit_game() -> void:
	get_tree().quit()