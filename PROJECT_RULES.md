# Project Rules

Read this before adding features. It defines folder layout, wiring, and patterns so humans and AI agents stay consistent.

## Technical
- Godot 4
- Hex axial coordinate system
- 3D environment with 2D billboard sprites (2.5D, Octopath-style)
- Data-driven gameplay using Resources
- **Composition-based architecture** — prefer composing small modules over large classes
- **Dependency injection** via `setup()` — no `get_node("/root/...")` in business logic

### Code layout
- `scripts/battle/` — flow, turns, combat rules, selection, input, AI
- `scripts/units/` — unit actor + composed modules (`UnitStats`, `UnitEffects`, `UnitEquipment`)
- `scripts/presentation/` — HUD, visual effects, tile highlights, UI components
- `scripts/systems/` — cross-cutting scene services (audio, passives, particles, spawner)
- `scripts/skills/` — skill system (executor, context, data)
- `scripts/data/` — Resource types (class, weapon, encounter, status effect)
- `scripts/components/` — scene components (e.g. hex tile, active status effect)
- `scripts/core/` — shared non-battle utilities (camera, config, main menu)
- `data/` — `.tres` content (classes, weapons, encounters, ai, skills)
- `scripts/battle/ai/` — modular enemy AI (`EnemyBehavior`, intents, decision tree stubs)
- `scripts/ui/` — pure UI widgets (panels, bars, stat modifiers)

### Unit architecture (composition)
`UnitBase` is a **facade** that composes three modules:
- `UnitStats` — HP, MOV, AP, defense, attack power, damage/heal/spend operations (RefCounted)
- `UnitEffects` — active status effects, modifiers, tick/stack management (RefCounted)
- `UnitEquipment` — primary/secondary weapons, slot switching, tags (RefCounted)

New unit features should be added to the appropriate module. If a feature doesn't fit, create a new module rather than bloating `UnitBase`.

### BattleHud architecture (facade)
`BattleHud` is a **facade** that coordinates sub-components. Each component lives in `scripts/presentation/`:

| Component | Responsibility |
|-----------|---------------|
| `ResourceDisplay` | MOV/AP labels |
| `HintDisplay` | Hint label + error feedback timer |
| `ActionNamePopup` | Centered action name popup with fade |
| `HpBarManager` | HP bar creation and per-frame updates |
| `TurnOrderUI` | Turn order bar items |
| `DamagePopupManager` | Floating damage/heal/buff/debuff popups |
| `ActionSubmenuUI` | Weapon + skill action buttons |

Do not add logic directly to `BattleHud` — add it to the appropriate sub-component or create a new one.

### Visual effects
Visual effects are extracted into dedicated classes in `scripts/presentation/`:
- `AttackLineEffect` — line between attacker and target
- `ImpactEffect` — expanding ring at impact point
- `TileFlashEffect` — red flash on invalid move tile
- `CameraService` — focus camera on a unit
- `CinematicPlayer` — attack/skill cinematic sequences

These are created at runtime in `BattleFlow._bootstrap()` (not placed in the `.tscn`).

### Unit visuals (2.5D)
- Units use `MeshInstance3D` + `QuadMesh` with `StandardMaterial3D` and `BILLBOARD_FIXED_Y` (see `scenes/units/unit_base.tscn` + `UnitSpriteVisual`). No shader — `StandardMaterial3D.albedo_texture` receives each animation frame directly.
- `UnitBase.configure_from_grid(GridConfig)` syncs foot height to hex surface. `play_attack_visual()` plays one-shot `transform` then returns to `idle`.
- Placeholder sheets: `assets/sprites/units/placeholder/Gr1_*.png` (80×80 frames). Built at runtime via `Gr1PlaceholderFrames` (`idle`, `idle_powered`, `transform`, `revert`, `full`).
- Team outline removed temporarily (caused gray-square regression). Outline shader (`shaders/unit_sprite.gdshader`) and `use_outline_shader` export variable still exist for future re-enable when the Sprite3D→ShaderMaterial texture binding is resolved.
- Per-class sprites later: assign a `SpriteFrames` on `UnitVisual` from `ClassData`, or call `UnitSpriteVisual.play("animation_name")`.

### Grid (hex)
- `GridConfig` (`data/grid/default_grid_config.tres`) — `hex_size`, `mesh_radius`, `mesh_height`, `grid_radius`, shared tile/overlay colors.
- `HexMath` (`scripts/grid/hex_math.gd`) — axial distance, `axial_to_world`, `world_to_axial`. Use instead of duplicating formulas.
- `GridManager.initialize(encounter)` — called from `BattleFlow.start_battle()` before spawning units. `EncounterData.grid_radius` overrides config when `> 0`.
- `HexTile` — base mesh uses config materials; move/attack ranges use `HighlightOverlay` (do not swap base material for ranges).
- Do not add a ground `PlaneMesh` under the grid; tiles are the play surface.
- `GridPathPreview` (`World/GridPathPreview`) draws move path in MOVE mode. `MovementRules.find_path()` for BFS path.
- Invalid player actions show feedback via `BattleHud.show_action_feedback()`. Move/Attack modes reset to Idle after a successful action.

## Wiring rules (required)

### 1. `BattleFlow` bootstraps all dependencies
In `_bootstrap()`, `BattleFlow.setup(...)` receives every session service and calls `setup()` on each. **Do not** let sibling nodes call `get_parent().get_node("OtherSibling")` in `_ready()`.

### 2. Use `setup()` for cross-service links
```gdscript
func setup(p_battle_flow: BattleFlow, ...) -> void:
    battle_flow = p_battle_flow
    some_signal.connect(_handler)
```
`BattleFlow.setup()` calls child `setup()` methods after storing references.

### 3. Inject dependencies into all nodes
Every node that needs external services (audio, HUD, grid, camera) must receive them via `setup()`:
- `BattleHud.setup(selection, turn_controller, units_container, audio, camera)`
- `UnitBase.setup(audio, hud, selection)` — called by `UnitSpawner`
- `UnitSpawner.setup(audio, hud, selection)`
- `SkillExecutor.setup(particle, hud, audio, grid)`
- `BattleInput.setup(battle_flow, selection, grid, turn_controller, audio)`
- `PassiveService.setup(grid_manager)`

### 4. Domain emits events; presentation subscribes
- **Emit signals** from: `CombatResolver`, `TurnController`, `UnitBase`, and action signals on `BattleFlow` (e.g. `move_executed`).
- **Subscribe** in presentation/services: `AudioManager` connects in `setup()`. `BattleHud` is updated by `BattleFlow` after actions (HUD stays imperative for now).
- **Do not** call `audio_manager.play_*()` from `BattleFlow` or combat code. Add or reuse a signal instead.

### 5. Register dynamic actors
When `BattleFlow` spawns a unit, call `audio_manager.register_unit(unit)` so lifecycle signals (e.g. `UnitBase.died`) are connected.

### 6. Action entry points live in `BattleFlow`
Movement, attacks, and end turn go through `BattleFlow` (`execute_move`, `execute_attack`, `end_turn`). Input and AI call these, not raw tile/unit methods.

### 7. Data in Resources
Stats, weapons, encounters, and AI behaviors use `.tres` under `data/`. Avoid hardcoding balance in scripts.

### 8. Visual effects created at runtime
Visual effects (`AttackLineEffect`, `ImpactEffect`, `TileFlashEffect`, `CameraService`) are instantiated in `BattleFlow._bootstrap()` — they do **not** need to be placed in the `.tscn` file.

## Battle scene architecture

The playable battle lives in `scenes/battle/battle_scene.tscn`.

### Node tree (BattleSession)
All battle logic nodes are siblings under `BattleSession`:

| Node | Role |
|------|------|
| `SelectionState` | Player selection and action mode |
| `TurnController` | Turn queue and phase changes |
| `CombatResolver` | Attack rules; emits combat signals |
| `BattleHud` | UI facade (coordinates 7 sub-components) |
| `GridHighlights` | Tile highlight meshes |
| `UnitSpawner` | Instantiates units + injects dependencies |
| `BattleInput` | Mouse/keyboard → flow |
| `EnemyBrain` | Enemy turn execution |
| `BattleFlow` | Orchestrates battle; single entry for actions |
| `AudioManager` | SFX; reacts to signals only |
| `SkillExecutor` | Executes skills |
| `ParticleManager` | Particle effects |
| `CinematicPlayer` | Attack/skill cinematic sequences |
| `PassiveService` | (optional) Passive evaluation service |

World (`%World`), UI canvas (`UI/CanvasLayer`), and VFX sit outside `BattleSession`.

### Signal map (battle feedback)

| Signal | Emitter | Typical listeners |
|--------|---------|-------------------|
| `attack_executed` | `CombatResolver` | `AudioManager` |
| `target_hit` | `CombatResolver` | `AudioManager` |
| `turn_ended` | `TurnController` | `AudioManager` |
| `move_executed` | `BattleFlow` | `AudioManager` |
| `died` | `UnitBase` | `AudioManager` (via `register_unit`) |
| `current_unit_changed` | `TurnController` | `BattleFlow`, `EnemyBrain` |
| `action_mode_changed` | `SelectionState` | `BattleHud` |
| `hovered_unit_changed` | `SelectionState` | `BattleHud` |
| `unit_selected` | `SelectionState` | `GridHighlights` |

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
- Small focused scripts (< 300 lines ideal, < 500 hard limit)
- Separate logic from visuals
- Comments and identifiers in **English**
- Use `class_name` for types referenced across folders
- Use `setup()` pattern for dependency injection
- Prefer composition over inheritance
- Use `RefCounted` for data-only modules (no scene tree needed)

## Checklist for new battle features

- [ ] Logic in the right folder (`battle/` vs `presentation/` vs `systems/`)
- [ ] Wired through `BattleFlow.setup()` if it needs other session nodes
- [ ] No `get_node("/root/...")` or sibling `get_node` in `_ready()`
- [ ] Events exposed as signals if audio/UI/other systems should react
- [ ] New units registered with `audio_manager.register_unit` when spawned
- [ ] Content in `data/*.tres` when it is designer-tunable
- [ ] Visual effects in `presentation/`, created at runtime (not in `.tscn`)
- [ ] If adding new unit stats or equipment logic, extend `UnitStats`/`UnitEquipment` (not `UnitBase`)
- [ ] If adding new UI element, create a sub-component in `presentation/` (not in `BattleHud`)