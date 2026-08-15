class_name BattleSim
extends RefCounted
## Deterministic, headless battle simulation. No Node, no rendering, no Godot physics.
##
## Determinism notes (Stage 7 will audit this — keep it true):
##   - Advances by a fixed TICK_DELTA, never by a frame delta.
##   - All iteration is by index/id, never over an unordered set.
##   - Nearest-enemy ties break by lowest id.
##   - The only randomness is `rng`, always explicitly seeded via setup().
##   - Movement is plain vector math. Godot's physics engine is NOT used anywhere.
##   - REMAINING RISK: Vector2.length()/distance_to() use sqrt, and _retreat_position()
##     uses rotated() (sin/cos). Those can differ in the last bit across architectures.
##     Fine on a single device; revisit in Stage 7 if an Android/iOS cross-check ever
##     desyncs (fixed-point math, or a per-tick lockstep checksum to detect drift).

const TICK_DELTA := 1.0 / 60.0

## Arena, per the design doc: 24m x 14m, hard walls, no cover.
const ARENA_WIDTH := 24.0
const ARENA_DEPTH := 14.0
const UNIT_RADIUS := 0.5

const SPAWN_X_A := 3.0
const SPAWN_X_B := 21.0
const SPAWN_Z_MIN := 5.0
const SPAWN_Z_MAX := 9.0

## Safety net from the design doc — real matches should end well under 30s.
const MATCH_TIMEOUT := 90.0

enum Result { IN_PROGRESS, TEAM_A, TEAM_B, DRAW }

var units: Array[SimUnit] = []
var elapsed: float = 0.0
var result: Result = Result.IN_PROGRESS
var rng := RandomNumberGenerator.new()

## Per-tick events for the view layer to drain (Stage 4 VFX / Stage 5 SFX hooks).
## Cleared at the start of every tick. [{type="attack", attacker_id, target_id},
## {type="death", unit_id}]
var events: Array = []


func setup(hand_a: Array[UnitDefinition], hand_b: Array[UnitDefinition], seed_value: int) -> void:
	units.clear()
	events.clear()
	elapsed = 0.0
	result = Result.IN_PROGRESS
	rng.seed = seed_value

	_spawn_hand(hand_a, 0, SPAWN_X_A)
	_spawn_hand(hand_b, 1, SPAWN_X_B)


func _spawn_hand(hand: Array[UnitDefinition], team: int, spawn_x: float) -> void:
	for i in range(hand.size()):
		var u := SimUnit.new()
		u.id = units.size()
		u.team = team
		u.def = hand[i]
		u.hp = u.def.hp
		u.pos = Vector2(spawn_x, _spawn_z(i, hand.size()))
		units.append(u)


func _spawn_z(index: int, count: int) -> float:
	if count <= 1:
		return (SPAWN_Z_MIN + SPAWN_Z_MAX) * 0.5
	var t := float(index) / float(count - 1)
	return lerpf(SPAWN_Z_MIN, SPAWN_Z_MAX, t)


## Advances the simulation exactly TICK_DELTA seconds.
func tick() -> void:
	if result != Result.IN_PROGRESS:
		return

	events.clear()
	elapsed += TICK_DELTA

	_acquire_targets()
	_attack()      # decided before movement, so a unit dying this tick still fires
	_move()
	_resolve_separation()
	_clamp_to_arena()
	_apply_damage()
	_evaluate_result()


## Runs until the match resolves. Used by the Stage 6 headless harness.
## Returns the number of ticks taken.
func run_to_completion() -> int:
	var ticks := 0
	var max_ticks := int(MATCH_TIMEOUT / TICK_DELTA) + 2
	while result == Result.IN_PROGRESS and ticks < max_ticks:
		tick()
		ticks += 1
	return ticks


func _acquire_targets() -> void:
	for u in units:
		if not u.alive:
			continue
		var best_id := -1
		var best_dist_sq := INF
		for other in units:
			if not other.alive or other.team == u.team:
				continue
			var d := u.pos.distance_squared_to(other.pos)
			# Ties break by lowest id — required for determinism.
			if d < best_dist_sq or (d == best_dist_sq and other.id < best_id):
				best_dist_sq = d
				best_id = other.id
		u.target_id = best_id


func _attack() -> void:
	for u in units:
		if not u.alive:
			continue
		u.attack_cooldown = maxf(0.0, u.attack_cooldown - TICK_DELTA)
		if u.target_id < 0:
			continue
		var target := units[u.target_id]
		if not target.alive:
			continue
		if u.pos.distance_to(target.pos) > u.def.preferred_range:
			continue
		if u.attack_cooldown > 0.0:
			continue
		target.pending_damage += u.def.damage_per_hit
		u.attack_cooldown = u.def.attack_interval()
		events.append({"type": "attack", "attacker_id": u.id, "target_id": target.id})


func _move() -> void:
	for u in units:
		if not u.alive or u.target_id < 0:
			continue
		var target := units[u.target_id]
		if not target.alive:
			continue

		var to_target := target.pos - u.pos
		var dist := to_target.length()
		var dir: Vector2
		if dist > 0.0001:
			dir = to_target / dist
		else:
			# Deterministic fallback when exactly coincident.
			dir = Vector2.RIGHT if u.team == 0 else Vector2.LEFT

		var step := u.def.move_speed * TICK_DELTA
		if dist > u.def.preferred_range:
			u.pos += dir * step
		elif dist < u.def.retreat_range:
			u.pos = _retreat_position(u, -dir, step, target.pos)
		# else: hold position


## Retreat directions to try, in order: straight away first, then progressively more
## sideways. Fixed order + strict `>` scoring means ties resolve to the straightest
## option, which keeps this deterministic.
const RETREAT_ANGLES: Array = [0.0, -30.0, 30.0, -60.0, 60.0, -90.0, 90.0, -120.0, 120.0]


## Picks where a retreating unit actually goes. Moving straight away from the threat
## is preferred, but a unit backed against a wall would otherwise just pin itself
## there and die — so it slides along the wall instead. This is what makes the design
## doc's kiting behavior possible at all; without it Trooper can never out-space
## Enforcer, because it spawns only 2.5m from its own back wall.
func _retreat_position(u: SimUnit, away_dir: Vector2, step: float, threat_pos: Vector2) -> Vector2:
	var best_pos := u.pos
	var best_score := -INF

	for angle_deg in RETREAT_ANGLES:
		var candidate := u.pos + away_dir.rotated(deg_to_rad(angle_deg)) * step
		if candidate.x < UNIT_RADIUS or candidate.x > ARENA_WIDTH - UNIT_RADIUS:
			continue
		if candidate.y < UNIT_RADIUS or candidate.y > ARENA_DEPTH - UNIT_RADIUS:
			continue
		var score := candidate.distance_squared_to(threat_pos)
		if score > best_score:
			best_score = score
			best_pos = candidate

	return best_pos


## Keeps units from stacking into one blob. Deterministic: pairs visited in id order.
func _resolve_separation() -> void:
	var min_dist := UNIT_RADIUS * 2.0
	for i in range(units.size()):
		var a := units[i]
		if not a.alive:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if not b.alive:
				continue
			var delta := b.pos - a.pos
			var d := delta.length()
			if d >= min_dist:
				continue
			var push: Vector2
			if d > 0.0001:
				push = (delta / d) * ((min_dist - d) * 0.5)
			else:
				push = Vector2(0.0, 0.005)
			a.pos -= push
			b.pos += push


func _clamp_to_arena() -> void:
	for u in units:
		if not u.alive:
			continue
		u.pos.x = clampf(u.pos.x, UNIT_RADIUS, ARENA_WIDTH - UNIT_RADIUS)
		u.pos.y = clampf(u.pos.y, UNIT_RADIUS, ARENA_DEPTH - UNIT_RADIUS)


func _apply_damage() -> void:
	for u in units:
		if not u.alive:
			continue
		if u.pending_damage > 0.0:
			u.hp -= u.pending_damage
			u.pending_damage = 0.0
			if u.hp <= 0.0:
				u.hp = 0.0
				u.alive = false
				u.target_id = -1
				events.append({"type": "death", "unit_id": u.id})


func _evaluate_result() -> void:
	var a_alive := alive_count(0)
	var b_alive := alive_count(1)

	if a_alive == 0 and b_alive == 0:
		result = Result.DRAW
	elif b_alive == 0:
		result = Result.TEAM_A
	elif a_alive == 0:
		result = Result.TEAM_B
	elif elapsed >= MATCH_TIMEOUT:
		# Timeout tiebreak: most total remaining HP wins, exact tie is a draw.
		var a_hp := total_hp(0)
		var b_hp := total_hp(1)
		if a_hp > b_hp:
			result = Result.TEAM_A
		elif b_hp > a_hp:
			result = Result.TEAM_B
		else:
			result = Result.DRAW


func alive_count(team: int) -> int:
	var n := 0
	for u in units:
		if u.alive and u.team == team:
			n += 1
	return n


func total_hp(team: int) -> float:
	var sum := 0.0
	for u in units:
		if u.alive and u.team == team:
			sum += u.hp
	return sum
