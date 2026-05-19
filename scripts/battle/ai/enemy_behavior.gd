class_name EnemyBehavior
extends Resource

## Base class for enemy decision logic.
## Subclasses implement plan() and return a list of AIIntent.
## Swap behaviors per encounter, class, or unit via EnemyBrain / ClassData.


func plan(_context: EnemyAIContext) -> Array:
	return []
