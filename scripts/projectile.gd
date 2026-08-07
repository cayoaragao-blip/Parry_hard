extends Area3D
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
			if is_instance_valid(self):
				queue_free()
	)

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
	if body.is_in_group("wall"):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("player"):
		_handle_player_contact(area)
	elif area.is_in_group("machine_hitbox"):
		_handle_machine_contact(area)

func _handle_player_contact(player_hurtbox: Area3D) -> void:
	var player := player_hurtbox.get_parent()
	if player == null or not player.has_method("get_hit"):
		return

	if player.is_parrying:
		state = State.RICOCHETED
		parried_by_player_id = player.player_id
		# Redireciona na direção para a qual o player está apontando (forward).
		# Assim o projétil pode ir para qualquer uma das duas máquinas,
		# dependendo de para onde o player estiver de frente no momento do parry.
		var forward: Vector3 = -player.global_transform.basis.z
		velocity = forward.normalized() * GameConfig.projectile_speed_ricochet
		player.on_successful_parry()
	else:
		player.get_hit()
		queue_free()

func _handle_machine_contact(machine_hitbox: Area3D) -> void:
	if state != State.RICOCHETED:
		# Projétil ainda voando (não ricocheteado) não destrói máquinas —
		# evita que a máquina se autodestrua com o próprio disparo.
		return

	var machine := machine_hitbox.get_parent()
	if machine == null or not machine.has_method("destroy"):
		return

	machine.destroy(parried_by_player_id)
	queue_free()
