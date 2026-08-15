# Cyber Draft-Duel

A tactical auto-battler mobile game built in Godot 4.7. Draft your team, watch them fight automatically, and master the counter-triangle meta.

## Project Overview

**Genre:** Tactical Auto-Battler
**Platform:** Android (mobile), iOS as a fast follow
**Engine:** Godot 4.7.1 (stable), GDScript, Mobile rendering method
**Status:** Stage 3 — Core Gameplay Loop vs. Bot Complete

Previously prototyped in Unity — see `../cyber-draft-duel_old/` and the "Engine history" note in `../mvp-development-plan.md` for why the project moved to Godot.

## Game Concept

Players draft 4 units from 3 available types, then watch them fight automatically in a bounded arena. Victory goes to the last side standing. Full design in `../design-doc.md`.

### The Counter-Triangle
- **Melee beats Long-range** — fast bruisers close the gap and overwhelm snipers
- **Mid beats Melee** — kiting units maintain distance and chip away at melee
- **Long beats Mid** — snipers outrange mid-range units and pick them off

### MVP Units
1. **Enforcer** (Melee) — 160 HP, ~40 DPS, 4.5 m/s, ~1.5m range
2. **Trooper** (Mid) — 100 HP, ~28 DPS, 5.5 m/s, 6m preferred range
3. **Marksman** (Long) — 70 HP, ~33 DPS, 2.8 m/s, 11m preferred range

## Project Structure

```
project/
├── art/                    # Sprites, models, materials
├── audio/                  # Sound effects, music
├── prefabs/                # Unit scenes (Godot's prefab equivalent), UI components
├── resources/               # UnitDefinition .tres instances (balance data)
├── scenes/                 # main_menu.tscn, draft.tscn, battle.tscn
├── scripts/
│   ├── core/               # game_manager.gd (autoload), future core systems
│   ├── units/               # unit_definition.gd, unit runtime behavior
│   ├── draft/               # Draft UI logic
│   ├── combat/               # Battle simulation
│   ├── ui/                  # General UI components
│   └── networking/           # (Future) PvP networking
└── settings/                # Input map notes, project-wide settings
```

## Setup Instructions

### Prerequisites
- Godot 4.7.1 (stable) — installed via `winget install --id GodotEngine.GodotEngine`
- Android build template + SDK/NDK/JDK for exporting (Project > Export > Android in the editor will prompt/link to Godot's Android export docs the first time)
- Android device for testing (USB debugging enabled) or an emulator

### Opening the Project
1. Open Godot 4.7.1
2. Click "Import" → navigate to `D:\vapecoder\cyber-draft-duel\project.godot`
3. Open the project

### Exporting for Android
1. Project → Export
2. Add an Android export preset if one isn't already configured (requires Android SDK/NDK/JDK — Godot's editor links directly to the setup docs)
3. Connect your Android device via USB, or use "Remote Deploy" from the editor's Android menu for one-click deploy

## Development Stages

- ✅ **Stage 1:** Design & Technical Doc (Complete) — see `../design-doc.md`
- ✅ **Stage 2:** Godot Foundation Setup (Complete)
  - Folder structure created (`project/{art,audio,prefabs,resources,scenes,scripts,settings}`)
  - Git repository initialized
  - `UnitDefinition` Resource script created
  - `GameManager` autoload singleton implemented
  - Empty scenes ready (main_menu, draft, battle)
- ✅ **Stage 3:** Core Gameplay Loop vs. Bot (Complete)
  - 3 `UnitDefinition` resources with design-doc stats
  - Draft screen: tap to fill 4 slots, duplicates allowed, Ready gating
  - Bot opponent picks one of 3 canned hands per match
  - Deterministic `BattleSim` — fixed timestep, seeded RNG, no engine physics
  - Battle scene: arena, capsule unit views, health bars, death animation
  - HUD with per-unit status, timer, 3-2-1 countdown, result banner
  - Headless smoke test (`sim_smoke_test.gd`) covering determinism + balance
- 🔲 **Stage 4:** Visual Art & Animation (Next)
- 🔲 **Stage 5:** Audio
- 🔲 **Stage 6:** Balance Pass & Simulation Harness
- 🔲 **Stage 7:** Online PvP
- 🔲 **Stage 8:** Polish, Build & Ship

## Key Scripts

### scripts/core/game_manager.gd
Autoload singleton (persists across scene changes automatically — no `DontDestroyOnLoad` equivalent needed in Godot). Holds match state (`player_hand`, `opponent_hand`) and exposes `start_new_match()`, `start_battle()`, `return_to_main_menu()` for scene flow.

### scripts/units/unit_definition.gd
`Resource` script (`class_name UnitDefinition`) defining a unit's stats — Godot's equivalent of a Unity ScriptableObject. Instances live in `project/resources/*.tres`; tune them in the Inspector.

**Range model:** `preferred_range` is both the attack range *and* the "advance if further than this" threshold; `retreat_range` is the "back off if closer than this" threshold. Melee sets `retreat_range = 0`, so all three archetypes share one behavior path with no special-casing.

### scripts/combat/battle_sim.gd
The deterministic simulation, and the most important file in the project. Pure `RefCounted` — no Node, no rendering, no Godot physics. Advances by a fixed `TICK_DELTA` (1/60s), iterates by id, breaks ties by lowest id, and uses only an explicitly-seeded RNG. Stage 6's headless harness and Stage 7's lockstep networking both build directly on this.

### scripts/combat/battle_controller.gd
Renders the sim. Builds the arena, spawns `UnitView`s, ticks the sim in `_physics_process`, feeds the HUD. Never mutates unit state — the sim is the single source of truth.

## Running the tests

Headless correctness + balance check (no editor needed):

```bash
godot --headless --path . --script project/scripts/combat/sim_smoke_test.gd
```

Exit code reflects **correctness only** (determinism, termination, state validity). Balance is reported as data, not asserted — tuning is Stage 6's job.

## Known findings (see mvp-development-plan.md)

- **Counter-triangle: 2 of 3 edges hold.** "Melee beats Long" is inverted — 4 Marksmen focus-fire 180 damage per volley, one-shotting a 160 HP Enforcer during its 18m approach. Design decision pending; deferred to Stage 6.
- **Mirror hands always draw.** Identical hands + deterministic sim + mirrored spawns means both sides die on the same tick.

## Next Steps (Stage 4)

Visual art and animation — real unit models replacing the capsule placeholders (via `UnitDefinition.scene`), arena environment, UI skin, and VFX.

## Design Documents

- `../design-doc.md` — Stage 1 output: unit balance, arena spec, win conditions
- `../mvp-development-plan.md` — the full 8-stage plan with ready-to-paste prompts for each stage

## Git

Repository initialized with a Godot-specific `.gitignore` (`.godot/`, export artifacts, etc.).
```bash
git add .
git commit -m "Your message"
```

## Notes

- Combat is fully automatic — no player input during battles
- Duplicates allowed in draft (e.g., 4x Trooper is legal)
- Arena: 24m × 14m rectangular arena with hard boundaries
- Win condition: eliminate all enemy units (timeout at 90s → most HP wins)
