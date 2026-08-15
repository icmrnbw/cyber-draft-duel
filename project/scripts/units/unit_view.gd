class_name UnitView
extends Node3D
## Visual representation of one SimUnit. Reads sim state every frame; never writes
## back. Stage 3 builds a capsule placeholder in code — Stage 4 replaces the body
## with the real model from UnitDefinition.scene and keeps the rest of this intact.
##
## Node layout matters here:
##   UnitView          <- position only, never rotates
##     Facing          <- rotates to aim at the current target
##       body/accent/nose
##     health bar quads <- must NOT be under Facing, or their world offsets orbit
##                         with the unit and the bar detaches from it visually
##
## The camera is a fixed orthogonal top-down rig with no yaw, so screen-right is
## exactly world +X. That's what lets the bar anchor to its left edge cleanly.

const TEAM_A_COLOR := Color(0.15, 0.75, 1.0)
const TEAM_B_COLOR := Color(1.0, 0.42, 0.2)
const BAR_WIDTH := 1.1
const BAR_HEIGHT := 0.14

var unit: SimUnit

var _facing: Node3D
var _bar_fill: MeshInstance3D
var _bar_bg: MeshInstance3D
var _death_time: float = -1.0


func setup(p_unit: SimUnit) -> void:
	unit = p_unit
	var team_color: Color = TEAM_A_COLOR if unit.team == 0 else TEAM_B_COLOR

	_facing = Node3D.new()
	add_child(_facing)

	# Body: capsule sized per unit type so archetypes read at a glance.
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = unit.def.body_radius
	capsule.height = unit.def.body_height
	body.mesh = capsule
	body.material_override = _make_material(team_color)
	body.position.y = unit.def.body_height * 0.5
	_facing.add_child(body)

	# Accent ring on the ground: the unit's own color, so you can tell the three
	# archetypes apart at a glance even though they're all capsules.
	var accent := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = unit.def.body_radius * 1.6
	ring.bottom_radius = unit.def.body_radius * 1.6
	ring.height = 0.06
	accent.mesh = ring
	accent.material_override = _make_material(unit.def.accent_color, true)
	accent.position.y = 0.04
	_facing.add_child(accent)

	# Nose cone so you can see which way a unit is aimed.
	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = unit.def.body_radius * 0.55
	cone.height = unit.def.body_radius * 1.3
	nose.mesh = cone
	nose.material_override = _make_material(unit.def.accent_color, true)
	nose.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	nose.position = Vector3(0.0, unit.def.body_height * 0.6, -unit.def.body_radius * 1.2)
	_facing.add_child(nose)

	_build_health_bar()
	_sync_transform()


func _build_health_bar() -> void:
	var bar_y := unit.def.body_height + 0.45

	_bar_bg = MeshInstance3D.new()
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_bar_bg.mesh = bg_quad
	_bar_bg.material_override = _make_bar_material(Color(0.03, 0.04, 0.06, 0.9))
	_bar_bg.position = Vector3(0.0, bar_y, 0.0)
	add_child(_bar_bg)

	# Anchored at its left edge: center_offset shifts the quad so local x runs
	# 0..BAR_WIDTH, and the node sits at world -BAR_WIDTH/2. Scaling x then drains
	# the bar rightward instead of shrinking it toward its middle.
	_bar_fill = MeshInstance3D.new()
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(BAR_WIDTH, BAR_HEIGHT * 0.7)
	fill_quad.center_offset = Vector3(BAR_WIDTH * 0.5, 0.0, 0.0)
	_bar_fill.mesh = fill_quad
	var fill_color: Color = TEAM_A_COLOR if unit.team == 0 else TEAM_B_COLOR
	_bar_fill.material_override = _make_bar_material(fill_color)
	_bar_fill.position = Vector3(-BAR_WIDTH * 0.5, bar_y, 0.02)
	add_child(_bar_fill)


func _make_material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.roughness = 0.55
		mat.metallic = 0.2
	return mat


## Bars face the camera. The rig never yaws, so a fixed pitch would also work, but
## billboarding keeps this correct if Stage 4 moves the camera.
func _make_bar_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 2
	return mat


func _process(delta: float) -> void:
	if unit == null:
		return

	if unit.alive:
		_sync_transform()
		_bar_fill.scale.x = unit.hp_fraction()
	elif _death_time < 0.0:
		_death_time = 0.0
		_bar_bg.visible = false
		_bar_fill.visible = false
	else:
		# Quick sink-and-shrink so deaths read clearly without extra assets.
		_death_time += delta
		var t := clampf(_death_time / 0.4, 0.0, 1.0)
		_facing.scale = Vector3.ONE * (1.0 - t)
		_facing.position.y = -t * 0.6
		if t >= 1.0:
			visible = false


func _sync_transform() -> void:
	position = Vector3(unit.pos.x, 0.0, unit.pos.y)

	if unit.target_id >= 0:
		var to_target := _target_pos() - unit.pos
		if to_target.length_squared() > 0.0001:
			# Model forward is -Z (Godot/glTF convention), so the yaw that aims -Z at
			# the target is atan2(-x, -z), NOT atan2(x, z) — the latter points the
			# model 180 degrees away.
			_facing.rotation.y = atan2(-to_target.x, -to_target.y)


func _target_pos() -> Vector2:
	var battle := get_parent()
	if battle != null and battle.has_method("get_unit_pos"):
		return battle.get_unit_pos(unit.target_id)
	return unit.pos
