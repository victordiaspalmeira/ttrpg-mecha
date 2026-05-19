class_name DecisionNode
extends Resource

## Branch: condition + on_true / on_false.
## Leaf: assign leaf_behavior (e.g. SimpleChaseBehavior) or subclass this node.

@export var condition: AICondition
@export var on_true: DecisionNode
@export var on_false: DecisionNode
@export var leaf_behavior: EnemyBehavior


func evaluate(context: EnemyAIContext) -> Array:

	if condition:
		if condition.is_met(context):
			if on_true:
				return on_true.evaluate(context)
		elif on_false:
			return on_false.evaluate(context)

		return []

	if leaf_behavior:
		return leaf_behavior.plan(context)

	return []
