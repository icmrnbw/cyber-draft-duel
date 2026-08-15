extends Node3D
## Drives the battle scene: builds the arena, spawns unit views, ticks the sim on a
## fixed timestep, and reports state to the HUD.
##
## The sim is the source of truth. This class only renders it — it never changes
## unit state, which is what keeps the Stage 7 determinism story simple.

enum Phase { COUNTDOWN, FIGHTING, FINISHED }

const COUNTDOWN_SECONDS := 3.0

@onready var _hud: Control = $HUD/BattleHUD

var sim: BattleSim
var phase: Phase = Phase.COUNTDOWN

var _views: Dictionary = {}  ## unit id -> UnitView
var _countdown_left: float = COUNTDOWN_SECONDS


func _ready() -> void:
	var hand_a := GameManager.player_hand
	var hand_b := GameManager.opponent_hand

	# Allows running battle.tscn directly (F6) without going through the draft.
	if hand_a.is_empty() or hand_b.is_empty():
		push_warning("No drafted hands found — using debug hands. Run from MainMenu for a real match.")
		var debug_rng := RandomNumberGenerator.new()
		debug_rng.seed = 12345
		hand_a = UnitDatabase.random_bot_hand(debug_rng)
		hand_b = UnitDatabase.random_bot_hand(debug_rng)
		GameManager.player_hand = hand_a
		GameManager.opponent_hand = hand_b
		GameManager.match_seed = 12345

	sim = BattleSim.new()
	sim.setup(hand_a, hand_b, GameManager.match_seed)

	_build_arena()
	_spawn_views()
	_hud.setup(sim)


func _physics_process(_delta: float) -> void:
	match phase:
		Phase.COUNTDOWN:
			_countdown_left -= BattleSim.TICK_DELTA
			_hud.show_countdown(_countdown_left)
			if _countdown_left <= 0.0:
				phase = Phase.FIGHTING
				_hud.hide_countdown()

		Phase.FIGHTING:
			sim.tick()
			_hud.refresh(sim)
			if sim.result != BattleSim.Result.IN_PROGRESS:
				phase = Phase.FINISHED
				GameManager.last_result = sim.result
				_hud.show_result(sim)

		Phase.FINISHED:
			pass


## Called by UnitView so a unit can face its target.
func get_unit_pos(unit_id: int) -> Vector2:
	if unit_id < 0 or unit_id >= sim.units.size():
		return Vector2.ZERO
	return sim.units[unit_id].pos


func _spawn_views() -> void:
	for u in sim.units:
		var view := UnitView.new()
		add_child(view)
		view.setup(u)
		_views[u.id] = view


func _build_arena() -> void:
	var w := BattleSim.ARENA_WIDTH
	var d := BattleSim.ARENA_DEPTH

	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(w, 0.2, d)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.2, 0.22, 0.27)
	floor_mat.roughness = 0.9
	floor_mesh.mesh.material = floor_mat
	floor_mesh.position = Vector3(w * 0.5, -0.1, d * 0.5)
	add_child(floor_mesh)

	# Center line, purely cosmetic.
	var center_line := MeshInstance3D.new()
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.08, 0.02, d)
	center_line.mesh = line_mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.3, 0.34, 0.4)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center_line.mesh.material = line_mat
	center_line.position = Vector3(w * 0.5, 0.01, d * 0.5)
	add_child(center_line)

	# Walls — visual only. The sim clamps positions itself; no physics bodies here.
	var wall_h := 0.5
	var wall_t := 0.2
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.22, 0.25, 0.32)
	_add_wall(Vector3(w * 0.5, wall_h * 0.5, 0.0), Vector3(w, wall_h, wall_t), wall_mat)
	_add_wall(Vector3(w * 0.5, wall_h * 0.5, d), Vector3(w, wall_h, wall_t), wall_mat)
	_add_wall(Vector3(0.0, wall_h * 0.5, d * 0.5), Vector3(wall_t, wall_h, d), wall_mat)
	_add_wall(Vector3(w, wall_h * 0.5, d * 0.5), Vector3(wall_t, wall_h, d), wall_mat)


func _add_wall(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	wall.mesh = box
	wall.mesh.material = mat
	wall.position = pos
	add_child(wall)
