extends Node
## Persistent autoload. Holds match state between scenes and drives scene flow:
## MainMenu -> Draft -> Battle -> (rematch | MainMenu).

const MAIN_MENU_SCENE := "res://project/scenes/main_menu.tscn"
const DRAFT_SCENE := "res://project/scenes/draft.tscn"
const BATTLE_SCENE := "res://project/scenes/battle.tscn"

## Both hands are exactly UnitDatabase.HAND_SIZE entries once drafted.
var player_hand: Array[UnitDefinition] = []
var opponent_hand: Array[UnitDefinition] = []

## Shared seed for the battle. Stage 7 exchanges exactly this + both hands between
## clients — everything else is derived deterministically from them.
var match_seed: int = 0

## Set by the battle scene when the match resolves (a BattleSim.Result value).
var last_result: int = BattleSim.Result.IN_PROGRESS


func start_new_match() -> void:
	player_hand.clear()
	opponent_hand.clear()
	last_result = BattleSim.Result.IN_PROGRESS
	get_tree().change_scene_to_file(DRAFT_SCENE)


## Called by the draft screen once the player locks in 4 units. Rolls the bot's hand
## and the shared seed, then jumps to the battle.
func start_battle(p_player_hand: Array[UnitDefinition]) -> void:
	player_hand = p_player_hand

	var setup_rng := RandomNumberGenerator.new()
	setup_rng.randomize()
	match_seed = setup_rng.randi()

	var bot_rng := RandomNumberGenerator.new()
	bot_rng.seed = match_seed
	opponent_hand = UnitDatabase.random_bot_hand(bot_rng)

	get_tree().change_scene_to_file(BATTLE_SCENE)


## Replays with the same player hand but a fresh seed (so the bot may pick differently).
func rematch() -> void:
	if player_hand.is_empty():
		start_new_match()
		return
	start_battle(player_hand.duplicate())


func return_to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
