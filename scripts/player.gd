extends CharacterBody3D
## Player
## Personagem em terceira pessoa clássico: a câmera (ver chase_camera.gd) é
## o referencial de movimento E de orientação — o personagem sempre gira
## para acompanhar o yaw da câmera, e o input WASD move em relação a essa
## orientação (não em relação aos eixos do mundo).
##
## REDE: cada humano controla exatamente 1 destes nós — o que tiver
## multiplayer_authority igual ao peer local (ver Net.gd e scripts/game.gd,
## que fazem essa atribuição quando a partida começa). O outro Player só
## existe aqui como réplica: seu transform e estado (is_stunned/is_parrying)
## chegam prontos via MultiplayerSynchronizer, e este script não roda
## física nem lê input para ele — ver _is_locally_simulated().
##
## Quando não há um segundo humano, o host marca `bot_controlled = true` no
## Player2 e uma IA simples assume o controle (rodando também só no host,
## que nesse caso é quem tem autoridade sobre ele).

@export var player_id: int = 1
@export var body_color: Color = Color.WHITE
## Câmera em 3ª pessoa deste cliente. Atribuída em tempo de execução por
## scripts/game.gd — só existe/importa para o player LOCAL (humano).
@export var camera: Camera3D
## true somente na cópia HOST de um Player sem dono humano.
@export var bot_controlled: bool = false

var is_parrying: bool = false
var is_stunned: bool = false

var _parry_timer: float = 0.0
var _parry_cooldown_timer: float = 0.0
var _stun_timer: float = 0.0

## Feedback visual de stun: o corpo pisca (troca de cor) e o indicador
## giratório acima da cabeça fica visível enquanto is_stunned == true. Roda
## em TODO peer (dono ou não), pois só depende de `is_stunned`, que chega
## sincronizado nos players remotos.
const STUN_BLINK_INTERVAL: float = 0.1
const STUN_INDICATOR_SPIN_SPEED: float = 4.5
var _stun_blink_timer: float = 0.0
var _stun_blink_on: bool = false

## --- Parâmetros da IA do bot ---
const BOT_WANDER_RADIUS: float = 6.0
const BOT_REACT_DISTANCE: float = 7.0
const BOT_PARRY_REACTION: float = 0.18
const BOT_ARENA_BOUND: float = 9.0

var _bot_wander_target: Vector3
var _bot_repick_timer: float = 0.0
var _bot_parry_delay: float = 0.0
var _bot_incoming_projectile: Projectile = null

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _parry_flash: MeshInstance3D = $ParryFlash
@onready var _stun_indicator: MeshInstance3D = $StunIndicator

var _body_material: StandardMaterial3D
var _stun_material: StandardMaterial3D

func _ready() -> void:
	_apply_color()
	_parry_flash.visible = false
	_stun_indicator.visible = false
	_bot_wander_target = global_position

func _apply_color() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = body_color
	_mesh.material_override = _body_material

	# Material "apagado"/acinzentado usado no piscar durante o stun, para
	# diferenciar claramente do estado normal e do parry (flash amarelo).
	_stun_material = StandardMaterial3D.new()
	_stun_material.albedo_color = body_color.darkened(0.6)
	_stun_material.emission_enabled = true
	_stun_material.emission = Color(0.9, 0.85, 0.1)
	_stun_material.emission_energy_multiplier = 0.8

## Só quem tem autoridade sobre este nó roda física/IA/input. Nos demais
## peers, o transform e o estado já chegam prontos via
## MultiplayerSynchronizer — eles só precisam ser exibidos.
func _is_locally_simulated() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()

func _physics_process(delta: float) -> void:
	if not _is_locally_simulated():
		return

	_update_timers(delta)

	if is_stunned:
		# Enquanto stunado, o player não responde a input; apenas aplica
		# gravidade e desliza até parar.
		velocity.x = move_toward(velocity.x, 0.0, GameConfig.player_move_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, GameConfig.player_move_speed * delta * 4.0)
		_apply_gravity(delta)
		move_and_slide()
		return

	var move_input: Vector2
	var wants_parry: bool
	var look_yaw: float

	if bot_controlled:
		var decision := _bot_decide(delta)
		move_input = decision.move
		wants_parry = decision.parry
		look_yaw = decision.look_yaw
	else:
		move_input = _read_human_move_input()
		wants_parry = Input.is_action_just_pressed("parry")
		# O personagem SEMPRE olha para onde a câmera olha (yaw), mesmo
		# parado — é o que faz o controle parecer um TPS clássico.
		look_yaw = camera.global_transform.basis.get_euler().y if camera and is_instance_valid(camera) else rotation.y

	rotation.y = look_yaw
	_apply_movement(move_input)

	if wants_parry and _parry_cooldown_timer <= 0.0 and not is_parrying:
		_start_parry()

	_apply_gravity(delta)
	move_and_slide()

func _process(delta: float) -> void:
	if is_stunned:
		_update_stun_visual(delta)
	elif _stun_indicator.visible:
		_reset_stun_visual()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GameConfig.player_gravity * delta
	else:
		velocity.y = 0.0

func _read_human_move_input() -> Vector2:
	var input_dir := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	if Input.is_action_pressed("move_forward"):
		input_dir.y -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.y += 1.0
	return input_dir

## input_dir.x = direita/esquerda, input_dir.y = trás/frente (negativo é
## "pra frente"), sempre relativo à orientação ATUAL do personagem — que já
## foi alinhada à câmera (ou à decisão do bot) neste mesmo frame, antes
## desta chamada.
func _apply_movement(input_dir: Vector2) -> void:
	if input_dir.length_squared() > 0.01:
		input_dir = input_dir.normalized()
		var forward := -global_transform.basis.z
		var right := global_transform.basis.x
		var move_dir := (right * input_dir.x) + (forward * -input_dir.y)
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * GameConfig.player_move_speed
		velocity.z = move_dir.z * GameConfig.player_move_speed
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _start_parry() -> void:
	is_parrying = true
	_parry_timer = GameConfig.parry_window
	_parry_cooldown_timer = GameConfig.parry_cooldown
	_parry_flash.visible = true

func _update_timers(delta: float) -> void:
	if is_parrying:
		_parry_timer -= delta
		if _parry_timer <= 0.0:
			is_parrying = false
			_parry_flash.visible = false

	if _parry_cooldown_timer > 0.0:
		_parry_cooldown_timer -= delta

	if is_stunned:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			is_stunned = false

func _update_stun_visual(delta: float) -> void:
	_stun_indicator.visible = true
	_stun_indicator.rotate_y(STUN_INDICATOR_SPIN_SPEED * delta)

	_stun_blink_timer -= delta
	if _stun_blink_timer <= 0.0:
		_stun_blink_timer = STUN_BLINK_INTERVAL
		_stun_blink_on = not _stun_blink_on
		_mesh.material_override = _stun_material if _stun_blink_on else _body_material

func _reset_stun_visual() -> void:
	_stun_indicator.visible = false
	_mesh.material_override = _body_material
	_stun_blink_timer = 0.0
	_stun_blink_on = false

## A resolução de colisão é autoritativa no host (ver projectile.gd), que
## chama estas funções via RPC em todos os peers. `any_peer` é necessário
## porque a autoridade DESTE nó normalmente pertence ao jogador dono dele
## (não ao host) — por isso validamos manualmente quem pode chamar.
@rpc("any_peer", "call_local", "reliable")
func get_hit() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	is_stunned = true
	_stun_timer = GameConfig.stun_duration
	is_parrying = false
	_parry_flash.visible = false
	_stun_blink_timer = 0.0
	_stun_blink_on = false

@rpc("any_peer", "call_local", "reliable")
func on_successful_parry() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	pass

## ============================== IA do bot ==============================
## Simples e honesta: quando não há projétil ameaçador por perto, o bot
## perambula pela arena; quando um projétil se aproxima na sua direção,
## ele para, encara a ameaça e tenta cronometrar um parry (com uma margem
## de "reação" para não parecer sobre-humano).

func _yaw_facing(direction: Vector3) -> float:
	if direction.length_squared() < 0.0001:
		return rotation.y
	return Basis.looking_at(direction, Vector3.UP).get_euler().y

func _bot_decide(delta: float) -> Dictionary:
	_bot_scan_for_threats()

	if _bot_parry_delay > 0.0:
		_bot_parry_delay -= delta

	if is_instance_valid(_bot_incoming_projectile):
		var to_threat: Vector3 = _bot_incoming_projectile.global_position - global_position
		var dist: float = to_threat.length()
		var speed: float = maxf(GameConfig.projectile_speed, 0.01)
		var eta: float = dist / speed

		var wants_parry := false
		if _bot_parry_delay <= 0.0 and eta <= (GameConfig.parry_window + BOT_PARRY_REACTION):
			wants_parry = true
			_bot_parry_delay = 0.6

		return {
			"move": Vector2.ZERO,
			"parry": wants_parry,
			"look_yaw": _yaw_facing(to_threat),
		}

	var target := _bot_pick_wander_target(delta)
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	var moving: bool = to_target.length() > 0.4

	return {
		"move": Vector2(0.0, -1.0) if moving else Vector2.ZERO,
		"parry": false,
		"look_yaw": _yaw_facing(to_target) if moving else rotation.y,
	}

func _bot_scan_for_threats() -> void:
	_bot_incoming_projectile = null
	var best_eta := INF
	for node in get_tree().get_nodes_in_group("projectile"):
		if not (node is Projectile) or node.state != Projectile.State.FLYING:
			continue
		var to_me: Vector3 = global_position - node.global_position
		var dist: float = to_me.length()
		if dist > BOT_REACT_DISTANCE or dist < 0.01:
			continue
		var vel: Vector3 = node.velocity
		var speed: float = vel.length()
		if speed < 0.01:
			continue
		var closing: float = vel.normalized().dot(to_me.normalized())
		if closing <= 0.3:
			continue  # não está vindo na nossa direção
		var eta: float = dist / speed
		if eta < best_eta:
			best_eta = eta
			_bot_incoming_projectile = node

func _bot_pick_wander_target(delta: float) -> Vector3:
	_bot_repick_timer -= delta
	if _bot_repick_timer <= 0.0 or global_position.distance_to(_bot_wander_target) < 0.6:
		_bot_repick_timer = randf_range(1.5, 3.5)
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(1.5, BOT_WANDER_RADIUS)
		var candidate := global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
		candidate.x = clamp(candidate.x, -BOT_ARENA_BOUND, BOT_ARENA_BOUND)
		candidate.z = clamp(candidate.z, -BOT_ARENA_BOUND, BOT_ARENA_BOUND)
		candidate.y = global_position.y
		_bot_wander_target = candidate
	return _bot_wander_target
