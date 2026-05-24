# Mecha Classes — TTRPG Mecha

## Visão Geral

Este documento descreve todas as 8 classes de mecha implementadas, suas estatísticas, armas, skills e passivas. Cada classe representa um estilo de jogo distinto.

---

## 1. Assault

| Atributo      | Valor |
|---------------|-------|
| HP            | 8     |
| Movimento     | 4     |
| AP Máximo     | 5     |
| Defesa        | 1     |
| Ataque Base   | 2     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |
| Secundária| Shotgun        | 4     | 1       | 2        | shotgun, ranged|

### Skills
| Skill           | Custo AP | Descrição                                      |
|-----------------|----------|-------------------------------------------------|
| Suppression     | 2        | Tiro supressivo que reduz movimento do alvo.    |
| Adrenaline Rush | 2        | Ganha Haste e Power Up (buff próprio).          |
| Grenade         | 3        | Granada de AoE (raio 2), alcance 4.             |

### Passiva
**Close Quarters** — +1 de dano a alcance ≤ 2.

### Design
Mecha de linha de frente versátil. Combina rifle de médio alcance com shotgun para curta distância. A granada oferece pressão em área. A passiva incentiva o combate agressivo.

---

## 2. Bastion

| Atributo      | Valor |
|---------------|-------|
| HP            | 12    |
| Movimento     | 3     |
| AP Máximo     | 5     |
| Defesa        | 3     |
| Ataque Base   | 1     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |
| Secundária| Shotgun        | 4     | 1       | 2        | shotgun, ranged|

### Skills
| Skill       | Custo AP | Descrição                                      |
|-------------|----------|-------------------------------------------------|
| Fortify     | 1        | Aumenta defesa em +2.                           |
| Shield Bash | 2        | Dano corpo a corpo que reduz defesa do alvo.    |
| Taunt       | 1        | Aplica Weaken em todos inimigos num raio 3.     |

### Passiva
**Thick Skin** — +1 de defesa (adicional).

### Design
Tanque pesado. O Bastion tem o maior HP e defesa do jogo, mas baixo movimento e ataque. Usa Fortify para ficar ainda mais resistente, Shield Bash para retaliar e Taunt para enfraquecer inimigos próximos.

---

## 3. Ember ⚠️ INCOMPLETA

| Atributo      | Valor |
|---------------|-------|
| HP            | 8     |
| Movimento     | 3     |
| AP Máximo     | 3     |
| Defesa        | 0     |
| Ataque Base   | 2     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |

### Skills
Nenhuma — não implementadas.

### Passiva
Nenhuma — não implementada.

### Design
Classe incompleta. Sem skills, sem arma secundária, sem passiva. AP baixo (3). Aguarda implementação de habilidades de fogo/queima.

---

## 4. Judge

| Atributo      | Valor |
|---------------|-------|
| HP            | 5     |
| Movimento     | 6     |
| AP Máximo     | 5     |
| Defesa        | 0     |
| Ataque Base   | 1     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |
| Secundária| Vibro Blade    | 5     | 1       | 1        | blade, melee   |

### Skills
| Skill       | Custo AP | Descrição                                           |
|-------------|----------|------------------------------------------------------|
| Accusation  | 1        | Marca um alvo como "Accused" permanentemente.        |
| Judgement   | 2        | Dano 4 (ou 8 se o alvo estiver Accused). Alcance 3. |
| Execution   | 3        | Dano massivo de 8. Só pode usar em Accused. Alv. 2. |

### Passiva
**Judge's Condemnation** — Ao matar um inimigo, ganha +1 stack de Condemnation. Cada stack aumenta ataque e defesa.

### Design
Assassino frágil e rápido. O Judge marca alvos com Accusation, então usa Judgement (dano dobrado) ou Execution (dano massivo) para finalizar. Precisa matar para ficar mais forte via passiva.

---

## 5. Medic

| Atributo      | Valor |
|---------------|-------|
| HP            | 11    |
| Movimento     | 4     |
| AP Máximo     | 5     |
| Defesa        | 2     |
| Ataque Base   | 2     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |
| Secundária| Shotgun        | 4     | 1       | 2        | shotgun, ranged|

### Skills
| Skill         | Custo AP | Descrição                                           |
|---------------|----------|------------------------------------------------------|
| Healing Wave  | 2        | Cura 3 HP de todos aliados num raio 3.               |
| Regen Shield  | 1        | Aplica Regen em um aliado (cura 1 HP no próximo turno). |
| Combat Stim   | 1        | Buff próprio: +2 ataque por 1 turno.                 |

### Passiva
**Thick Skin** — +1 de defesa.

### Design
Suporte resistente. O Medic mantém aliados vivos com Healing Wave (cura em área), Regen Shield (cura ao longo do tempo) e Combat Stim (buff ofensivo). Tem boa sobrevivência com HP 11 e Thick Skin.

---

## 6. Phaser

| Atributo      | Valor |
|---------------|-------|
| HP            | 8     |
| Movimento     | 6     |
| AP Máximo     | 5     |
| Defesa        | 1     |
| Ataque Base   | 2     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Vibro Blade    | 5     | 1       | 1        | blade, melee   |
| Secundária| Shotgun        | 4     | 1       | 2        | shotgun, ranged|

### Skills
| Skill          | Custo AP | Descrição                                           |
|----------------|----------|------------------------------------------------------|
| Blink          | 1        | Teletransporte instantâneo de até 5 tiles.           |
| Swap           | 1        | Troca de lugar com uma unidade a até 5 tiles.        |
| Momentum Damage| 1        | Dano = número de tiles andados neste turno.          |

### Passiva
**Close Quarters** — +1 de dano a alcance ≤ 2.

### Design
Mecha de mobilidade extrema. O Phaser usa Blink e Swap para reposicionamento tático, e Momentum Damage escala com a distância percorrida. Suas armas são todas de curto alcance, exigindo constante movimentação.

---

## 7. Sniper

| Atributo      | Valor |
|---------------|-------|
| HP            | 6     |
| Movimento     | 5     |
| AP Máximo     | 5     |
| Defesa        | 0     |
| Ataque Base   | 3     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |
| Secundária| Shotgun        | 4     | 1       | 2        | shotgun, ranged|

### Skills
| Skill         | Custo AP | Descrição                                           |
|---------------|----------|------------------------------------------------------|
| Precision Shot| 3        | Tiro de alto dano a longo alcance (6).               |
| Turret Mode   | 2        | Alterna modo torre: movimento 0, alcance +3.         |
| Armor Piercer | 3        | Tiro que reduz defesa do alvo. Alcance 5.            |

### Passiva
**Eagle Eye** — +1 de alcance de arma (apenas armas ranged).

### Design
Artilheiro frágil de longo alcance. O Sniper tem o maior ataque base (3) e usa Precision Shot para dano focado. Turret Mode troca mobilidade por alcance extra. Armor Piercer quebra defesas. A passiva Eagle Eye estende ainda mais seu alcance.

---

## 8. Volt

| Atributo      | Valor |
|---------------|-------|
| HP            | 8     |
| Movimento     | 5     |
| AP Máximo     | 5     |
| Defesa        | 1     |
| Ataque Base   | 2     |

### Armas
| Slot      | Nome           | Poder | Alcance | Custo AP | Tags           |
|-----------|----------------|-------|---------|----------|----------------|
| Primária  | Starter Rifle  | 4     | 3       | 2        | rifle, ranged  |
| Secundária| Vibro Blade    | 5     | 1       | 1        | blade, melee   |

### Skills
| Skill         | Custo AP | Descrição                                           |
|---------------|----------|------------------------------------------------------|
| Shock Trooper | 2        | Ataque elétrico que gera Charge. Alcance 2.          |
| Energize      | 2        | Buff próprio: gera Charge e aumenta ataque.          |
| Thunder       | 3        | Raio poderoso. Consome Charge para dano bônus. Alc. 2.|

### Passiva
**Volt Charge** — Ao usar uma ação, ganha +1 stack de Charge. Cada stack adiciona +1 de dano ao próximo ataque.

### Design
Mecha elétrico com recurso de Charge. O Volt gera Charge atacando (Shock Trooper) ou se buffando (Energize). Thunder consome as cargas para dano massivo. A passiva recompensa o uso frequente de habilidades.

---

## Armas Disponíveis

| Nome             | Poder | Alcance | Custo AP | Tags                 |
|------------------|-------|---------|----------|----------------------|
| Starter Rifle    | 4     | 3       | 2        | rifle, ranged        |
| Shotgun          | 4     | 1       | 2        | shotgun, ranged      |
| Vibro Blade      | 5     | 1       | 1        | blade, melee         |
| Missile Launcher | 7     | 5       | 3        | missile, ranged      |

## Passivas

| Nome                     | Tipo | Descrição                                                     |
|--------------------------|------|---------------------------------------------------------------|
| Close Quarters           | Buff | +1 dano a alcance ≤ 2.                                       |
| Eagle Eye                | Buff | +1 alcance de arma (apenas ranged).                          |
| Judge's Condemnation     | Kill | Ao matar: +1 stack. Cada stack aumenta ataque e defesa.      |
| Thick Skin               | Buff | +1 defesa.                                                    |
| Volt Charge              | On Action | Ao agir: +1 stack de Charge. Cada stack +1 dano no próximo ataque. |