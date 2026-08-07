extends Node
## GameConfig
## Singleton (autoload) com todos os parâmetros de tuning do jogo.
## Ajuste os valores abaixo (ou pelo Inspector, se abrir esta cena como Autoload
## em Project > Project Settings > Autoload) para alterar a dificuldade sem
## precisar tocar em nenhuma outra lógica do jogo.

## --- Condição de vitória ---
@export var target_score: int = 5

## --- Máquinas ---
@export var machine_fire_rate: float = 1.75          # segundos entre disparos de cada máquina
@export var machine_respawn_time_min: float = 1.0    # segundos
@export var machine_respawn_time_max: float = 3.0    # segundos
@export var machine_move_speed: float = 1.0          # velocidade do movimento lateral (rad/s do seno)
@export var machine_move_range: float = 4.0          # amplitude do trajeto na parede (metros)

## --- Projéteis ---
@export var projectile_speed: float = 8.0            # velocidade do projétil disparado pela máquina
@export var projectile_speed_ricochet: float = 10.0   # velocidade do projétil após o parry
@export var projectile_lifetime: float = 6.0          # segurança: destrói projétil "perdido" após N segundos

## --- Parry / Stun (players) ---
@export var parry_window: float = 0.25    # duração da janela de parry, em segundos
@export var parry_cooldown: float = 0.4   # tempo mínimo entre dois parries
@export var stun_duration: float = 1.2    # duração do stun ao ser atingido sem parry

## --- Movimento do player ---
@export var player_move_speed: float = 6.0
@export var player_gravity: float = 18.0
