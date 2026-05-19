class_name HasTargetInAttackRange
extends AICondition

## Example condition for decision trees.


func is_met(context: EnemyAIContext) -> bool:

	var target: UnitBase = context.find_nearest_opponent()

	if not target:
		return false

	return context.can_attack(target)
