# Duelo de Parry — Protótipo (Godot 4)

Jogo 3D competitivo para 2 jogadores (local ou split), em uma quadra fechada com 4 paredes. 
Duas máquinas inimigas ficam presas a uma das paredes, movendo-se lateralmente e disparando projéteis. 
Os jogadores usam parry para ricochetear projéteis de volta nas máquinas, destruindo-as. 
Quem destruir primeiro N máquinas vence.

## Como abrir
1. Abra o Godot 4.3+ (Godot Engine, não precisa de nenhum plugin extra).
2. "Import" este projeto apontando para a pasta que contém `project.godot`.
3. Rode a cena principal (F5) — já está configurada em
   `Project > Project Settings > Application > Run > Main Scene`
   (`res://scenes/main.tscn`).

## Controles
| Ação  | Player 1   | Player 2      |
| Mover | W A S D    | Setas ↑ ↓ ← → |
| Parry | F          | Enter         |

O player vira de frente para a direção em que está se movendo — essa direção
é o que define para qual máquina o projétil vai quando o parry acerta.

## O que já está implementado
- Máquinas fixas em uma parede (`WallMachines` em `arena.tscn`), com
  movimento lateral em vaivém (seno) e disparo periódico.
- Alvo do disparo da máquina: **aleatório** entre os players vivos na cena.
- Parry: janela curta de tempo (`GameConfig.parry_window`) + cooldown
  (`GameConfig.parry_cooldown`).
- Ricochete: pode acertar **qualquer uma das duas máquinas**, dependendo da
  direção para onde o player estiver de frente no momento do parry.
- Stun ao ser atingido sem parry (`GameConfig.stun_duration`), sem sistema de
  vida — o player nunca "morre", só fica temporariamente incapacitado.
- Destruição de máquina → ponto para o autor do parry → respawn após um
  tempo aleatório (`machine_respawn_time_min/max`).
- Projéteis somem ao colidir com paredes, seja no disparo original ou depois
  de ricocheteados.
- Vitória ao atingir `target_score` (padrão 5), com regra de **sudden
  death**: se os dois alcançarem a pontuação-alvo no mesmo instante, a
  partida continua até alguém destruir a próxima máquina primeiro.
- HUD simples com placar dos dois players e mensagem de vitória/empate.
- Colisão física simples entre os dois players (bloqueiam um ao outro, sem
  empurrão) — herdado do `CharacterBody3D` padrão.
