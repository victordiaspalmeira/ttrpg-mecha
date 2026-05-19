class_name AIIntent
extends RefCounted

enum Type {
	ATTACK,
	MOVE,
	WAIT,
	END_TURN,
}

var type: Type = Type.END_TURN
var target_unit: UnitBase = null
var target_tile: HexTile = null
var wait_seconds: float = 0.0


static func attack(target: UnitBase) -> AIIntent:

	var intent := AIIntent.new()
	intent.type = Type.ATTACK
	intent.target_unit = target
	return intent


static func move(target_tile: HexTile) -> AIIntent:

	var intent := AIIntent.new()
	intent.type = Type.MOVE
	intent.target_tile = target_tile
	return intent


static func wait(seconds: float) -> AIIntent:

	var intent := AIIntent.new()
	intent.type = Type.WAIT
	intent.wait_seconds = seconds
	return intent


static func end_turn() -> AIIntent:

	var intent := AIIntent.new()
	intent.type = Type.END_TURN
	return intent
