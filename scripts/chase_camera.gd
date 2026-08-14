extends Camera3D
## ChaseCamera
## Câmera em terceira pessoa clássica: orbita o player com o mouse
## (yaw/pitch) e serve de referencial de movimento — player.gd lê
## `camera.global_transform.basis` a cada frame pra decidir "frente" e
## girar o corpo do personagem (é assim que a orientação do personagem
## acompanha a câmera, como num TPS de verdade).
##
## Existe UMA única instância por cliente — a câmera do jogador LOCAL —
## criada dinamicamente por scripts/game.gd quando a partida começa (ver
## scenes/chase_camera.tscn). Não há mais divisão de tela: cada máquina só
## roda a câmera do seu próprio jogador.
##
## O bug antigo ("câmera não funciona") era a mistura de duas causas: 1) o
## input do mouse só era processado quando `player_id == 1`, então a
## câmera do segundo player nunca recebia movimento nenhum; 2) isso fazia
## sentido apenas no modelo de tela dividida/hot-seat, que não existe mais.
## Agora só existe uma câmera local por cliente, então ela sempre processa
## o próprio mouse, sem nenhuma checagem de player_id.

@export var height: float = 2.0
@export var distance: float = 4.0
@export var mouse_sensitivity: float = 0.0035
@export var min_pitch: float = deg_to_rad(-35.0)
@export var max_pitch: float = deg_to_rad(65.0)
## Margem de segurança para não deixar a câmera atravessar paredes/objetos.
@export var collision_margin: float = 0.3
## Camada de colisão usada no raycast anti-clipping (1 = grupo "wall").
@export_flags_3d_physics var collision_mask: int = 1

var target: Node3D
var yaw: float = 0.0
var pitch: float = deg_to_rad(15.0)

func _ready() -> void:
	set_process_unhandled_input(true)
	_capture_mouse()

## Chamado por scripts/game.gd assim que sabe qual Player este cliente
## controla localmente.
func set_target(node: Node3D) -> void:
	target = node
	if target != null:
		yaw = target.rotation.y
		_update_camera_position()

func _capture_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, min_pitch, max_pitch)
	elif event.is_action_pressed("ui_cancel"):
		# Esc solta o mouse (útil pra alternar de janela); clicar recaptura.
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_capture_mouse()

func _process(_delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	_update_camera_position()

func _update_camera_position() -> void:
	var rotation_quat := Quaternion(Vector3.UP, yaw) * Quaternion(Vector3.RIGHT, pitch)
	var target_center: Vector3 = target.global_position + Vector3.UP * height
	var offset: Vector3 = rotation_quat * Vector3(0.0, 0.0, distance)
	var desired_position: Vector3 = target_center + offset

	# Evita que a câmera atravesse paredes: raycast do personagem até a
	# posição desejada e, se bater em algo antes, aproxima a câmera do ponto
	# de impacto (com uma pequena margem).
	if is_inside_tree():
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(target_center, desired_position)
		query.collision_mask = collision_mask
		if target is CollisionObject3D:
			query.exclude = [target.get_rid()]
		var result := space_state.intersect_ray(query)
		if result:
			var hit_pos: Vector3 = result.position
			var dir_back: Vector3 = (desired_position - target_center).normalized()
			desired_position = hit_pos - dir_back * collision_margin

	global_position = desired_position
	look_at(target_center, Vector3.UP)
