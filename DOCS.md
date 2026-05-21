# TTRPG-MECHA — Documentação do Projeto

## Visão Geral

Jogo tático de mechas em grid hexagonal, feito com Godot 4. Estilo 2.5D (ambiente 3D com sprites 2D billboard, estilo Octopath Traveler).

**Pilares de design:**
- Combate tático em grid hexagonal
- Sistema de AP (Action Points) para ações
- Builds modulares de mechas
- Escopo pequeno, combate rápido

**Engine:** Godot 4 | **Linguagem:** GDScript | **Coordenadas:** Axial hex

---

## Estrutura de Pastas

```
scripts/
├── battle/          — Fluxo de batalha, turnos, combate, seleção, input, AI
│   └── ai/          — Comportamento de inimigos (EnemyBehavior, intents)
├── grid/            — Grid hexagonal (GridManager, HexMath)
├── units/           — Actor de unidade (UnitBase, UnitSpriteVisual)
├── presentation/    — HUD, highlights de tile, turn announce
├── systems/         — Serviços cross-cutting (AudioManager, Spawner)
├── data/            — Tipos de Resource (ClassData, WeaponData, EncounterData)
├── components/      — Componentes de cena (HexTile, ActiveStatusEffect)
├── core/            — Utilitários compartilhados (GameManager, câmera)
└── ui/              — Elementos de UI (UnitHpBar)

data/
├── ai/              — Resources de AI (.tres)
├── classes/         — Definitions de classe (Assault, Bastion, Sniper)
│   └── passives/    — Efeitos passivos por classe
├── encounters/      — Encontros/batalhas configuráveis
├── grid/            — Configuração do grid
├── skills/          — Definições de habilidades
│   └── effects/     — Efeitos individuais de skills
├── status_effects/  — Buffs/debuffs (slow, shatter, weaken, etc.)
├── templates/       — Templates de unidade (player/enemy)
└── weapons/         — Armas (Starter Rifle, Shotgun)

scenes/
├── battle/          — Cena principal de batalha
├── grid/            — Elementos do grid
├── ui/              — Cenas de UI
└── units/           — Cena base de unidade
```

---

## Arquitetura de Batalha

### Node Tree (BattleSession)

Todos os nós de lógica de batalha são irmãos sob `BattleSession`:

| Nome | Classe | Responsabilidade |
|------|--------|-----------------|
| `SelectionState` | `SelectionState` | Seleção do jogador e modo de ação |
| `TurnController` | `TurnController` | Fila de turnos e mudança de fase |
| `CombatResolver` | `CombatResolver` | Regras de ataque; emite sinais de combate |
| `BattleHud` | `BattleHud` | UI na tela (barras, popups, painéis) |
| `GridHighlights` | `GridHighlights` | Meshes de highlight de tiles |
| `UnitSpawner` | `UnitSpawner` | Instancia unidades a partir de `ClassData` |
| `BattleInput` | `BattleInput` | Mouse/keyboard → fluxo |
| `EnemyBrain` | `EnemyBrain` | Execução de turno inimigo |
| `BattleFlow` | `BattleFlow` | Orquestra a batalha; entrada única para ações |
| `AudioManager` | `AudioManager` | SFX; reage apenas a sinais |
| `SkillExecutor` | `SkillExecutor` | Executa habilidades |

O `World` (3D), canvas de UI e VFX ficam fora de `BattleSession` mas são referenciados via nomes únicos (`%World`, etc.).

### Fluxo de Inicialização

```
GameManager (singleton)
  └→ start_encounter(encounter)
       └→ change_scene_to_file("battle_scene.tscn")
            └→ BattleFlow._bootstrap()
                 ├→ setup(recebe todos os serviços)
                 │    ├→ battle_input.setup(...)
                 │    ├→ enemy_brain.setup(...)
                 │    └→ audio_manager.setup(...)
                 └→ start_battle()
                      ├→ grid_manager.initialize(encounter)
                      ├→ _spawn_encounter()
                      ├→ turn_controller.build_turn_queue()
                      └→ turn_controller.start_first_turn()
```

### Regras de Wiring (OBRIGATÓRIAS)

1. **`BattleFlow` bootstrapa dependências** — Em `_bootstrap()`, `BattleFlow.setup(...)` recebe todos os serviços da sessão. Nós irmãos NÃO devem usar `get_parent().get_node("OtherSibling")` em `_ready()`.

2. **Use `setup()` para links cross-service** — Padrão usado por `BattleInput`, `EnemyBrain` e `AudioManager`:
   ```gdscript
   func setup(p_battle_flow: BattleFlow, ...) -> void:
       battle_flow = p_battle_flow
       some_signal.connect(_handler)
   ```

3. **Domínio emite eventos; apresentação se inscreve**
   - **Emitir sinais de:** `CombatResolver`, `TurnController`, `UnitBase`, e sinais de ação no `BattleFlow`
   - **Inscrever em:** `AudioManager` (em `setup()`), `BattleHud` (atualizado pelo `BattleFlow` após ações)
   - **NUNCA** chamar `audio_manager.play_*()` do `BattleFlow` ou código de combate. Adicione ou reutilize um sinal.

4. **Registre atores dinâmicos** — Quando `BattleFlow` spawna uma unidade, chame `audio_manager.register_unit(unit)`.

5. **Pontos de entrada de ação vivem no `BattleFlow`** — Movimento, ataques e fim de turno passam pelo `BattleFlow` (`execute_move`, `execute_attack`, `end_turn`). Input e AI chamam estes, não métodos raw de tile/unit.

6. **Dados em Resources** — Stats, weapons, encounters e AI behaviors usam `.tres` sob `data/`.

### Mapa de Sinais (Battle Feedback)

| Sinal | Emissor | Listeners típicos |
|-------|---------|-------------------|
| `attack_executed` | `CombatResolver` | `AudioManager` |
| `target_hit` | `CombatResolver` | `AudioManager` |
| `turn_ended` | `TurnController` | `AudioManager` |
| `move_executed` | `BattleFlow` | `AudioManager` |
| `died` | `UnitBase` | `AudioManager` (via `register_unit`) |
| `current_unit_changed` | `TurnController` | `BattleFlow`, `EnemyBrain` |
| `action_mode_changed` | `SelectionState` | `BattleHud` |
| `hovered_unit_changed` | `SelectionState` | `BattleHud` |
| `unit_selected` | `SelectionState` | — |

---

## Sistemas de Jogo

### Grid Hexagonal

- **Coordenadas:** Axial (q, r)
- **`GridConfig`** (`data/grid/default_grid_config.tres`) — `hex_size`, `mesh_radius`, `mesh_height`, `grid_radius`, cores de tile/overlay
- **`HexMath`** (`scripts/grid/hex_math.gd`) — distância axial, `axial_to_world`, `world_to_axial`
- **`GridManager.initialize(encounter)`** — chamado de `BattleFlow.start_battle()` antes de spawnar unidades
- **`HexTile`** — mesh base usa materiais de config; ranges de movimento/ataque usam `HighlightOverlay`
- **`GridPathPreview`** — desenha caminho de movimento no modo MOVE
- **`MovementRules.find_path()`** — pathfinding BFS

### Sistema de Turnos

**`TurnController`:**
- Mantém `turn_queue: Array[UnitBase]` e `current_turn_index`
- `build_turn_queue()` — coleta todos os filhos do container de unidades
- `start_turn(unit)` — define `current_unit`, chama `unit.refresh_turn()`, emite `current_unit_changed`
- `end_turn()` — emite `turn_ended`, avança índice (com wrap), chama `start_turn` próximo
- `prune_invalid_units()` — remove unidades mortas/invalidadas da fila

**`UnitBase.refresh_turn()`:**
- `_tick_effects()` — decrementa duração de efeitos, remove expirados
- `current_movement = get_effective_movement()` — recalcula com modificadores
- `current_ap = get_effective_max_ap()` — recalcula com modificadores
- `reduce_cooldowns()` — decrementa cooldowns de skills

### Sistema de Ação (AP)

Cada unidade tem:
- `max_ap` — máximo de Action Points (da classe)
- `current_ap` — AP disponível no turno

**Custos de ação:**
- Ataque: definido pela arma ativa (`weapon.attack_ap_cost`)
- Habilidades: definido por skill (`skill.ap_cost`)
- Movimento: custo por tile (calculado por `MovementRules.get_move_cost`)

### Sistema de Combate

**Fórmula de dano:**
```
total_attack_power = base_attack + weapon_power + effect_modifiers + passive_bonuses
effective_defense = max(1, defense + effect_modifier_defense)
final_damage = max(1, total_attack_power - effective_defense)
```

**`CombatResolver`:**
- `is_unit_in_attack_range(attacker, target)` — verifica distância vs `attacker.get_effective_range()`
- `can_attack(attacker, target)` — range + AP suficiente
- `execute_attack(attacker, target)` — gasta AP, calcula dano, chama `target.take_damage()`, emite sinais

**`UnitBase.take_damage(amount)`:**
- Aplica defesa efetiva
- Flash visual (white flash + shake)
- Se HP ≤ 0 → `die()` → animação de morte → `queue_free()`

### Sistema de Movimento

**`MovementRules`:**
- `can_move_to(unit, target_tile, grid_manager)` — validação (tile ocupado, distância, etc.)
- `get_move_cost(unit, target_tile, grid_manager)` — custo de AP de movimento
- `find_path(unit, target_tile, grid_manager)` — BFS pathfinding

**`UnitBase.move_to_tile(tile)`:**
- Desocupa tile anterior
- Ocupa novo tile
- Anima transição com tween (duração: `movement_tween_duration`)

### Sistema de Unidade

**`UnitBase` — Stats:**
| Propriedade | Descrição |
|-------------|-----------|
| `max_hp` / `current_hp` | Pontos de vida |
| `max_movement` / `current_movement` | Movimento por turno |
| `max_ap` / `current_ap` | Action Points |
| `defense` | Redução de dano |
| `attack_power` | Poder base de ataque (da classe) |
| `attack_range` | Range de ataque (da arma) |

**`UnitBase` — Efeitos:**
- `active_effects: Array[ActiveStatusEffect]` — efeitos ativos
- `add_effect(effect_data, source)` — aplica efeito (refresh se já existe)
- `remove_effect(effect_id)` — remove todas as instâncias
- `has_effect(effect_id)` — verifica presença
- `get_effect_modifier(stat)` — soma modificadores de todos os efeitos

**`UnitBase` — Equipamento:**
- `primary_weapon: WeaponData`
- `secondary_weapon: WeaponData`
- `active_weapon_slot: String` — "primary" ou "secondary"
- `switch_weapon()` — alterna entre primária/secundária

**`UnitBase` — Passivas:**
- `_passive_bonuses: Dictionary` — bônus de passivas da classe
- `get_passive_bonus(stat)` — retorna valor do bônus
- Suporta: `FLAT_STAT_BONUS`, `CONDITIONAL_BONUS`, `ON_KILL`, `AOE_ON_DAMAGE`, `RESISTANCE`

### Sistema de Efeitos (Status Effects)

**`StatusEffect` (Resource):**
| Propriedade | Descrição |
|-------------|-----------|
| `effect_id` | Identificador único |
| `display_name` | Nome exibido |
| `description` | Descrição |
| `duration` | Duração em turnos (-1 = permanente/toggle) |
| `icon` | Ícone de display |
| `modifiers` | Dicionário `{stat: valor}` |

**Stats modificáveis:** `movement`, `max_ap`, `range`, `attack_power`, `defense`

**Efeitos especiais:**
- `movement <= -999` — sentinel que força movimento a 0 (usado por Turret Mode)
- `duration == -1` — efeito permanente (toggle, pode ser removido pela skill novamente)
- `allowed_tags` — lista de tags de arma que qualificam para o bônus (ex: só armas "ranged")

**`ActiveStatusEffect` (Runtime):**
- Instância de `StatusEffect` aplicada a uma unidade
- `turns_remaining` — turnos restantes
- `tick()` — decrementa duração, retorna `true` se expirou
- `source` — nome da unidade que aplicou

**Efeitos implementados:**
| Efeito | Tipo | Modificadores |
|--------|------|---------------|
| `slow` | Debuff | movement: -2 |
| `shatter` | Debuff | defense: -2 |
| `weaken` | Debuff | attack_power: -2 |
| `haste` | Buff | movement: +2 |
| `fortify` | Buff | defense: +2 |
| `power_up` | Buff | attack_power: +2 |
| `energize` | Buff | max_ap: +1 |
| `turret` | Toggle | movement: -999 (bloqueio) |

### Sistema de Habilidades

**`SkillData` (Resource):**
| Propriedade | Descrição |
|-------------|-----------|
| `skill_id` | Identificador único |
| `skill_name` | Nome exibido |
| `description` | Descrição |
| `ap_cost` | Custo em AP |
| `skill_range` | Range (0 = self, -1 = ilimitado) |
| `max_uses` | Usos por batalha (-1 = ilimitado) |
| `target_mode` | `SELF`, `SINGLE_UNIT`, `SINGLE_TILE`, `AOE_CIRCLE` |
| `team_filter` | `ALLY`, `ENEMY`, `BOTH`, `SELF_ONLY` |
| `aoe_radius` | Raio para AOE |
| `effects` | Array de `SkillEffect` |
| `status_effects` | Status effects aplicados ao alvo |
| `self_effects` | Status effects aplicados ao caster |

**`SkillEffect` (Resource):**
| Propriedade | Descrição |
|-------------|-----------|
| `effect_type` | `DAMAGE`, `HEAL`, `APPLY_STATUS`, `REMOVE_STATUS`, `BUFF`, `DEBUFF` |
| `amount` | Valor base (dano, cura) |
| `status_effect` | Efeito a aplicar/remover |
| `stat_name` | Stat a modificar (buff/debuff) |
| `stat_modifier` | Valor do modificador |
| `duration` | Duração (buff/debuff) |

**`SkillContext` (RefCounted):**
- `caster: UnitBase` — unidade que usa
- `target_unit: UnitBase` — alvo (opcional)
- `target_tile: HexTile` — tile alvo (opcional)
- `skill: SkillData` — habilidade sendo usada
- `affected_units: Array[UnitBase]` — preenchido pelo executor

**`SkillExecutor.execute(ctx)`:**
1. Valida targeting (`_validate_targeting`)
2. Resolve unidades afetadas (`_resolve_targets`)
3. Handle toggle skills (se já ativo, remove)
4. Aplica `SkillEffect` a cada unidade afetada
5. Aplica `status_effects` aos alvos
6. Aplica `self_effects` ao caster
7. Toca SFX e mostra popup

**Habilidades implementadas:**
| Skill | Classe | Efeito |
|-------|--------|--------|
| Suppression | Assault | Dano + Slow |
| Adrenaline Rush | Assault | Haste + Power Up (self) |
| Grenade | Assault | AoE Dano |
| Fortify | Bastion | Fortify (self) + defesa |
| Shield Bash | Bastion | Dano + Shatter |
| Taunt | Bastion | Weaken + provocação |
| Precision Shot | Sniper | Dano alto |
| Turret Mode | Sniper | Toggle: movimento 0, +range |
| Armor Piercer | Sniper | Dano + Shatter |
| Overwatch | Sniper | Turret + vigilância |

### Sistema de Classes

**`ClassData` (Resource):**
| Propriedade | Descrição |
|-------------|-----------|
| `class_id` | Identificador |
| `display_name` | Nome exibido |
| `max_hp` | HP máximo |
| `movement` | Movimento base |
| `max_ap` | AP máximo |
| `defense` | Defesa base |
| `base_attack` | Poder de ataque base |
| `primary_weapon` | Arma primária |
| `secondary_weapon` | Arma secundária |
| `skills` | Array de `SkillData` |
| `passives` | Array de `PassiveEffect` |
| `enemy_behavior` | AI behavior opcional |

**Classes implementadas:**
| Class | HP | MOV | AP | DEF | Arma Primária | Arma Secundária |
|-------|----|-----|----|-----|---------------|-----------------|
| Assault | 8 | 6 | 4 | 1 | Starter Rifle | Shotgun |
| Bastion | 12 | 4 | 3 | 3 | Shotgun | — |
| Sniper | 6 | 5 | 3 | 0 | Starter Rifle | Shotgun |

### Sistema de Armas

**`WeaponData` (Resource):**
| Propriedade | Descrição |
|-------------|-----------|
| `weapon_id` | Identificador |
| `weapon_name` | Nome exibido |
| `weapon_range` | Range de ataque |
| `attack_ap_cost` | Custo em AP por ataque |
| `weapon_power` | Poder de dano |
| `tags` | Array de tags (ex: "rifle", "ranged") |

**Armas implementadas:**
| Arma | Poder | Range | AP | Tags |
|------|-------|-------|----|------|
| Starter Rifle | 3 | 3 | 2 | rifle, ranged |
| Shotgun | 5 | 1 | 2 | shotgun, ranged |

### Sistema de Passivas

**`PassiveEffect` (Resource):**
| Propriedade | Descrição |
|-------------|-----------|
| `passive_type` | `FLAT_STAT_BONUS`, `CONDITIONAL_BONUS`, `ON_KILL`, `AOE_ON_DAMAGE`, `RESISTANCE` |
| `stat_name` | Stat a modificar |
| `stat_value` | Valor do bônus |
| `condition` | Condicional (ex: "range_le_2", "ranged_only") |

**Passivas implementadas:**
| Passiva | Classe | Efeito |
|---------|--------|--------|
| Close Quarters | Assault | +1 dmg em range ≤ 2 |
| Thick Skin | Bastion | +2 DEF |
| Eagle Eye | Sniper | +1 range com armas ranged |

### Sistema de Templates

**`UnitTemplate` (Resource):**
- `template_id` — identificador
- `display_name` — nome
- `class_data` — referência à `ClassData`
- `team_id` — "player" ou "enemy"

Templates permitem reutilizar classes com diferentes times (ex: `assault.tres` vs `assault_enemy.tres`).

### Sistema de Encontros

**`EncounterData` (Resource):**
- `encounter_id` — identificador
- `display_name` — nome
- `grid_radius` — raio do grid
- `teams` — Array de `TeamData`
- `spawns` — Array de `EncounterSpawn`

**`EncounterSpawn` (Resource):**
- `template` — referência ao `UnitTemplate`
- `q`, `r` — coordenadas hex de spawn
- `team_id` — override de time (opcional)

**`TeamData` (Resource):**
- `team_id` — identificador
- `display_name` — nome
- `is_player` — se é time do jogador
- `outline_color` — cor de outline dos sprites
- `hp_bar_full_color` / `hp_bar_empty_color` — cores da barra de HP

### Sistema de Input

**`BattleInput`:**
- `_process()` — atualiza hover do mouse a cada frame
- `_unhandled_input()` — processa clique esquerdo
- `_pick_at_screen_position()` — raycast da câmera para grid/unidades
- Modos de ação:
  - `NONE` — selecionar unidade atual
  - `MOVE` — mover para tile hovered
  - `ATTACK` — atacar unidade hovered
  - `SKILL` — usar habilidade pendente no alvo

**Controles:**
- **Clique esquerdo** — seleciona/ataca/move
- **Botão Move** — ativa modo movimento
- **Botão Action** — abre submenu de armas/skills
- **Botão End Turn** — encerra turno
- **Z** — fecha o jogo

### Sistema de UI (BattleHud)

**Painéis:**
- `ActionPanel` — botões Move, Action, End Turn + labels MOV/AP
- `ActionSubmenu` — lista de armas e habilidades disponíveis
- `HoverInfoPanel` — info da unidade sob o mouse (portrait, HP, stats, efeitos)
- `TurnOrder` — ordem de turno visual
- `DamagePopupContainer` — popups flutuantes de dano/cura
- `TurnAnnounce` — banner de início de turno

**Popups:**
- Dano: vermelho, "-X"
- Cura: verde, "+X"
- Buff: amarelo, "+X"
- Debuff: roxo, "X"
- Morte: "DEAD" em vermelho escuro
- Action Name: banner centralizado no topo

### Sistema de Audio

**`AudioManager`:**
- Conecta-se a sinais em `setup()`
- `register_unit(unit)` — conecta sinal `died`
- SFX mapeados por skill_id em `play_skill_sfx()`

**Canais de áudio:**
| Canal | Uso |
|-------|-----|
| AudioAttack | Ataque executado |
| AudioMove | Movimento |
| AudioHit | Alvo atingido |
| AudioDeath | Morte de unidade |
| AudioEndTurn | Fim de turno |
| AudioUIHover | Hover em botão |
| AudioUIClick | Clique em botão |
| AudioTurnStart | Início de turno |
| AudioSkillBuff | Skill de buff |
| AudioSkillDebuff | Skill de debuff |
| AudioSkillHeal | Skill de cura |
| AudioSkillDamage | Skill de dano |
| AudioSkillTurret | Skill de turret |
| AudioSkillTaunt | Skill de taunt |
| AudioSkillGrenade | Skill de grenade |
| AudioInvalid | Ação inválida |

### Sistema de Visual (2.5D)

- Usam `MeshInstance3D` + `QuadMesh` com `StandardMaterial3D` e `BILLBOARD_FIXED_Y`
- `UnitSpriteVisual` gerencia animações (idle, transform, revert, attack, death)
- Placeholder sheets: `assets/sprites/units/placeholder/Gr1_*.png` (80×80 frames)
- `UnitBase.configure_from_grid(grid_config)` — sincroniza altura do pé com superfície hex
- Outline shader existe mas está desabilitado temporariamente

### Sistema de IA

**`EnemyBrain`:**
- Executa lista de `AIIntent` (attack, move, wait, end turn)
- `EnemyBehavior.plan(context)` — retorna intents
- `SimpleChaseBehavior` — padrão (persegue e ataca jogador mais próximo)
- `DecisionTreeBehavior` + `DecisionNode` — stubs para árvores customizadas

### GameManager (Singleton)

- Carrega todos os encounters de `data/encounters/` em `_ready()`
- `selected_encounter` — encounter selecionado para batalha
- `start_encounter(encounter)` — troca para cena de batalha
- Referenciado por `BattleFlow._bootstrap()` para obter o encounter

---

## Checklist para Novas Features de Batalha

- [ ] Lógica na pasta correta (`battle/` vs `presentation/` vs `systems/`)
- [ ] Conectado via `BattleFlow.setup()` se precisa de outros nós da sessão
- [ ] Sem wiring de sibling `get_node` em `_ready()`
- [ ] Eventos expostos como sinais se audio/UI devem reagir
- [ ] Novas unidades registradas com `audio_manager.register_unit` ao spawnar
- [ ] Conteúdo em `data/*.tres` quando é configurável por designer

---

## Estilo de Código

- Código legível sobre código clever
- Evitar overengineering
- Scripts pequenos e focados
- Separar lógica de visuais
- Comentários e identificadores em **Inglês**
- Usar `class_name` para tipos referenciados entre pastas