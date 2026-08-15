class_name SimUnit
extends RefCounted
## One unit's runtime state inside BattleSim. Pure data — no Node, no rendering.
## The visual layer (UnitView) reads this; it never writes back.

var id: int = -1
var team: int = 0  ## 0 = player (side A), 1 = opponent (side B)
var def: UnitDefinition

var hp: float = 0.0
## Arena-plane position: x = arena X, y = arena Z. Maps to Vector3(pos.x, 0, pos.y).
var pos: Vector2 = Vector2.ZERO
var target_id: int = -1
var attack_cooldown: float = 0.0
var alive: bool = true

## Damage accumulated this tick, applied all at once at the end so that two units
## can kill each other on the same tick (the design doc's simultaneous-elimination draw).
var pending_damage: float = 0.0


func hp_fraction() -> float:
	return clampf(hp / def.hp, 0.0, 1.0) if def.hp > 0.0 else 0.0
