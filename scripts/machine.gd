extends Node3D
## Machine
## Máquina inimiga fixada em uma parede. Move-se lateralmente (eixo X local)
## e dispara projéteis periodicamente contra um player escolhido
## aleatoriamente. Ao ser atingida por um projétil RICOCHETEADO (de qualquer
## um dos players), é destruída, atribui ponto ao autor do parry e "nasce"
## de novo após um tempo aleatório (machine_respawn_time_min/max).
##
## REDE: o disparo (Timer + escolha de alvo + spawn do projétil) só roda no
## host — senão cada cliente spawnaria seu próprio projétil "fantasma" e
## duplicaria os tiros. O projétil em si é replicado automaticamente pelo
## MultiplayerSpawner (ver scenes/main.tscn). destroy() é chamado via RPC
## (o host decide, todos executam), então clientes nunca precisam decidir
## isso por conta própria. O balanço/vaivém visual (_process) roda em todo
## mundo, é só cosmético e não depende de rede.

@export var projectile_scene: PackedScene
@export var move_range_override: float = -1.0   # -1 = usa GameConfig.machine_move_range
@export var move_speed_override: float = -1.0    # -1 = usa GameConfig.machine_move_speed

var active: bool = true

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _hitbox: Area3D = $HitBox
@onready var _body_collision: CollisionShape3D = $Body/CollisionShape3D
@onready var _fire_timer: Timer = $FireTimer

var _base_position: Vector3
var _time_alive: float = 0.0

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _ready() -> void:
	_base_position = position
	if _is_authority():
		_fire_timer.wait_time = GameConfig.machine_fire_rate
		_fire_timer.timeout.connect(_on_fire_timer_timeout)
		_fire_timer.start()

func _process(delta: float) -> void:
	if not active:
		return
	_time_alive += delta
	var speed: float = move_speed_override if move_speed_override >= 0.0 else GameConfig.machine_move_speed
	var range_: float = move_range_override if move_range_override >= 0.0 else GameConfig.machine_move_range
	# Movimento em vaivém suave (seno) dentro do range definido, ao longo do
	# eixo X local da máquina (a parede define a orientação do nó pai).
	position.x = _base_position.x + sin(_time_alive * speed) * (range_ * 0.5)

func _on_fire_timer_timeout() -> void:
	# Relê o fire_rate a cada disparo, então ajustar GameConfig em tempo real
	# (ex.: pelo Remote Inspector durante o jogo) já muda a cadência na
	# próxima rodada, sem precisar reiniciar a cena.
	_fire_timer.wait_time = max(0.05, GameConfig.machine_fire_rate)
	if active:
		_fire_at_random_player()

func _fire_at_random_player() -> void:
	if projectile_scene == null:
		push_warning("Machine: projectile_scene não configurado.")
		return

	var players := get_tree().get_nodes_in_group("player_body")
	if players.is_empty():
		return

	var target: Node3D = players[randi() % players.size()]
	var projectile := projectile_scene.instantiate()
	# Adiciona sob current_scene (Main): é o spawn_path configurado no
	# MultiplayerSpawner, então essa instanciação é automaticamente
	# replicada para todos os clientes quando rodando em rede.
	get_tree().current_scene.add_child(projectile)

	var spawn_pos: Vector3 = _hitbox.global_position
	var direction: Vector3 = target.global_position - spawn_pos
	if multiplayer.has_multiplayer_peer():
		projectile.rpc("launch", spawn_pos, direction)
	else:
		projectile.launch(spawn_pos, direction)

## Chamado (via RPC quando em rede) pelo Projectile quando um projétil
## ricocheteado a acerta. by_player_id: id do player autor do parry que
## originou este projétil.
@rpc("any_peer", "call_local", "reliable")
func destroy(by_player_id: int) -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return  # só o host (peer 1) pode autorizar a destruição.
	if not active:
		return
	active = false
	_mesh.visible = false
	_hitbox.set_deferred("monitorable", false)
	_body_collision.set_deferred("disabled", true)

	if by_player_id > 0:
		MatchManager.add_score(by_player_id)

	if _is_authority():
		var respawn_time: float = randf_range(
			GameConfig.machine_respawn_time_min,
			GameConfig.machine_respawn_time_max
		)
		var timer := get_tree().create_timer(respawn_time)
		timer.timeout.connect(_respawn)

func _respawn() -> void:
	if not is_instance_valid(self):
		return
	if multiplayer.has_multiplayer_peer():
		_rpc_respawn.rpc()
	else:
		_rpc_respawn()

@rpc("authority", "call_local", "reliable")
func _rpc_respawn() -> void:
	active = true
	_mesh.visible = true
	_hitbox.set_deferred("monitorable", true)
	_body_collision.set_deferred("disabled", false)
	_time_alive = 0.0
