extends Control
## Main menu. "Find Match" arrives in Stage 7 — Stage 3 is bot-only.

@onready var _play_button: Button = $Margin/Layout/PlayButton
@onready var _quit_button: Button = $Margin/Layout/QuitButton


func _ready() -> void:
	_play_button.pressed.connect(func() -> void: GameManager.start_new_match())
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	# Android's back button / desktop Esc shouldn't kill the app silently elsewhere,
	# but on the menu quitting is the expected behavior.
	_play_button.grab_focus()
