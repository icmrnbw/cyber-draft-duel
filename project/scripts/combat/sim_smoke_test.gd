extends SceneTree
## Headless check for BattleSim. Run with:
##   godot --headless --path . --script project/scripts/combat/sim_smoke_test.gd
##
## Two separate concerns, deliberately not conflated:
##   CORRECTNESS — the sim is deterministic, terminates, and never produces invalid
##     state. These are code defects. Exit code reflects only these.
##   BALANCE — whether the design doc's counter-triangle actually holds. Reported as
##     data, not asserted, because tuning is Stage 6's job and the numbers are a
##     design decision. A broken triangle here is a finding, not a bug.
##
## Stage 6 grows this into the full 15-hand / 225-matchup balance harness.

const ENFORCER := preload("res://project/resources/enforcer.tres")
const TROOPER := preload("res://project/resources/trooper.tres")
const MARKSMAN := preload("res://project/resources/marksman.tres")

const RUNS := 20


func _initialize() -> void:
	var failures := 0

	print("=== CORRECTNESS ===\n")
	failures += _check_determinism()
	failures += _check_all_matchups_terminate()
	failures += _check_state_validity()

	print("\n=== BALANCE (Stage 6 territory — reported, not asserted) ===\n")
	_report_triangle()
	_report_mirrors()

	if failures == 0:
		print("\nCorrectness: all checks PASSED")
	else:
		printerr("\nCorrectness: %d check(s) FAILED" % failures)

	quit(1 if failures > 0 else 0)


func _hand_of(unit_def: UnitDefinition) -> Array[UnitDefinition]:
	var hand: Array[UnitDefinition] = []
	for i in range(4):
		hand.append(unit_def)
	return hand


func _simulate(a: UnitDefinition, b: UnitDefinition, seed_value: int) -> BattleSim:
	var sim := BattleSim.new()
	sim.setup(_hand_of(a), _hand_of(b), seed_value)
	sim.run_to_completion()
	return sim


## Runs RUNS matches and returns [a_wins, b_wins, draws, avg_seconds].
func _run_matchup(a: UnitDefinition, b: UnitDefinition) -> Array:
	var a_wins := 0
	var b_wins := 0
	var draws := 0
	var total_time := 0.0

	for i in range(RUNS):
		var sim := _simulate(a, b, 1000 + i)
		total_time += sim.elapsed
		match sim.result:
			BattleSim.Result.TEAM_A:
				a_wins += 1
			BattleSim.Result.TEAM_B:
				b_wins += 1
			_:
				draws += 1

	return [a_wins, b_wins, draws, total_time / float(RUNS)]


# --- correctness ---------------------------------------------------------------

## Same seed + same hands must reproduce a bit-identical match.
func _check_determinism() -> int:
	var a := _simulate(ENFORCER, TROOPER, 777)
	var b := _simulate(ENFORCER, TROOPER, 777)

	if a.elapsed != b.elapsed or a.result != b.result:
		printerr("FAIL determinism: same seed diverged")
		return 1

	for i in range(a.units.size()):
		if a.units[i].hp != b.units[i].hp or a.units[i].pos != b.units[i].pos:
			printerr("FAIL determinism: unit %d state diverged" % i)
			return 1

	print("PASS determinism — same seed reproduces exactly")
	return 0


## Every matchup must resolve, and (per the design doc) real matches should land well
## under the 90s timeout. Hitting the timeout means something is stalemating.
func _check_all_matchups_terminate() -> int:
	var roster := [ENFORCER, TROOPER, MARKSMAN]
	var worst := 0.0
	var timed_out := 0

	for a in roster:
		for b in roster:
			var sim := _simulate(a, b, 4242)
			worst = maxf(worst, sim.elapsed)
			if sim.elapsed >= BattleSim.MATCH_TIMEOUT:
				timed_out += 1
				printerr("FAIL terminate: %s x4 vs %s x4 hit the 90s timeout" % [
					a.display_name, b.display_name,
				])

	if timed_out > 0:
		return 1
	print("PASS terminate — all 9 matchups resolved, slowest %.1fs" % worst)
	return 0


## No unit may finish with negative HP, outside the arena, or alive-with-0-HP.
func _check_state_validity() -> int:
	var problems := 0
	var roster := [ENFORCER, TROOPER, MARKSMAN]

	for a in roster:
		for b in roster:
			var sim := _simulate(a, b, 99)
			for u in sim.units:
				if u.hp < 0.0:
					printerr("FAIL validity: %s ended at %.1f HP" % [u.def.display_name, u.hp])
					problems += 1
				if u.alive and u.hp <= 0.0:
					printerr("FAIL validity: %s alive at 0 HP" % u.def.display_name)
					problems += 1
				var r := BattleSim.UNIT_RADIUS
				if u.pos.x < r - 0.01 or u.pos.x > BattleSim.ARENA_WIDTH - r + 0.01 \
						or u.pos.y < r - 0.01 or u.pos.y > BattleSim.ARENA_DEPTH - r + 0.01:
					printerr("FAIL validity: %s escaped the arena at %v" % [
						u.def.display_name, u.pos,
					])
					problems += 1

	if problems > 0:
		return 1
	print("PASS validity — no negative HP, no zombies, nobody left the arena")
	return 0


# --- balance reporting ---------------------------------------------------------

func _report_triangle() -> void:
	print("Counter-triangle (design doc expects the first side to win each row):")
	var rows := [
		["Melee beats Long", ENFORCER, MARKSMAN],
		["Mid beats Melee", TROOPER, ENFORCER],
		["Long beats Mid", MARKSMAN, TROOPER],
	]
	var holding := 0
	for row in rows:
		var r := _run_matchup(row[1], row[2])
		var verdict := "HOLDS" if r[0] > r[1] else "INVERTED"
		if r[0] > r[1]:
			holding += 1
		print("  %-18s %-9s %2d W | %-9s %2d W | %d D | avg %5.1fs  -> %s" % [
			row[0], row[1].display_name, r[0], row[2].display_name, r[1], r[2], r[3], verdict,
		])
	print("  %d of 3 triangle edges hold." % holding)


func _report_mirrors() -> void:
	print("\nMirror matchups (identical hands — perfect symmetry):")
	for unit_def in [ENFORCER, TROOPER, MARKSMAN]:
		var r := _run_matchup(unit_def, unit_def)
		print("  %-9s  %2d W / %2d W / %2d D   avg %.1fs" % [
			unit_def.display_name, r[0], r[1], r[2], r[3],
		])
	print("  Note: mirrors always draw. Identical hands + deterministic sim + mirrored")
	print("  spawns means both sides die on the same tick. Design decision needed if")
	print("  guaranteed draws on mirror drafts are unacceptable.")
