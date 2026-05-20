class_name WeaponData
extends Resource

@export var weapon_id := ""
@export var weapon_name := ""
@export var weapon_description := ""
@export var weapon_range := 1
@export var attack_ap_cost := 1
@export var weapon_type := "primary"
@export var skill_ids: Array[String] = []
@export var tags: Array[String] = []

## Base damage of the weapon. Added to attacker's attack_power for total damage.
@export var weapon_power := 1

