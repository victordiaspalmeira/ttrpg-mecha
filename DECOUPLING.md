# DECOUPLING.md — Plano de Reestruturação do TTRPG-MECHA

> **Propósito**: Documentar o plano completo de refatoração para tornar o código mais modular, manutenível e didático. Este documento serve como guia e checklist para a reestruturação.

---

## Sumário

1. [Diagnóstico: O Que Está Ruim Hoje](#1-diagnóstico-o-que-está-ruim-hoje)
2. [Filosofia da Reestruturação](#2-filosofia-da-reestruturação)
3. [Fase 0: Fundação — Eliminar Acoplamento Hardcoded](#3-fase-0-fundação--eliminar-acoplamento-hardcoded)
4. [Fase 1: Extrair Lógica Visual do BattleFlow](#4-fase-1-extrair-lógica-visual-do-battleflow)
5. [Fase 2: Extrair Sistema de Gerenciamento de Unidade](#5-fase-2-extrair-sistema-de-gerenciamento-de-unidade)
6. [Fase 3: Extrair BattleHud em Componentes Menores](#6-fase-3-extrair-battlehud-em-componentes-menores)
7. [Fase 4: Refatorar PassiveSystem](#7-fase-4-refatorar-passivesystem)
8. [Fase 5: Remover Legacy](#8-fase-5-remover-legacy)
9. [Fase 6: Padronizar Timings e Estilos](#9-fase-6-padronizar-timings-e-estilos)
10. [Nova Estrutura de Pastas (Final)](#10-nova-estrutura-de-pastas-final)
11. [Estratégia de Migração](#11-estratégia-de-migração)
12. [Boas Práticas Aprendidas](#12-boas-práticas-aprendidas)

---

## 1. Diagnóstico: O Que Está Ruim Hoje

### 🔴 Problemas Críticos

| # | Problema | Arquivos | Impacto |
|---|----------|----------|---------|
| 1 | **God Objects** — classes com 500+ linhas fazendo múltiplas responsabilidades | `BattleHud` (601 linhas), `BattleFlow` (557 linhas), `UnitBase` (601 linhas) | Viola SRP (Single Responsibility Principle). Dificulta leitura, teste e modificação. Uma mudança no popup de dano pode quebrar lógica de turno. |
| 2 | **Acoplamento rígido via path absoluto** — nós usam `/root/BattleScene/...` para acessar siblings | `BattleHud` (linhas 54-56, 63-65, 151), `UnitBase` (linhas 265, 270, 372-377), `SkillExecutor` (linhas 198, 325-326), `PassiveSystem` (linha 251) | Se a node tree mudar (ex: mudar nome de `BattleSession`), tudo quebra em runtime sem warning do compilador. |
| 3 | **Dependências ocultas em runtime** — `_get_audio_manager()`, `_get_battle_hud()` são chamados em momentos imprevisíveis | `UnitBase.die()` linha 249, `SkillExecutor.execute()` linha 59 | Cria acoplamento invisível entre módulos. Se `AudioManager` não existir, o jogo não crasha na cena mas sim no meio de uma skill. |
| 4 | **PassiveSystem como estático global** — RefCounted com métodos estáticos + callback global `feedback_callback` | `PassiveSystem` inteiro (251 linhas), referenciado em `BattleFlow` linha 264 e `UnitBase` linhas 150, 218, 226 | Estado global dificulta raciocínio: qualquer código pode chamar `trigger_event()` e modificar estado sem aviso. |
| 5 | **Lógica visual misturada com domínio** — `BattleFlow` cria meshes direto | `BattleFlow._show_attack_line()` (linhas 318-348), `_show_impact_effect()` (linhas 451-476), `_flash_tile_red()` (linhas 480-499) | Viola separação core/presentation. Se mudar o visual (ex: de mesh para sprite), precisa alterar lógica de batalha. |

### 🟡 Problemas Moderados

| # | Problema | Detalhes |
|---|----------|----------|
| 6 | `BattleHud` faz absolutamente tudo — HP bars, popups, submenu de ações, câmera, áudio, labels de recursos | Mais de 10 responsabilidades distintas. Qualquer bug de UI exige navegar 600 linhas. |
| 7 | `StatModifier` vive em `scripts/ui/` mas é usado por `UnitBase` em `scripts/units/` | Acoplamento inverso: um módulo de baixo nível (units) depende de um módulo de UI. |
| 8 | Duplicação de lógica entre `BattleFlow.execute_attack()` e `SkillExecutor.execute()` | Ambos fazem validação de alvo, aplicação de dano, disparo de partículas. Se uma regra muda, precisa atualizar dois lugares. |
| 9 | `ui_system.gd` existe mas é marcado como legacy | Ruído mental. O que não é usado deve ser removido. |
| 10 | Português e Inglês misturados em alguns lugares | `BattleFlow._finish_battle()` linha 430 usa "VICTORY"/"DEFEAT" em Português no código. Comentários em português também. |
| 11 | `battle_input.gd` linha 37: `move_button.pressed.connect()` crasha porque `move_button` nunca é atribuído | Falta `move_button = %MoveButton` — variável declarada mas nunca inicializada. Bug silencioso que só aparece ao iniciar batalha. |

### 🟢 O Que Já Está Bom e Deve Preservar

| Aspecto | Por que é bom |
|---------|---------------|
| **Arquitetura BattleSession** com nós irmãos | Cada serviço é independente, facilita teste e substituição |
| **Wiring via `setup()`** no BattleFlow | Injeção de dependência explícita — um dos melhores padrões do projeto |
| **Sistema de sinais** para eventos de domínio | `attack_executed`, `target_hit`, `died` — baixo acoplamento entre emissor e ouvinte |
| **Data-driven com Resources** | `ClassData`, `WeaponData`, `EncounterData` em `.tres` — balanceamento sem código |
| **Grid hexagonal bem isolado** | `GridManager` + `HexMath` com API limpa |
| **Separação AI** | `EnemyBrain` + `AIIntent` + `EnemyBehavior` — extensível sem tocar no resto |
| **PROJECT_RULES.md** | Documentação viva que define padrões |

---

## 2. Filosofia da Reestruturação

### Princípios Norteadores

1. **Pequenos módulos com uma responsabilidade** — cada script deve caber na cabeça de uma pessoa
2. **Injeção de dependência explícita** — `setup(p_audio, p_grid)` em vez de `get_node("/root/BattleScene/AudioManager")`
3. **Separação domínio vs apresentação** — scripts em `battle/` não sabem que existem meshes ou cores
4. **Composição sobre herança** — `UnitBase` compõe `UnitStats` + `UnitEffects` + `UnitEquipment` em vez de fazer tudo
5. **Migração incremental** — cada fase produz código compilável e rodável

### Padrão de Dependência

```
battle/  ──→  systems/  ──→  data/
   │                 │
   │                 └──→  audio_manager, passive_service
   │
   └──→  presentation/  (via sinais, não chamadas diretas)
```

- `battle/` nunca importa de `presentation/`
- `presentation/` escuta sinais de `battle/`
- `data/` é a camada mais baixa (sem dependências)
- `systems/` é a cola entre os mundos

---

## 3. Fase 0: Fundação — Eliminar Acoplamento Hardcoded

**Objetivo**: Nenhum `get_node("/root/BattleScene/...")` ou `_get_audio_manager()` deve existir no código final.

### 3.1 Identificar todas as ocorrências

Antes de refatorar, mapear todos os pontos de acoplamento hardcoded:

**Arquivo: `BattleHud.gd`**
```gdscript
# ❌ RUIM: Path absoluto, quebra se mudar a cena
var session := get_node("/root/BattleScene/BattleSession")
var ui_layer := get_node("/root/BattleScene/UI/CanvasLayer")
var world := get_node("/root/BattleScene/World")
var cam_rig := get_node("/root/BattleScene/World/CameraRig")

# ✅ BOM: Receber via setup() ou @export
var session: Node
var ui_layer: CanvasLayer
var world: Node3D
var cam_rig: Node3D

func setup(p_session: Node, p_ui: CanvasLayer, p_world: Node3D) -> void:
    session = p_session
    ui_layer = p_ui
    world = p_world
    cam_rig = p_world.get_node("CameraRig")
```

**Arquivo: `UnitBase.gd`** — 4 métodos de busca hardcoded:
```gdscript
# ❌ RUIM: Busca em runtime, frágil
func _get_audio_manager() -> AudioManager:
    var scene_root: Node = get_tree().current_scene
    return scene_root.get_node_or_null("BattleSession/AudioManager") as AudioManager

func _get_battle_hud() -> BattleHud:
    var scene_root: Node = get_tree().current_scene
    return scene_root.get_node_or_null("BattleSession/BattleHud") as BattleHud

func _get_hovered_unit() -> UnitBase:
    var selection_state := current_scene.get_node_or_null("BattleSession/SelectionState")
    ...
    return selection_state.get("hovered_unit") as UnitBase

# ✅ BOM: Referências injetadas
var audio_manager: AudioManager
var battle_hud: BattleHud
var selection_state: SelectionState

func setup(p_audio: AudioManager, p_hud: BattleHud, p_selection: SelectionState) -> void:
    audio_manager = p_audio
    battle_hud = p_hud
    selection_state = p_selection
```

**Arquivo: `SkillExecutor.gd`** — 3 métodos de busca hardcoded:
```gdscript
# ❌ RUIM
func _get_particle_manager(unit) -> ParticleManager:
    return session.get_node_or_null("ParticleManager") as ParticleManager

func _get_battle_hud(unit) -> BattleHud:
    return scene_root.get_node_or_null("BattleSession/BattleHud") as BattleHud

func _get_audio_manager(unit) -> AudioManager:
    return scene_root.get_node_or_null("BattleSession/AudioManager") as AudioManager

# ✅ BOM
var particle_manager: ParticleManager
var battle_hud: BattleHud
var audio_manager: AudioManager

func setup(p_particle: ParticleManager, p_hud: BattleHud, p_audio: AudioManager) -> void:
    particle_manager = p_particle
    battle_hud = p_hud
    audio_manager = p_audio
```

**Arquivo: `PassiveSystem.gd`** — 1 método hardcoded + callback global:
```gdscript
# ❌ RUIM: Estático e busca GridManager em runtime
static func _get_grid_manager(unit: UnitBase) -> Node:
    return scene.get_node_or_null("World/GridManager")

# ✅ BOM: Receber GridManager como parâmetro
static func _count_enemies_nearby(unit: UnitBase, grid: GridManager) -> int:
    # usa grid diretamente
```

### 3.2 Checklist da Fase 0

### 3.3 Checklist da Fase 0

- [ ] `BattleFlow.setup()` agora injeta dependências em TODOS os nós, não só em BattleInput/EnemyBrain/AudioManager
- [ ] `UnitBase` recebe `setup(p_audio, p_hud, p_selection)`
- [ ] `SkillExecutor` recebe `setup(p_particle, p_hud, p_audio)`
- [ ] `BattleHud` recebe `setup(p_session, p_ui, p_world)` em vez de paths absolutos
- [ ] `PassiveSystem._count_enemies_nearby(unit, grid)` recebe GridManager como parâmetro
- [ ] Nenhum `get_node("/root/...")` existe nos scripts
- [ ] Nenhum `_get_audio_manager()`, `_get_battle_hud()` existe
- [ ] **Corrigir bug**: `battle_input.gd` — adicionar `move_button = %MoveButton` na linha 36 (após `end_turn_button = %EndTurnButton`)
- [ ] Jogo roda e batalha funciona normalmente

---

## 4. Fase 1: Extrair Lógica Visual do BattleFlow

**Objetivo**: `BattleFlow` contém apenas orquestração de batalha. Tudo que cria Mesh ou animação vai para `presentation/`.

### 4.1 O que extrair

**AttackLineEffect** (novo arquivo: `scripts/presentation/attack_line_effect.gd`)
```gdscript
class_name AttackLineEffect
extends Node3D

func show_attack_line(from: Vector3, to: Vector3, world: Node3D) -> void:
    # Cria mesh de linha entre dois pontos com fade out
    # Antes estava em BattleFlow._show_attack_line() (linhas 318-348)
```

**ImpactEffect** (novo arquivo: `scripts/presentation/impact_effect.gd`)
```gdscript
class_name ImpactEffect
extends Node3D

func play_impact(at: Vector3, world: Node3D) -> void:
    # Cria anel expansivo com fade
    # Antes estava em BattleFlow._show_impact_effect() (linhas 451-476)
```

**TileFlashEffect** (novo arquivo: `scripts/presentation/tile_flash_effect.gd`)
```gdscript
class_name TileFlashEffect
extends Node

func flash_tile_red(tile: HexTile) -> void:
    # Pisca tile vermelho
    # Antes estava em BattleFlow._flash_tile_red() (linhas 480-499)
```

**CameraService** (novo arquivo: `scripts/presentation/camera_service.gd`)
```gdscript
class_name CameraService
extends Node

func focus_on_unit(unit: UnitBase, camera_rig: Node3D) -> void:
    # Foca câmera na unidade
    # Antes estava em BattleFlow._camera_look_at() (linhas 442-448)
```

### 4.2 BattleFlow refatorado

```gdscript
# Antes: 557 linhas com lógica visual misturada
# Depois: ~350 linhas só de orquestração

class_name BattleFlow
extends Node

# Injeta serviços visuais via setup()
var attack_line_effect: AttackLineEffect
var impact_effect: ImpactEffect
var tile_flash: TileFlashEffect
var camera_service: CameraService

func setup(
    # ... parâmetros existentes +
    p_attack_line: AttackLineEffect = null,
    p_impact: ImpactEffect = null,
    p_tile_flash: TileFlashEffect = null,
    p_camera: CameraService = null
) -> void:
    attack_line_effect = p_attack_line
    impact_effect = p_impact
    tile_flash = p_tile_flash
    camera_service = p_camera

# Métodos visuais delegam:
# _show_attack_line() → attack_line_effect.show_attack_line()
# _show_impact_effect() → impact_effect.play_impact()
# _flash_tile_red() → tile_flash.flash_tile_red()
# _camera_look_at() → camera_service.focus_on_unit()
```

### 4.3 Checklist da Fase 1

- [ ] `AttackLineEffect` criado e funcional
- [ ] `ImpactEffect` criado e funcional
- [ ] `TileFlashEffect` criado e funcional
- [ ] `CameraService` criado e funcional
- [ ] `BattleFlow._show_attack_line()` removido (delega)
- [ ] `BattleFlow._show_impact_effect()` removido
- [ ] `BattleFlow._flash_tile_red()` removido
- [ ] `BattleFlow._camera_look_at()` removido
- [ ] BattleFlow perdeu ~200 linhas
- [ ] Jogo roda e batalha funciona com os mesmos efeitos visuais

---

## 5. Fase 2: Extrair Sistema de Gerenciamento de Unidade

**Objetivo**: `UnitBase` vira uma fachada que compõe módulos especializados.

### 5.1 Novo: UnitStats

`scripts/units/unit_stats.gd`
```gdscript
class_name UnitStats
extends Resource  # ou Node

var max_hp: int = 0
var current_hp: int = 0
var max_movement: int = 0
var current_movement: int = 0
var max_ap: int = 0
var current_ap: int = 0
var defense: int = 0
var attack_power: int = 0

func take_damage(amount: int, effective_defense: int) -> int:
    var final := maxi(1, amount - effective_defense)
    current_hp -= final
    return final

func heal(amount: int) -> void:
    current_hp = mini(max_hp, current_hp + amount)

func can_spend_ap(amount: int) -> bool:
    return amount > 0 and current_ap >= amount

func spend_ap(amount: int) -> bool:
    if not can_spend_ap(amount):
        return false
    current_ap -= amount
    return true

func can_spend_movement(amount: int) -> bool:
    return amount > 0 and current_movement >= amount

func spend_movement(amount: int) -> bool:
    if not can_spend_movement(amount):
        return false
    current_movement -= amount
    return true
```

### 5.2 Novo: UnitEffects

`scripts/units/unit_effects.gd`
```gdscript
class_name UnitEffects
extends Node

var active_effects: Array[ActiveStatusEffect] = []

func add_effect(effect_data: StatusEffect, source: String = "") -> ActiveStatusEffect:
    # Refresh se já existe, senão adiciona novo
    ...

func remove_effect(effect_id: String) -> void:
    ...

func has_effect(effect_id: String) -> bool:
    ...

func tick_effects() -> void:
    # Decrementa duração, remove expirados
    ...

func get_modifier(stat: String) -> int:
    # Soma modificadores de todos os efeitos ativos
    var total := 0
    for e in active_effects:
        total += e.get_modifier(stat)
    return total
```

### 5.3 Novo: UnitEquipment

`scripts/units/unit_equipment.gd`
```gdscript
class_name UnitEquipment
extends Node

var primary_weapon: WeaponData
var secondary_weapon: WeaponData
var active_weapon_slot := "primary"

func get_active_weapon() -> WeaponData:
    if active_weapon_slot == "primary" and primary_weapon:
        return primary_weapon
    if active_weapon_slot == "secondary" and secondary_weapon:
        return secondary_weapon
    return primary_weapon

func switch_weapon() -> void:
    if secondary_weapon:
        active_weapon_slot = "secondary" if active_weapon_slot == "primary" else "primary"

func get_attack_ap_cost() -> int:
    var weapon := get_active_weapon()
    return maxi(1, weapon.attack_ap_cost if weapon else 1)
```

### 5.4 UnitBase Refatorado

```gdscript
class_name UnitBase
extends Node3D

@export var stats: UnitStats
@export var effects: UnitEffects
@export var equipment: UnitEquipment

var unit_name := ""
var class_id := ""
var team_id := "player"
var class_data: ClassData
var team_data: TeamData
var current_tile: HexTile

# Injetado via setup()
var audio_manager: AudioManager
var battle_hud: BattleHud
var selection_state: SelectionState

func setup(p_audio: AudioManager, p_hud: BattleHud, p_selection: SelectionState) -> void:
    audio_manager = p_audio
    battle_hud = p_hud
    selection_state = p_selection

func refresh_turn() -> void:
    effects.tick_effects()
    stats.current_movement = get_effective_movement()
    stats.current_ap = get_effective_max_ap()
    reduce_cooldowns()

func take_damage(amount: int) -> void:
    var resistance := PassiveSystem.get_damage_resistance(self)
    var effective_defense := maxi(1, defense + effects.get_modifier("defense") + resistance)
    var final_damage = stats.take_damage(amount, effective_defense)
    
    PassiveSystem.trigger_event(PassiveEvent.ON_DAMAGE_TAKEN, self, {"damage": final_damage})
    
    # Visual feedback (ainda pode ficar aqui pois é reação visual da unidade)
    _unit_visual.flash_white()
    _unit_visual.shake()
    
    if stats.current_hp <= 0:
        die()

# Delegation methods
func get_active_weapon() -> WeaponData:
    return equipment.get_active_weapon()

func add_effect(effect_data: StatusEffect, source: String = "") -> ActiveStatusEffect:
    return effects.add_effect(effect_data, source)

# etc...
```

### 5.5 Checklist da Fase 2

- [ ] `UnitStats` criado com toda lógica de stats
- [ ] `UnitEffects` criado com toda lógica de efeitos
- [ ] `UnitEquipment` criado com toda lógica de armas
- [ ] `UnitBase` refatorado para compor os três módulos
- [ ] Métodos de breakdown movidos para presentation (não são responsabilidade da unidade)
- [ ] `UnitBase` perdeu ~300 linhas
- [ ] Todas as referências externas a `UnitBase.stats`, `.effects`, `.equipment` funcionam
- [ ] Jogo roda e batalha funciona

---

## 6. Fase 3: Extrair BattleHud em Componentes Menores

**Objetivo**: `BattleHud` de 601 linhas vira fachada de ~80 linhas que coordena componentes especializados.

### 6.1 Componentes a Criar

Cada um em `scripts/presentation/`:

| Componente | Responsabilidade | Métodos Principais |
|------------|-----------------|-------------------|
| `HpBarManager` | Criar e atualizar HP bars das unidades | `create_hp_bars(units_container)`, `update_hp_bars()`, `_on_unit_spawned()` |
| `TurnOrderUI` | Visual da ordem de turno | `create_turn_order(units_container)`, `highlight_turn_order(active_unit)` |
| `DamagePopupManager` | Popups de dano/cura/buff/debuff/morte | `show_popup(unit, amount, type)`, `show_popup_at_position(world_pos, amount, type)` |
| `ActionSubmenuUI` | Menu de ações (armas + skills) | `show(unit)`, `hide()`, `_on_weapon_selected()`, `_on_skill_selected()` |
| `ActionNamePopup` | Popup de nome de ação | `show(action_name, duration)` |
| `HintDisplay` | Label de hint + feedback | `show_hint(text)`, `show_error(text, duration)`, `restore_default()` |
| `ResourceDisplay` | Labels MOV/AP | `update(unit)` |

### 6.2 BattleHud Refatorado

```gdscript
class_name BattleHud
extends Node

@export var hp_bar_manager: HpBarManager
@export var turn_order_ui: TurnOrderUI
@export var damage_popup_manager: DamagePopupManager
@export var action_submenu_ui: ActionSubmenuUI
@export var action_name_popup: ActionNamePopup
@export var hint_display: HintDisplay
@export var resource_display: ResourceDisplay

func setup(p_session: Node, p_ui: CanvasLayer, p_world: Node3D,
           p_camera: Camera3D, p_selection: SelectionState, p_turn_controller: TurnController) -> void:
    # Inicializa todos os componentes com suas referências
    hp_bar_manager.setup(p_world.get_node("Units"), p_camera)
    turn_order_ui.setup(p_world.get_node("Units"))
    damage_popup_manager.setup(p_camera)
    resource_display.setup(p_ui)
    hint_display.setup(p_ui)
    
    # Conecta sinais
    p_selection.action_mode_changed.connect(_on_action_mode_changed)
    p_selection.hovered_unit_changed.connect(_on_hovered_unit_changed)
    p_selection.pinned_unit_changed.connect(_on_pinned_unit_changed)

func present_turn_start(unit: UnitBase) -> void:
    # Agora delega em vez de fazer
    resource_display.update(unit)
    turn_order_ui.highlight_turn_order(unit)
    hp_bar_manager.update_hp_bars()
    ...

func show_damage_popup(unit: UnitBase, amount: int, popup_type: String = "damage") -> void:
    damage_popup_manager.show_popup(unit, amount, popup_type)

func update_resource_display(unit: UnitBase) -> void:
    resource_display.update(unit)

func show_action_feedback(message: String, duration := 2.2) -> void:
    hint_display.show_error(message, duration)
```

### 6.3 Checklist da Fase 3

- [ ] `HpBarManager` criado com lógica de HP bars
- [ ] `TurnOrderUI` criado com lógica de ordem de turno
- [ ] `DamagePopupManager` criado com lógica de popups
- [ ] `ActionSubmenuUI` criado com lógica de submenu
- [ ] `ActionNamePopup` criado com lógica de popup de nome
- [ ] `HintDisplay` criado com lógica de hint
- [ ] `ResourceDisplay` criado com lógica de labels MOV/AP
- [ ] BattleHud refatorado para fachada de ~80 linhas
- [ ] Todos os métodos públicos de BattleHud ainda funcionam
- [ ] Jogo roda e UI funciona normalmente

---

## 7. Fase 4: Refatorar PassiveSystem

**Objetivo**: Deixar de ser um sistema estático global para ser um serviço injetável.

### 7.1 Problemas do PassiveSystem Atual

```gdscript
# ❌ RUIM: Vários problemas estruturais

# 1. É estático — qualquer código pode chamar e modificar estado global
static func trigger_event(event, unit, context, extra_passives = []) -> Dictionary:
    ...

# 2. Callback global — frágil e escondido
static var feedback_callback: Callable = func(_u, _t, _c): pass

# 3. Busca GridManager em runtime com path absoluto
static func _get_grid_manager(unit: UnitBase) -> Node:
    return scene.get_node_or_null("World/GridManager")

# 4. Mistura responsabilidades: evento + condicional + dano + range
static func get_conditional_range(unit) -> int: ...
static func get_damage_multiplier(unit) -> int: ...
static func consume_damage_multiplier(unit) -> void: ...
static func get_total_bonus(unit, stat, ctx) -> int: ...
```

### 7.2 Novo: PassiveService

`scripts/systems/passive_service.gd`
```gdscript
class_name PassiveService
extends Node

signal passive_triggered(unit: UnitBase, text: String, color: Color)

var grid_manager: GridManager

func setup(p_grid_manager: GridManager) -> void:
    grid_manager = p_grid_manager

func trigger_event(
    event: PassiveEvent,
    unit: UnitBase,
    context: Dictionary = {},
    extra_passives: Array[PassiveEffect] = []
) -> Dictionary:
    # Lógica do evento, mas não estática
    for passive in _get_all_passives(unit, extra_passives):
        match passive.passive_type:
            PassiveEffect.PassiveType.ON_KILL:
                if event == PassiveEvent.ON_KILL:
                    ...
                    passive_triggered.emit(unit, passive.display_name, Color(1.0, 0.8, 0.3))
    ...

func _count_enemies_nearby(unit: UnitBase) -> int:
    # Agora usa grid_manager diretamente, sem buscar em runtime
    ...
```

### 7.3 Mudanças nos Consumidores

```gdscript
# Antes: chamada estática
PassiveSystem.trigger_event(PassiveEvent.BEFORE_ATTACK, attacker, {"target": target})

# Depois: chamada via serviço injetado
passive_service.trigger_event(PassiveEvent.BEFORE_ATTACK, attacker, {"target": target})
```

### 7.4 Checklist da Fase 4

- [ ] `PassiveService` criado como Node (não RefCounted estático)
- [ ] `setup(grid_manager)` injeta GridManager
- [ ] Todos os métodos agora são de instância, não estáticos
- [ ] `feedback_callback` removido, substituído por `passive_triggered` signal
- [ ] `PassiveSystem` original removido
- [ ] `BattleFlow`, `UnitBase`, `SkillExecutor` atualizados para usar `PassiveService`
- [ ] Jogo roda e passivas funcionam (Close Quarters, Thick Skin, Eagle Eye, Volt Charge)

---

## 8. Fase 5: Remover Legacy

### 8.1 O que Remover

```gdscript
# Arquivo: scripts/systems/ui_system.gd
# Marcado como "Legacy (do not extend)" no PROJECT_RULES.md
# Não deve ser referenciado por ninguém
```

### 8.2 Checklist da Fase 5

- [ ] Verificar se algum código ainda referencia `ui_system`
- [ ] Remover referências (se houver)
- [ ] Deletar `scripts/systems/ui_system.gd`
- [ ] Deletar `scripts/systems/ui_system.gd.uid`
- [ ] Atualizar PROJECT_RULES.md removendo menção ao legacy

---

## 9. Fase 6: Padronizar Timings e Estilos

### 9.1 Criar Config Central

`scripts/core/battle_config.gd` (novo)
```gdscript
extends RefCounted

## Configurações de timing e balanceamento visual
const MOVEMENT_TWEEN_DURATION := 0.3
const POPUP_DURATION_DAMAGE := 0.4
const POPUP_DURATION_SKILL_NAME := 1.2
const TILE_FLASH_DURATION := 0.4
const ATTACK_LINE_DURATION := 0.3
const FEEDBACK_DURATION := 2.2
const DEATH_ANIMATION_DURATION := 0.5
```

### 9.2 Remover Duplicação de Popups

BattleHud tem dois métodos quase idênticos:
```gdscript
# ❌ RUIM: Duplicação de ~40 linhas
func show_damage_popup(unit, amount, popup_type) -> void: ...
func show_damage_popup_at_position(world_position, amount, popup_type) -> void: ...

# ✅ BOM: Método único que aceita position
func show_damage_popup(
    position_source,  # UnitBase ou Vector3
    amount: int,
    popup_type: String = "damage"
) -> void:
    var world_pos: Vector3
    if position_source is UnitBase:
        world_pos = position_source.global_position + Vector3.UP * position_source.get_visual_top_y()
    else:
        world_pos = position_source + Vector3.UP * 1.5
    
    var screen_pos := _camera.unproject_position(world_pos + Vector3.UP * 0.25)
    # ... resto igual
```

### 9.3 Checklist da Fase 6

- [ ] `scripts/core/battle_config.gd` criado com constantes
- [ ] `movement_tween_duration` em `UnitBase` usa a config
- [ ] Durações de popup usam a config
- [ ] `show_damage_popup()` unificado
- [ ] `show_damage_popup_at_position()` removido
- [ ] Nenhum timing hardcoded mágico

---

## 10. Nova Estrutura de Pastas (Final)

```
scripts/
├── battle/                       # Orquestração de batalha pura (sem visual)
│   ├── battle_flow.gd            # Fachada da batalha (~350 linhas)
│   ├── battle_input.gd           # Input do jogador
│   ├── combat_resolver.gd        # Regras de combate
│   ├── enemy_brain.gd            # IA inimiga
│   ├── movement_rules.gd         # Regras de movimento
│   ├── selection_state.gd        # Estado de seleção
│   ├── turn_controller.gd        # Gerenciamento de turnos
│   └── ai/                       # Comportamentos de IA
│
├── units/                        # Composição de componentes de unidade
│   ├── unit_base.gd              # Fachada (~250 linhas)
│   ├── unit_stats.gd             # Stats e modificadores
│   ├── unit_effects.gd           # Gerenciamento de status effects
│   ├── unit_equipment.gd         # Gerenciamento de armas
│   ├── unit_combat.gd            # Cálculo de dano/ataque (opcional)
│   ├── unit_sprite_visual.gd     # Visual 2.5D (não mexe)
│   └── gr1_placeholder_frames.gd # Frames placeholder (não mexe)
│
├── presentation/                 # Tudo que é visual/UI
│   ├── battle_hud.gd             # Fachada da UI (~80 linhas)
│   ├── hp_bar_manager.gd         # Gerenciamento de HP bars       ← NOVO
│   ├── turn_order_ui.gd          # Ordem de turno visual           ← NOVO
│   ├── damage_popup_manager.gd   # Popups de dano/cura            ← NOVO
│   ├── action_submenu_ui.gd      # Menu de ações                  ← NOVO
│   ├── action_name_popup.gd      # Popup de nome de ação          ← NOVO
│   ├── hint_display.gd           # Label de hint                  ← NOVO
│   ├── resource_display.gd       # Labels MOV/AP                  ← NOVO
│   ├── attack_line_effect.gd     # Linha visual de ataque         ← NOVO
│   ├── impact_effect.gd          # Efeito de impacto              ← NOVO
│   ├── tile_flash_effect.gd      # Flash de tile                  ← NOVO
│   ├── camera_service.gd         # Serviço de câmera              ← NOVO
│   ├── cinematic_player.gd       # Cutscene de batalha
│   ├── grid_highlights.gd        # Highlights de tiles
│   ├── grid_path_preview.gd      # Preview de path
│   ├── passive_feedback.gd       # Feedback visual de passivas
│   ├── turn_announce.gd          # Anúncio de turno
│   └── turn_order_item.gd        # Item individual de ordem
│
├── systems/                      # Serviços cross-cutting
│   ├── audio_manager.gd          # Gerenciamento de áudio
│   ├── passive_service.gd        # Sistema de passivas     ← REFATORADO (não estático)
│   ├── particle_manager.gd       # Gerenciamento de partículas
│   ├── particle_config.gd        # Config de partículas
│   └── unit_spawner.gd           # Spawn de unidades
│
├── grid/                         # Grid hexagonal
│   ├── grid_manager.gd
│   └── hex_math.gd
│
├── data/                         # Tipos de Resource
│   ├── class_data.gd
│   ├── encounter_data.gd
│   ├── encounter_spawn.gd
│   ├── grid_config.gd
│   ├── passive_effect.gd
│   ├── status_effect.gd
│   ├── team_data.gd
│   ├── unit_template.gd
│   └── weapon_data.gd
│
├── components/                   # Componentes de cena
│   ├── active_status_effect.gd
│   └── hex_tile.gd
│
├── core/                         # Singleton e utilitários
│   ├── game_manager.gd           # Singleton (autoload)
│   ├── camera_controller.gd
│   ├── battle_config.gd          # Config central           ← NOVO
│   └── main_menu.gd
│
├── skills/                       # Sistema de habilidades
│   ├── skill_context.gd
│   ├── skill_data.gd
│   ├── skill_effect.gd
│   └── skill_executor.gd
│
├── editor/                       # Editor de mapa
│   └── map_editor.gd
│
└── ui/                           # Widgets de UI puros
    ├── stat_modifier.gd
    ├── unit_details_panel.gd
    ├── unit_hp_bar.gd
    └── unit_info_panel.gd
```

### Comparativo: Antes vs Depois

| Métrica | Antes | Depois |
|---------|-------|--------|
| Scripts em `scripts/` | 35 | ~52 |
| God Objects (500+ linhas) | 3 (`BattleHud`, `BattleFlow`, `UnitBase`) | 0 |
| Acoplamento hardcoded | ~15 ocorrências | 0 |
| Classes com uma responsabilidade | ~30% | ~90% |
| Dependência entre pastas | Cruzada (UI ↔ Units) | Hierárquica |

---

## 11. Estratégia de Migração

### Regras para Não Quebrar o Jogo

1. **Nunca remover antes de criar substituto** — primeiro crie o novo arquivo, depois refatore o consumidor, depois remova o antigo
2. **Cada fase termina com jogo rodando** — execute o Godot após cada mudança significativa
3. **Preservar interface pública** — se `BattleFlow` antes tinha `execute_move()`, depois também tem
4. **Commits por fase** — `git commit -m "fase 0: remover acoplamento hardcoded"`

### Ordem Recomendada

```
Fase 0 → Fase 1 → Fase 2 → Fase 3 → Fase 4 → Fase 5 → Fase 6
```

Cada fase depende da anterior. A Fase 0 é pré-requisito para todas as outras porque sem resolver o acoplamento hardcoded, as extrações seriam mais difíceis.

### Exemplo de Fluxo para Uma Fase

```
1. Crio o novo arquivo (ex: UnitStats.gd)
2. Movo a lógica para o novo arquivo
3. No UnitBase, substituo a implementação antiga pela delegação
4. Testo se compila e roda
5. Removo o código antigo do UnitBase
6. Commit
```

---

## 12. Boas Práticas Aprendidas

### Para Projetos Godot em Geral

| Prática | Como Aplicar | Benefício |
|---------|-------------|-----------|
| **Injeção de dependência** | `setup()` em vez de `get_node()` | Testabilidade, acoplamento baixo |
| **Sinais para comunicação** | Emitir de domínio, escutar em presentation | Separação clara de responsabilidades |
| **Composição sobre herança** | `UnitBase` compõe módulos | Cada módulo é testável independentemente |
| **Data-driven design** | Resources para stats, armas, encontros | Balanceamento sem código |
| **Pastas por camada, não por feature** | `battle/`, `presentation/`, `data/` | Organização previsível |
| **God Objects são um alerta** | Se passar de 200 linhas, extraia | Mantém código compreensível |
| **Não confie em paths absolutos** | Use `@export` ou `setup()` | Resiliência a mudanças na node tree |
| **Evite estado global** | Prefira instâncias injetadas | Previsibilidade, facilidade de teste |
| **Separe lógica de visual** | `battle/` não sabe o que é Mesh | Pode mudar visual sem tocar em regras |
| **Documente decisões** | PROJECT_RULES.md + DECOUPLING.md | Time (e seu futuro eu) entende o porquê |

### Padrões Godot Recomendados

1. **`setup()` pattern**: método chamado pelo parent/orquestrador para injetar dependências
   ```gdscript
   func setup(p_dep1: Type1, p_dep2: Type2) -> void:
       dep1 = p_dep1
       dep2 = p_dep2
       _connect_signals()
   ```

2. **`@export var scene: PackedScene`**: injetar cenas em vez de instanciar dentro do código

3. **Grupos (`add_to_group()`)**: alternativa leve à injeção para broadcast de eventos

4. **`@onready var`**: para referências dentro do mesmo subtree (não para siblings distantes)

5. **Signals sobre chamadas diretas**: `attack_executed.emit()` em vez de `audio_manager.play_sfx()`

---

## Apêndice: Referências

### Arquivos a Criar (18 novos)

```
scripts/presentation/attack_line_effect.gd
scripts/presentation/impact_effect.gd
scripts/presentation/tile_flash_effect.gd
scripts/presentation/camera_service.gd
scripts/presentation/hp_bar_manager.gd
scripts/presentation/turn_order_ui.gd
scripts/presentation/damage_popup_manager.gd
scripts/presentation/action_submenu_ui.gd
scripts/presentation/action_name_popup.gd
scripts/presentation/hint_display.gd
scripts/presentation/resource_display.gd
scripts/units/unit_stats.gd
scripts/units/unit_effects.gd
scripts/units/unit_equipment.gd
scripts/units/unit_combat.gd (opcional)
scripts/systems/passive_service.gd
scripts/core/battle_config.gd
```

### Arquivos a Remover (1)

```
scripts/systems/ui_system.gd
scripts/systems/ui_system.gd.uid
```

### Arquivos a Refatorar (6)

| Arquivo | Linhas (hoje) | Linhas (meta) | Responsabilidades |
|---------|---------------|---------------|-------------------|
| `battle_flow.gd` | 557 | ~350 | Orquestração pura |
| `unit_base.gd` | 601 | ~250 | Fachada de unidade |
| `battle_hud.gd` | 601 | ~80 | Fachada de UI |
| `skill_executor.gd` | 328 | ~280 | Sem dependências hardcoded |
| `passive_system.gd` | 251 | ~200 (como service) | Instância injetável |
| `game_manager.gd` | 42 | Manter | OK como está |

### Estimativa de Esforço

| Fase | Complexidade | Arquivos Novos | Arquivos Modificados | Tempo Estimado |
|------|-------------|----------------|---------------------|----------------|
| Fase 0 | 🔴 Alta | 0 | 6+ | 2-3 sessões |
| Fase 1 | 🟡 Média | 4 | 1 | 1 sessão |
| Fase 2 | 🔴 Alta | 4 | 1 | 2-3 sessões |
| Fase 3 | 🔴 Alta | 7 | 1 | 2-3 sessões |
| Fase 4 | 🟡 Média | 1 | 3+ | 1 sessão |
| Fase 5 | 🟢 Baixa | 0 | 1 | 15 min |
| Fase 6 | 🟢 Baixa | 1 | 2+ | 1 sessão |

**Total estimado**: 8-12 sessões de trabalho focadas.

---

*Documento mantido em `DECOUPLING.md` na raiz do projeto. Atualize conforme o progresso das fases.*