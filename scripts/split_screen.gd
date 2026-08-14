extends Node3D
## SplitScreen (Main)
## Divide a tela em duas metades verticais, cada uma renderizando a MESMA
## Arena (mesmo World3D) através de uma câmera em terceira pessoa própria —
## uma seguindo o Player1, outra o Player2.

@onready var _arena: Node3D = $Arena
@onready var _viewport_p1: SubViewport = $SplitScreen/Left/SubViewport
@onready var _viewport_p2: SubViewport = $SplitScreen/Right/SubViewport

# Referências para as câmeras dentro dos Viewports
@onready var _cam_p1: Camera3D = $SplitScreen/Left/SubViewport/ChaseCamera
@onready var _cam_p2: Camera3D = $SplitScreen/Right/SubViewport/ChaseCamera

func _ready() -> void:
	var shared_world: World3D = _arena.get_world_3d()
	_viewport_p1.world_3d = shared_world
	_viewport_p2.world_3d = shared_world

	_update_viewport_sizes()
	get_tree().root.size_changed.connect(_update_viewport_sizes)

	# Injeta a câmera correspondente em cada player
	_assign_cameras_to_players()
	
func _assign_cameras_to_players() -> void:
	var cam_p1: Camera3D = $SplitScreen/Left/SubViewport/ChaseCamera
	var cam_p2: Camera3D = $SplitScreen/Right/SubViewport/ChaseCamera

	# Configura o ID da câmera explicitamente
	if "player_id" in cam_p1:
		cam_p1.player_id = 1
	if "player_id" in cam_p2:
		cam_p2.player_id = 2

	# Encontra os players dentro da Arena
	for node in _arena.get_children():
		if "player_id" in node:
			if node.player_id == 1:
				node.camera = cam_p1
			elif node.player_id == 2:
				node.camera = cam_p2

func _setup_player_cameras() -> void:
	# Procura por todos os nós de Player presentes na cena da Arena
	var players := _arena.find_children("", "CharacterBody3D", true, false)
	
	for node in players:
		# Verifica se o nó encontrado possui a propriedade 'player_id' do nosso script player.gd
		if "player_id" in node:
			if node.player_id == 1:
				node.camera = _cam_p1
			elif node.player_id == 2:
				node.camera = _cam_p2

func _update_viewport_sizes() -> void:
	var window_size: Vector2i = get_tree().root.size
	var half_size := Vector2i(window_size.x / 2, window_size.y)
	_viewport_p1.size = half_size
	_viewport_p2.size = half_size
