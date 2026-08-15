extends Control
## Draft screen: tap a unit to fill the next hand slot (duplicates allowed, no cap
## per the design doc). "Ready" unlocks once all 4 slots are full.

const SLOT_EMPTY_COLOR := Color(0.1, 0.11, 0.14, 0.9)
const SLOT_FILLED_COLOR := Color(0.12, 0.18, 0.24, 0.95)

@onready var _slot_row: HBoxContainer = $Margin/Layout/HandSlots
@onready var _unit_row: HBoxContainer = $Margin/Layout/UnitButtons
@onready var _ready_button: Button = $Margin/Layout/Actions/ReadyButton
@onready var _clear_button: Button = $Margin/Layout/Actions/ClearButton

var _hand: Array[UnitDefinition] = []
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []


func _ready() -> void:
	_build_slots()
	_build_unit_buttons()

	_ready_button.pressed.connect(_on_ready_pressed)
	_clear_button.pressed.connect(_on_clear_pressed)

	_refresh()


func _build_slots() -> void:
	for i in range(UnitDatabase.HAND_SIZE):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(190.0, 120.0)

		var style := StyleBoxFlat.new()
		style.bg_color = SLOT_EMPTY_COLOR
		style.border_color = Color(0.28, 0.32, 0.4)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		style.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel", style)

		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 22)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		panel.add_child(label)

		_slot_row.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(label)


func _build_unit_buttons() -> void:
	for unit_def in UnitDatabase.roster:
		var button := Button.new()
		button.custom_minimum_size = Vector2(300.0, 170.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n\n%s\n%d HP · %d DPS · %.1f m/s · %.1fm range" % [
			unit_def.display_name,
			unit_def.description,
			roundi(unit_def.hp),
			roundi(unit_def.dps()),
			unit_def.move_speed,
			unit_def.preferred_range,
		]
		button.pressed.connect(_on_unit_picked.bind(unit_def))
		_unit_row.add_child(button)


func _on_unit_picked(unit_def: UnitDefinition) -> void:
	if _hand.size() >= UnitDatabase.HAND_SIZE:
		return
	_hand.append(unit_def)
	_refresh()


func _on_clear_pressed() -> void:
	_hand.clear()
	_refresh()


func _on_ready_pressed() -> void:
	if _hand.size() != UnitDatabase.HAND_SIZE:
		return
	GameManager.start_battle(_hand.duplicate())


func _refresh() -> void:
	for i in range(UnitDatabase.HAND_SIZE):
		var label := _slot_labels[i]
		var style: StyleBoxFlat = _slot_panels[i].get_theme_stylebox("panel")
		if i < _hand.size():
			var unit_def := _hand[i]
			label.text = unit_def.display_name
			label.modulate = unit_def.accent_color
			style.bg_color = SLOT_FILLED_COLOR
			style.border_color = unit_def.accent_color
		else:
			label.text = "Slot %d" % (i + 1)
			label.modulate = Color(0.45, 0.48, 0.55)
			style.bg_color = SLOT_EMPTY_COLOR
			style.border_color = Color(0.28, 0.32, 0.4)

	var full := _hand.size() == UnitDatabase.HAND_SIZE
	_ready_button.disabled = not full
	_ready_button.text = "Ready" if full else "Pick %d more" % (UnitDatabase.HAND_SIZE - _hand.size())
	_clear_button.disabled = _hand.is_empty()
