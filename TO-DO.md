# Ideias para a classe Ember

## Visão geral
- Classe focada em dano de fogo e *burn*.
- Todos os personagens têm o mesmo AP, então as habilidades devem ser balanceadas em custo e efeito.

## Passivas
- **Flame Touch**: cada dano de arma adiciona 1 stack de *burn* ao alvo.
- **Heat‑Resist** (opcional): reduz a quantidade de stacks de *burn* recebidos em 1.

## Status Effect
- **Burn**: persistente, acumula *stacks*. No início do turno do alvo, consome todos os stacks e causa `stack * X%` de dano ignorando defesa. X a definir (ex.: 10%).

## Habilidades
1. **Fireball**
   - AP: 2
   - Alcance: 3 tiles
   - Efeito: dano baixo (ex.: 4) + 3 stacks de *burn* no alvo e em todas as unidades adjacentes.

2. **Overheat**
   - AP: 3
   - Alcance: 0 (auto)
   - Efeito: aplica buff *Overheat* ao próprio Ember: +1 defesa e, ao acertar com ataque corpo‑a‑corpo, aplica 1 stack de *burn* ao alvo.

3. **Inferno**
   - AP: 4 (custo total de AP)
   - Alcance: 2 tiles em cone
   - Efeito: dano baixo (ex.: 6) + 4 stacks de *burn* em todas as unidades no cone.

## Próximos passos
- Definir valores exatos de dano e percentual de *burn*.
- Implementar o status *Burn* e a lógica de consumo no início do turno.
- Criar os recursos `.tres` para passiva, status e habilidades.
- Ajustar o `SkillExecutor` para lidar com *burn* e *Overheat*.
- Testar em `test_skirmish.tres`.
