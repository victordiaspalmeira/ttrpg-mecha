class_name SimpleChaseBehavior
extends EnemyBehavior

## Default AI: attack if possible, step toward nearest foe, attack again.


func plan(context: EnemyAIContext) -> Array:

	var intents: Array = []
	var target: UnitBase = context.find_nearest_opponent()

	if not target:
		intents.append(AIIntent.end_turn())
		return intents

	if context.can_attack(target):
		intents.append(AIIntent.attack(target))

	var move_tile: HexTile = context.find_best_move_tile_toward(target)

	if move_tile:
		intents.append(AIIntent.move(move_tile))

	if context.can_attack(target):
		intents.append(AIIntent.attack(target))

	intents.append(AIIntent.end_turn())
	return intents
