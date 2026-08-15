class_name UnitDefinition
extends Resource
## Balance data for one unit type. Instances live in project/resources/*.tres —
## tune numbers in the Inspector without touching code.
##
## Range model: `preferred_range` is BOTH the attack range and the "advance if the
## enemy is further than this" threshold, and `retreat_range` is the "back off if the
## enemy is closer than this" threshold. That gives every unit one shared behavior:
##
##     dist > preferred_range  -> advance
##     dist < retreat_range    -> retreat
##     otherwise               -> hold
##     dist <= preferred_range -> attack (on cooldown)
##
## Melee sets retreat_range = 0 so it never backs off, which reduces to "charge the
## nearest enemy, attack on contact" with no special-casing.

enum UnitType { MELEE, MID, LONG }

@export var display_name: String = ""
@export var type: UnitType = UnitType.MELEE
@export var icon: Texture2D
## One-line description shown on the draft card.
@export var description: String = ""

@export_group("Combat")
@export var hp: float = 100.0
@export var damage_per_hit: float = 10.0
@export var attacks_per_second: float = 1.0

@export_group("Movement & Range")
@export var move_speed: float = 4.0
## Attack range AND the distance the unit tries to hold. Advances when further away.
@export var preferred_range: float = 1.5
## Backs off when an enemy is closer than this. 0 = never retreats (melee).
@export var retreat_range: float = 0.0

@export_group("Placeholder Art")
## Stage 3 renders units as capsules. Stage 4 swaps in real models via `scene`.
@export var body_radius: float = 0.35
@export var body_height: float = 1.8
@export var accent_color: Color = Color.WHITE

@export_group("Spawn")
## Stage 4: real unit model. Left null in Stage 3 (capsule placeholders are built in code).
@export var scene: PackedScene


## Damage per second, derived. Used by the draft UI and the Stage 6 balance report.
func dps() -> float:
	return damage_per_hit * attacks_per_second


## Seconds between attacks.
func attack_interval() -> float:
	return 1.0 / attacks_per_second if attacks_per_second > 0.0 else INF
