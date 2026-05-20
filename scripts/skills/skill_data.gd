class_name SkillData
extends Resource

## Unique identifier for this skill.
@export var skill_id := ""
@export var skill_name := ""
@export var description := ""
@export var icon: Texture2D

## AP cost to use this skill.
@export var ap_cost := 1

## Maximum range from caster to target. 0 = self, -1 = unlimited.
@export var skill_range := 1

## Maximum number of uses per battle. -1 = unlimited.
@export var max_uses := -1

## Targeting mode for this skill.
enum TargetMode { SELF, SINGLE_UNIT, SINGLE_TILE, AOE_CIRCLE }
@export var target_mode := TargetMode.SINGLE_UNIT

## Which teams can be targeted.
enum TeamFilter { ALLY, ENEMY, BOTH, SELF_ONLY }
@export var team_filter := TeamFilter.ENEMY

## Radius for AOE skills.
@export var aoe_radius := 0

## Effects applied when the skill is used.
@export var effects: Array[SkillEffect] = []

## Status effects applied to the target.
@export var status_effects: Array[StatusEffect] = []

## Status effects applied to the caster.
@export var self_effects: Array[StatusEffect] = []