extends Node
## Autoload. The roster of draftable units, plus the bot's canned hands.

const ENFORCER := preload("res://project/resources/enforcer.tres")
const TROOPER := preload("res://project/resources/trooper.tres")
const MARKSMAN := preload("res://project/resources/marksman.tres")

const HAND_SIZE := 4

## Everything the player can draft. Order drives the draft screen's button order.
var roster: Array[UnitDefinition] = [ENFORCER, TROOPER, MARKSMAN]

## Stage 3 bot: a few fixed hands, one picked at random per match. Real bot AI is
## out of scope for MVP — this only needs to exercise the loop.
var _bot_hands: Array = [
	[ENFORCER, ENFORCER, TROOPER, MARKSMAN],  # balanced
	[TROOPER, TROOPER, TROOPER, MARKSMAN],    # kite-heavy
	[ENFORCER, ENFORCER, ENFORCER, TROOPER],  # rush
]


## Picks one of the canned bot hands. `rng` is passed in so match setup stays
## reproducible from a single seed (matters for Stage 7 determinism).
func random_bot_hand(rng: RandomNumberGenerator) -> Array[UnitDefinition]:
	var picked: Array = _bot_hands[rng.randi_range(0, _bot_hands.size() - 1)]
	var hand: Array[UnitDefinition] = []
	for unit_def in picked:
		hand.append(unit_def)
	return hand
