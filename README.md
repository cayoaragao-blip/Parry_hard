# Protótipo (Godot 4)

Jogo 3D competitivo para 2 jogadores em uma quadra fechada com 4 paredes. 
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

