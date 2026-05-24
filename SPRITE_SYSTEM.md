# Sistema de Sprites — Documentação Técnica

## Visão Geral

O sistema de sprites foi refatorado para usar `MeshInstance3D` + `ShaderMaterial` customizado, substituindo a abordagem anterior de `MeshInstance3D` + `StandardMaterial3D` com troca de textura por frame.

### Problemas resolvidos

- **Tint de time**: Antes resultava em quadrado cinza. Agora usa `tint_color` no shader.
- **Filtros de cor para status effects**: `set_status_tint()` aplica cor multiplicativa via shader.
- **Damage flash**: `flash_amount` no shader, sem tween de material.
- **Outline funcional**: Amostragem correta levando em conta `u_hframes` e `u_frame_offset`.
- **Performance**: Troca de frame é apenas atualizar `u_frame_offset` no shader, sem recriar texturas.
- **Billboard**: Implementado manualmente no `vertex()` do shader (FIXED_Y).

---

## Arquivos do Sistema

### 1. `shaders/unit_sprite_v2.gdshader`

**Tipo**: `shader_type spatial`

Shader responsável por toda a renderização do sprite: billboard, seleção de frame, outline, tint e flash.

#### Uniformes

| Uniform | Tipo | Descrição |
|---|---|---|
| `sprite_texture` | `sampler2D` | Strip horizontal da animação atual |
| `u_hframes` | `int` | Número de frames horizontais na textura |
| `u_frame_offset` | `float` | Offset UV do frame atual (0.0 a (hframes-1)/hframes) |
| `outline_color` | `vec4` | Cor do outline (vem do TeamData) |
| `outline_width` | `float` | Grossura do outline em pixels |
| `flash_amount` | `float` | 0.0 = normal, 1.0 = branco total |
| `tint_color` | `vec4` | Tint multiplicativo (1.0 = sem alteração) |
| `texture_pixel_size` | `vec2` | Tamanho do pixel relativo ao quad (para outline) |

#### Vertex shader

Implementa billboard FIXED_Y: zera a rotação da `MODELVIEW_MATRIX` mantendo apenas a translação, fazendo o quad sempre encarar a câmera horizontalmente.

#### Fragment shader

1. Calcula `frame_uv = (v_uv.x / hframes) + frame_offset` para selecionar o frame correto na strip
2. Se o pixel tem alpha > 0.1: aplica `tint_color` (multiplicativo) e `flash_amount` (additive white)
3. Se o pixel é transparente: sampleia pixels vizinhos para detectar borda e desenha outline
4. Se alpha final < 0.01: `discard`

---

### 2. `scripts/units/unit_sprite_controller.gd`

**Classe**: `UnitSpriteController`
**Extends**: `Node3D`

Controller que gerencia o `MeshInstance3D` filho e o `ShaderMaterial`. Cria o mesh e o material em `_ready()`.

#### Propriedades Exportadas

| Propriedade | Tipo | Padrão | Descrição |
|---|---|---|---|
| `default_animation` | `String` | `"idle"` | Animação inicial |
| `pixel_size` | `float` | `0.022` | Tamanho do pixel no mundo 3D |
| `y_offset` | `float` | `0.0` | Offset vertical adicional |
| `use_placeholder_sheets` | `bool` | `true` | Se true, carrega placeholders automáticos |

#### Métodos Públicos

| Método | Descrição |
|---|---|
| `apply_team_data(team_data, team_id)` | Aplica outline color e tint sutil do time |
| `configure_surface(grid_config)` | Ajusta posição Y para a superfície do grid |
| `get_sprite_top_y()` | Retorna o topo visual do sprite (em unidades 3D) |
| `play(animation_name)` | Toca uma animação |
| `play_attack()` | Toca animação de ataque (one-shot) |
| `play_one_shot(anim, return_anim)` | Toca animação e volta para outra |
| `flash_white(duration)` | Pisca branco (damage feedback) |
| `shake(intensity, duration)` | Tremor (damage feedback) |
| `play_death()` | Fade out e retorna Tween |
| `set_status_tint(color)` | Aplica tint de status (ex: verde poison) |
| `reset_status_tint()` | Remove tint de status |

#### Animação interna

O controller gerencia um dicionário `animations` que mapeia nome da animação para `{texture, fps, loop, frame_count}`. Em `_process()`, incrementa `_current_frame` baseado no FPS e atualiza `u_frame_offset` no shader.

#### Placeholders

- Se `use_placeholder_sheets = true` e `animations` está vazio, carrega automaticamente as strips do diretório `assets/sprites/units/placeholder/`
- Se existir `Gr1_Ember.png` (atlas combinado), usa `AtlasTexture` com regiões
- Se não, usa strips individuais (`Gr1_Idle.png`, `Gr1_Trans.png`, etc.)

---

### 3. `scenes/units/unit_base.tscn`

**Estrutura da cena**:

```
UnitBase (Node3D) ← unit_base.gd
  ├─ UnitVisual (Node3D) ← unit_sprite_controller.gd
  │    └─ MeshInstance3D (criado em _ready())
  └─ StaticBody3D
       └─ CollisionShape3D (BoxShape3D)
```

---

### 4. `scripts/units/unit_base.gd`

**Classe**: `UnitBase` | **Extends**: `Node3D`

Referencia o visual via:

```gdscript
@onready var _unit_visual = $UnitVisual  # UnitSpriteController
```

Delega chamadas visuais:

- `take_damage()` → `_unit_visual.flash_white()` + `_unit_visual.shake()`
- `die()` → `_unit_visual.play_death()`
- `play_attack_visual()` → `_unit_visual.play_attack()`
- `apply_team_data()` → `_unit_visual.apply_team_data()`
- `configure_from_grid()` → `_unit_visual.configure_surface()`
- `get_portrait()` → lê a textura da animação "idle" do dicionário `animations`

---

## Como Usar

### Tint de time (automático)

```gdscript
# Em UnitSpawner, após criar a unidade:
unit.apply_team_data(team_data)
# UnitSpriteController.apply_team_data() aplica outline_color e tint sutil
```

### Filtros de cor para status effects

```gdscript
# Exemplo: poison (verde)
_unit_visual.set_status_tint(Color(0.2, 1.0, 0.2))

# Exemplo: freeze (azul)
_unit_visual.set_status_tint(Color(0.2, 0.2, 1.0))

# Exemplo: burn (vermelho)
_unit_visual.set_status_tint(Color(1.0, 0.3, 0.3))

# Remover tint
_unit_visual.reset_status_tint()
```

### Damage flash

```gdscript
# Automático em UnitBase.take_damage():
_unit_visual.flash_white(0.25)
_unit_visual.shake(0.08, 0.4)
```

### Animações customizadas

```gdscript
# O controller aceita animações via dicionário animations.
# Para adicionar uma animação externamente:
_visual.animations["nova_anim"] = {
    "texture": minha_textura_strip,
    "fps": 10.0,
    "loop": false,
    "frame_count": 6,
}
_visual.play("nova_anim")
```

---

## Arquivos Deprecados (mantidos como referência)

| Arquivo | Substituído por |
|---|---|
| `scripts/units/unit_sprite_visual.gd` | `unit_sprite_controller.gd` |
| `shaders/unit_sprite.gdshader` | `unit_sprite_v2.gdshader` |
| `scripts/units/gr1_placeholder_frames.gd` | Lógica embutida em `unit_sprite_controller.gd` |

---

## Constantes

| Constante | Valor | Local |
|---|---|---|
| `FRAME_SIZE_PX` | `80` | `unit_sprite_controller.gd` |
| `SURFACE_CLEARANCE` | `0.03` | `unit_sprite_controller.gd` |
| `pixel_size` (padrão) | `0.022` | Export de `unit_sprite_controller.gd` |
| `IDLE_ANIMATION` | `"idle"` | `unit_sprite_controller.gd` |
| `ATTACK_ANIMATION` | `"transform"` | `unit_sprite_controller.gd` |

O tamanho do frame pode ser alterado via `FRAME_SIZE_PX` no controller.