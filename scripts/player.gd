extends CharacterBody3D
## Player
## Movimento simples em 3D + mecânica de parry + stun ao ser atingido.
## As ações de input usadas são prefixadas por player_id, ex.: "p1_move_forward",
## "p1_parry", "p2_move_forward", "p2_parry" etc. Configure esses InputMaps em
## Project Settings > Input Map (já vêm definidos no project.godot deste projeto).

@export var player_id: int = 1
@export var body_color: Color = Color.WHITE

var is_parrying: bool = false
var is_stunned: bool = false

var _parry_timer: float = 0.0
var _parry_cooldown_timer: float = 0.0
var _stun_timer: float = 0.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _parry_flash: MeshInstance3D = $ParryFlash

func _ready() -> void:
	_apply_color()
	_parry_flash.visible = false

func _apply_color() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	_mesh.material_override = mat

func _physics_process(delta: float) -> void:
	_update_timers(delta)

	if is_stunned:
		# Enquanto stunado, o player não responde a input; apenas aplica
		# gravidade e desliza até parar.
		velocity.x = move_toward(velocity.x, 0.0, GameConfig.player_move_speed * delta * 4.0)
		velocity.z = move_toward(velocity.z, 0.0, GameConfig.player_move_speed * delta * 4.0)
		_apply_gravity(delta)
		move_and_slide()
		return

	_handle_movement_input(delta)
	_handle_parry_input()
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GameConfig.player_gravity * delta
	else:
		velocity.y = 0.0

func _handle_movement_input(_delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed(_action("move_forward")):
		input_dir.z -= 1.0
	if Input.is_action_pressed(_action("move_back")):
		input_dir.z += 1.0
	if Input.is_action_pressed(_action("move_left")):
		input_dir.x -= 1.0
	if Input.is_action_pressed(_action("move_right")):
		input_dir.x += 1.0

	if input_dir.length() > 0.01:
		input_dir = input_dir.normalized()
		velocity.x = input_dir.x * GameConfig.player_move_speed
		velocity.z = input_dir.z * GameConfig.player_move_speed
		# O player vira de frente para a direção do movimento. Essa direção
		# ("para onde o player está apontando") é o que define para qual
		# máquina o projétil vai quando ricocheteado no parry.
		var look_target := global_position + input_dir
		look_at(look_target, Vector3.UP)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

func _handle_parry_input() -> void:
	if Input.is_action_just_pressed(_action("parry")) and _parry_cooldown_timer <= 0.0 and not is_parrying:
		_start_parry()

func _start_parry() -> void:
	is_parrying = true
	_parry_timer = GameConfig.parry_window
	_parry_cooldown_timer = GameConfig.parry_cooldown
	# Feedback visual placeholder (indicador ainda a definir com o time).
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

func _action(base_name: String) -> String:
	return "p%d_%s" % [player_id, base_name]

## Chamado pelo Projectile quando o player NÃO conseguiu dar parry a tempo.
func get_hit() -> void:
	is_stunned = true
	_stun_timer = GameConfig.stun_duration
	is_parrying = false
	_parry_flash.visible = false

## Chamado pelo Projectile quando o parry deu certo (opcional: gancho para
## efeitos sonoros/visuais extras no futuro).
func on_successful_parry() -> void:
	pass
