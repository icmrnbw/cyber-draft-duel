extends Control
## Battle overlay: per-unit status for both sides, match timer, 3-2-1 countdown, and
## the result banner. Builds its children in code so the .tscn stays trivial —
## Stage 4 will replace this with a designed, skinned layout.

const TEAM_A_COLOR := Color(0.15, 0.75, 1.0)
const TEAM_B_COLOR := Color(1.0, 0.42, 0.2)
const DEAD_MODULATE := Color(0.32, 0.32, 0.36, 0.75)

var _slots: Dictionary = {}  ## unit id -> {root: PanelContainer, hp: Label}
var _timer_label: Label
var _countdown_label: Label
var _result_panel: PanelContainer
var _result_title: Label
var _result_detail: Label


func setup(sim: BattleSim) -> void:
	_build_top_bar(sim)
	_build_countdown()
	_build_result_panel()
	refresh(sim)


func _build_top_bar(sim: BattleSim) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24.0
	bar.offset_right = -24.0
	bar.offset_top = 20.0
	bar.offset_bottom = 130.0
	bar.add_theme_constant_override("separation", 16)
	add_child(bar)

	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	bar.add_child(left)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bar.add_child(center)

	var you_label := Label.new()
	you_label.text = "YOU  vs  BOT"
	you_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	you_label.add_theme_font_size_override("font_size", 20)
	center.add_child(you_label)

	_timer_label = Label.new()
	_timer_label.text = "0.0s"
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 30)
	center.add_child(_timer_label)

	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	bar.add_child(right)

	for u in sim.units:
		var parent: HBoxContainer = left if u.team == 0 else right
		parent.add_child(_make_slot(u))


func _make_slot(u: SimUnit) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(140.0, 84.0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.9)
	style.border_color = TEAM_A_COLOR if u.team == 0 else TEAM_B_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = u.def.display_name
	name_label.add_theme_font_size_override("font_size", 17)
	vbox.add_child(name_label)

	var hp_label := Label.new()
	hp_label.add_theme_font_size_override("font_size", 15)
	hp_label.modulate = Color(0.75, 0.8, 0.85)
	vbox.add_child(hp_label)

	_slots[u.id] = {"root": panel, "hp": hp_label}
	return panel


func _build_countdown() -> void:
	_countdown_label = Label.new()
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 128)
	_countdown_label.offset_left = -200.0
	_countdown_label.offset_right = 200.0
	_countdown_label.offset_top = -90.0
	_countdown_label.offset_bottom = 90.0
	add_child(_countdown_label)


func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.set_anchors_preset(Control.PRESET_CENTER)
	_result_panel.offset_left = -260.0
	_result_panel.offset_right = 260.0
	_result_panel.offset_top = -150.0
	_result_panel.offset_bottom = 150.0
	_result_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.96)
	style.border_color = Color(0.3, 0.34, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	_result_panel.add_theme_stylebox_override("panel", style)
	add_child(_result_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_result_panel.add_child(vbox)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(_result_title)

	_result_detail = Label.new()
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_detail.add_theme_font_size_override("font_size", 20)
	_result_detail.modulate = Color(0.75, 0.8, 0.85)
	vbox.add_child(_result_detail)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	var rematch := Button.new()
	rematch.text = "Rematch"
	rematch.custom_minimum_size = Vector2(160.0, 56.0)
	rematch.pressed.connect(func() -> void: GameManager.rematch())
	buttons.add_child(rematch)

	var menu := Button.new()
	menu.text = "Main Menu"
	menu.custom_minimum_size = Vector2(160.0, 56.0)
	menu.pressed.connect(func() -> void: GameManager.return_to_main_menu())
	buttons.add_child(menu)


func refresh(sim: BattleSim) -> void:
	_timer_label.text = "%.1fs" % sim.elapsed
	for u in sim.units:
		var slot: Dictionary = _slots[u.id]
		var hp_label: Label = slot["hp"]
		var root: PanelContainer = slot["root"]
		if u.alive:
			hp_label.text = "%d HP" % roundi(u.hp)
		else:
			hp_label.text = "DOWN"
			root.modulate = DEAD_MODULATE


func show_countdown(seconds_left: float) -> void:
	_countdown_label.visible = true
	var n := ceili(seconds_left)
	_countdown_label.text = str(n) if n > 0 else "FIGHT"


func hide_countdown() -> void:
	_countdown_label.visible = false


func show_result(sim: BattleSim) -> void:
	match sim.result:
		BattleSim.Result.TEAM_A:
			_result_title.text = "VICTORY"
			_result_title.modulate = TEAM_A_COLOR
		BattleSim.Result.TEAM_B:
			_result_title.text = "DEFEAT"
			_result_title.modulate = TEAM_B_COLOR
		_:
			_result_title.text = "DRAW"
			_result_title.modulate = Color(0.85, 0.85, 0.85)

	_result_detail.text = "Units remaining — You: %d   Bot: %d\nMatch time: %.1fs" % [
		sim.alive_count(0), sim.alive_count(1), sim.elapsed,
	]
	_result_panel.visible = true
