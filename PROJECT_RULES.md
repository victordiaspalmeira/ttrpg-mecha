# Project Rules

Read this before adding features. It defines folder layout, wiring, and patterns so humans and AI agents stay consistent.

## Technical
- Godot 4
- Hex axial coordinate system
- 3D environment with 2D billboard sprites (2.5D, Octopath-style)
- Data-driven gameplay using Resources
- Component-based architecture

### Code layout
- `scripts/battle/` — flow, turns, combat rules, selection, input, AI
- `scripts/grid/` — hex grid
- `scripts/units/` — unit actor
- `scripts/presentation/` — HUD, tile highlights, turn announce UI
- `scripts/systems/` — cross-cutting scene services (spawner, audio)
- `scripts/data/` — Resource types (class, weapon, encounter)
- `scripts/components/` — scene components (e.g. hex tile)
- `scripts/core/` — shared non-battle utilities (e.g. camera)
- `data/` — `.tres` content (classes, weapons, encounters, ai)
- `scripts/battle/ai/` — modular enemy AI (`EnemyBehavior`, intents, decision tree stubs)

### Unit visuals (2.5D)
- Units use `Sprite3D` with `BILLBOARD_FIXED_Y` and manual frame animation (see `scenes/units/unit_base.tscn` + `UnitSpriteVisual`). Outline shader enabled by default (`use_outline_shader`).
- `UnitBase.configure_from_grid(GridConfig)` syncs foot height to hex surface. `play_attack_visual()` plays one-shot `transform` then returns to `idle`.
- Placeholder sheets: `assets/sprites/units/placeholder/Gr1_*.png` (80×80 frames). Built at runtime via `Gr1PlaceholderFrames` (`idle`, `idle_powered`, `transform`, `revert`, `full`).
- Team outline colors live in `UnitSpriteVisual.TEAM_OUTLINE_COLORS` (`player` = blue, `enemy` = red). Add new teams there.
- Per-class sprites later: assign a `SpriteFrames` on `UnitVisual` from `ClassData`, or call `UnitSpriteVisual.play("animation_name")`.

### Grid (hex)
- `GridConfig` (`data/grid/default_grid_config.tres`) — `hex_size`, `mesh_radius`, `mesh_height`, `grid_radius`, shared tile/overlay colors.
- `HexMath` (`scripts/grid/hex_math.gd`) — axial distance, `axial_to_world`, `world_to_axial`. Use instead of duplicating formulas.
- `GridManager.initialize(encounter)` — called from `BattleFlow.start_battle()` before spawning units. `EncounterData.grid_radius` overrides config when `> 0`.
- `HexTile` — base mesh uses config materials; move/attack ranges use `HighlightOverlay` (do not swap base material for ranges).
- Do not add a ground `PlaneMesh` under the grid; tiles are the play surface.
- `GridPathPreview` (`World/GridPathPreview`) draws move path in MOVE mode. `MovementRules.find_path()` for BFS path.
- Invalid player actions show feedback via `BattleHud.show_action_feedback()`. Move/Attack modes reset to Idle after a successful action.

### Legacy (do not extend)
- `scripts/systems/ui_system.gd` — replaced by `BattleHud`. Do not wire new code to it.

## Battle scene architecture

The playable battle lives in `scenes/battle/battle_scene.tscn`.

### Node tree (BattleSession)
All battle logic nodes are siblings under `BattleSession`:

| Node | Role |
|------|------|
| `SelectionState` | Player selection and action mode |
| `TurnController` | Turn queue and phase changes |
| `CombatResolver` | Attack rules; emits combat signals |
| `BattleHud` | On-screen UI (bars, popups, panels) |
| `GridHighlights` | Tile highlight meshes |
| `UnitSpawner` | Instantiates units from `ClassData` |
| `BattleInput` | Mouse/keyboard → flow |
| `EnemyBrain` | Enemy turn execution |
| `BattleFlow` | Orchestrates battle; single entry for actions |
| `AudioManager` | SFX; reacts to signals only |

World (`%World`), UI canvas, and VFX sit outside `BattleSession` but are referenced via unique names.

### Wiring rules (required)

1. **`BattleFlow` bootstraps dependencies**  
   In `_bootstrap()`, `BattleFlow.setup(...)` receives every session service. Do not let sibling nodes call `get_parent().get_node("OtherSibling")` in `_ready()` to wire battle logic.

2. **Use `setup()` for cross-service links**  
   Pattern used by `BattleInput`, `EnemyBrain`, and `AudioManager`:
   ```gdscript
   func setup(p_battle_flow: BattleFlow, ...) -> void:
       battle_flow = p_battle_flow
       some_signal.connect(_handler)
   ```
   `BattleFlow.setup()` calls child `setup()` methods after storing references.

3. **Domain emits events; presentation subscribes**  
   - **Emit signals** from: `CombatResolver`, `TurnController`, `UnitBase`, and action signals on `BattleFlow` (e.g. `move_executed`).
   - **Subscribe** in presentation/services: `AudioManager` connects in `setup()`. `BattleHud` is updated by `BattleFlow` after actions (HUD stays imperative for now).
   - **Do not** call `audio_manager.play_*()` from `BattleFlow` or combat code. Add or reuse a signal instead.

4. **Register dynamic actors**  
   When `BattleFlow` spawns a unit, call `audio_manager.register_unit(unit)` so lifecycle signals (e.g. `UnitBase.died`) are connected.

5. **Action entry points live in `BattleFlow`**  
   Movement, attacks, and end turn go through `BattleFlow` (`execute_move`, `execute_attack`, `end_turn`). Input and AI call these, not raw tile/unit methods.

6. **Data in Resources**  
   Stats, weapons, encounters, and AI behaviors use `.tres` under `data/`. Avoid hardcoding balance in scripts.

### Signal map (battle feedback)

| Signal | Emitter | Typical listeners |
|--------|---------|-------------------|
| `attack_executed` | `CombatResolver` | `AudioManager` |
| `target_hit` | `CombatResolver` | `AudioManager` |
| `turn_ended` | `TurnController` | `AudioManager` |
| `move_executed` | `BattleFlow` | `AudioManager` |
| `died` | `UnitBase` | `AudioManager` (via `register_unit`) |
| `current_unit_changed` | `TurnController` | `BattleFlow`, `EnemyBrain` |

When adding new feedback (particles, screen shake, etc.), prefer a small service in `systems/` or `presentation/` that subscribes via `setup()` — same pattern as `AudioManager`.

### Enemy AI (modular)
- `EnemyBrain` runs a list of `AIIntent` (attack, move, wait, end turn).
- `EnemyBehavior.plan(context)` returns intents; swap via `EnemyBrain.default_behavior` or `ClassData.enemy_behavior`.
- `SimpleChaseBehavior` is the default. `DecisionTreeBehavior` + `DecisionNode` are stubs for custom trees later.

## Design
- Small scope
- Readability over realism
- Fast tactical combat
- Simple expandable systems

## Coding style
- Readable code over clever code
- Avoid overengineering
- Small focused scripts
- Separate logic from visuals
- Comments and identifiers in **English**
- Use `class_name` for types referenced across folders

## Checklist for new battle features

- [ ] Logic in the right folder (`battle/` vs `presentation/` vs `systems/`)
- [ ] Wired through `BattleFlow.setup()` if it needs other session nodes
- [ ] No sibling `get_node` wiring in `_ready()`
- [ ] Events exposed as signals if audio/UI/other systems should react
- [ ] New units registered with `audio_manager.register_unit` when spawned
- [ ] Content in `data/*.tres` when it is designer-tunable
