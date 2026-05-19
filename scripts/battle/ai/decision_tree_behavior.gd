class_name DecisionTreeBehavior
extends EnemyBehavior

## Runs a DecisionNode tree. Assign root in the inspector.
## Empty root falls back to no actions (turn ends immediately).

@export var root: DecisionNode
@export var fallback: EnemyBehavior


func plan(context: EnemyAIContext) -> Array:

	if root:
		var result := root.evaluate(context)

		if not result.is_empty():
			if result[-1].type != AIIntent.Type.END_TURN:
				result.append(AIIntent.end_turn())

			return result

	if fallback:
		return fallback.plan(context)

	return [AIIntent.end_turn()]
