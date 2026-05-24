class_name ClassData
extends Resource

@export var class_id := ""
@export var display_name := ""
@export var portrait: Texture2D

## Which sprite variant to use: "grey", "cyan", "yellow", "orange", "red"
@export var sprite_variant := "grey"

@export var max_hp := 5
@export var movement := 6
@export var max_ap := 4
@export var defense := 0

## Base attack power (added to weapon power for total damage)
@export var base_attack := 2

@export var primary_weapon: WeaponData
@export var secondary_weapon: WeaponData

## Skills this class can use.
@export var skills: Array[SkillData] = []

## Passive effects always active for this class.
@export var passives: Array[PassiveEffect] = []

## Optional per-class AI. Falls back to EnemyBrain.default_behavior.
@export var enemy_behavior: EnemyBehavior