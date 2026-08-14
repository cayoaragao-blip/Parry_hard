extends Area3D
class_name Projectile
## Projectile
## Projétil disparado pelas máquinas. Dois estados:
## - FLYING: voando em direção a um player (disparo original da máquina).
## - RICOCHETED: voando após um parry bem-sucedido; pode acertar QUALQUER
##   uma das duas máquinas (não necessariamente a que disparou).
##
## Colisões:
## - Parede (grupo "wall")             -> destrói o projétil, sempre.
## - Player (grupo "player"), sem parry -> aplica stun no player, destrói o projétil.
## - Player (grupo "player"), com parry -> vira RICOCHETED, redireciona velocidade.
## - Máquina (grupo "machine_hitbox"), só se RICOCHETED -> destrói a máquina,
##   atribui ponto ao autor do parry, destrói o projétil.
##
## REDE: cada peer roda sua própria física local (a posição do projétil
## avança de forma determinística a partir de launch(), então não precisa
## ficar sincronizando posição a cada frame). Mas a RESOLUÇÃO da colisão —
## quem acertou quem, quem deu parry, o que morre — é decidida SÓ pelo host
## (_is_authority). O host então avisa todos os peers via RPC para que os
## efeitos (stun, flash de parry, destruição da máquina, remoção do
## projétil) aconteçam de forma idêntica em todas as máquinas.

enum State { FLYING, RICOCHETED }

var state: State = State.FLYING
var velocity: Vector3 = Vector3.ZERO
var parried_by_player_id: int = -1

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	# Segurança: se por algum motivo o projétil não colidir com nada
	# (ex.: saiu da área jogável), ele é destruído após um tempo.
	get_tree().create_timer(GameConfig.projectile_lifetime).timeout.connect(
		func():
			if is_instance_valid(self) and _is_authority():
				_free_networked()
	)

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

## Chamado pelo host logo após instanciar (via RPC quando em rede, ou
## diretamente em modo offline). Define a posição inicial e a velocidade —
## a partir daqui cada peer integra o movimento localmente e de forma
## determinística, sem precisar de sync contínuo de posição.
@rpc("authority", "call_local", "reliable")
func launch(from_position: Vector3, direction: Vector3) -> void:
	global_position = from_position
	var dir := direction
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	velocity = dir.normalized() * GameConfig.projectile_speed
	state = State.FLYING

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if not _is_authority():
		return
	if body.is_in_group("wall"):
		_free_networked()

func _on_area_entered(area: Area3D) -> void:
	if not _is_authority():
		return
	if area.is_in_group("player"):
		_handle_player_contact(area)
	elif area.is_in_group("machine_hitbox"):
		_handle_machine_contact(area)

func _handle_player_contact(player_hurtbox: Area3D) -> void:
	var player := player_hurtbox.get_parent()
	if player == null or not player.has_method("get_hit"):
		return

	if player.is_parrying:
		var by_player_id: int = player.player_id
		# Redireciona na direção para a qual o player está apontando (forward).
		# Assim o projétil pode ir para qualquer uma das duas máquinas,
		# dependendo de para onde o player estiver de frente no momento do parry.
		var forward: Vector3 = -player.global_transform.basis.z
		var new_velocity: Vector3 = forward.normalized() * GameConfig.projectile_speed_ricochet
		_ricochet_networked(new_velocity, by_player_id)
		_call_networked(player, "on_successful_parry")
	else:
		_call_networked(player, "get_hit")
		_free_networked()

func _handle_machine_contact(machine_hitbox: Area3D) -> void:
	if state != State.RICOCHETED:
		# Projétil ainda voando (não ricocheteado) não destrói máquinas —
		# evita que a máquina se autodestrua com o próprio disparo.
		return

	var machine := machine_hitbox.get_parent()
	if machine == null or not machine.has_method("destroy"):
		return

	_call_networked(machine, "destroy", [parried_by_player_id])
	_free_networked()

## --- Helpers de replicação (host chama a versão em rede; offline chama direto) ---

func _call_networked(node: Node, method: String, args: Array = []) -> void:
	if multiplayer.has_multiplayer_peer():
		# GDScript não tem "*args" (isso é Python) — para chamar rpc() com uma
		# lista de argumentos dinâmica, usamos callv() para invocar o método
		# vararg `rpc` embutido de Node, passando [method] + args como lista.
		node.callv("rpc", [method] + args)
	else:
		node.callv(method, args)

func _ricochet_networked(new_velocity: Vector3, by_player_id: int) -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_ricochet.rpc(new_velocity, by_player_id)
	else:
		_rpc_ricochet(new_velocity, by_player_id)

func _free_networked() -> void:
	if multiplayer.has_multiplayer_peer():
		_rpc_free.rpc()
	else:
		_rpc_free()

@rpc("authority", "call_local", "reliable")
func _rpc_ricochet(new_velocity: Vector3, by_player_id: int) -> void:
	state = State.RICOCHETED
	velocity = new_velocity
	parried_by_player_id = by_player_id

@rpc("authority", "call_local", "reliable")
func _rpc_free() -> void:
	if is_instance_valid(self):
		queue_free()
