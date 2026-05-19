class_name AICondition
extends Resource

## Base for decision-tree checks. Override is_met() in custom conditions.


func is_met(_context: EnemyAIContext) -> bool:
	return false
