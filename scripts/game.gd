extends Node3D
## Game (raiz de scenes/main.tscn)
## Prepara a partida assim que ela deve começar: define quem controla cada
## Player (humano local, humano remoto ou bot) e cria a ÚNICA câmera em 3ª
## pessoa deste cliente, apontada para o player que ESTE peer controla.
## Substitui o antigo esquema de tela dividida — não há mais SubViewports
## nem duas câmeras simultâneas: cada máquina roda sua própria janela em
## tela cheia, terceira pessoa, do seu próprio player.

const ChaseCameraScene: PackedScene = preload("res://scenes/chase_camera.tscn")

@onready var _arena: Node3D = $Arena
@onready var _player1: CharacterBody3D = $Arena/Player1
@onready var _player2: CharacterBody3D = $Arena/Player2

func _ready() -> void:
	if Net.is_online and not Net.is_host:
		# Cliente: aguarda o host avisar (via RPC) que a partida deve
		# começar — só ele sabe se vai ser 2 humanos ou humano + bot.
		Net.match_started.connect(_start_match)
	else:
		# Host (online ou offline) já pode montar a partida imediatamente.
		_start_match()

func _start_match() -> void:
	_configure_authority()
	_spawn_local_camera()

func _configure_authority() -> void:
	const HOST_PEER_ID := 1
	_player1.set_multiplayer_authority(HOST_PEER_ID)

	if Net.player2_is_bot():
		_player2.set_multiplayer_authority(HOST_PEER_ID)
		_player2.bot_controlled = Net.is_host
	else:
		var player2_peer_id: int = Net.player2_peer_id if Net.player2_peer_id > 0 else HOST_PEER_ID
		_player2.set_multiplayer_authority(player2_peer_id)
		_player2.bot_controlled = false

func _spawn_local_camera() -> void:
	var local_player: CharacterBody3D = _player1 if Net.local_player_id == 1 else _player2
	var camera: Camera3D = ChaseCameraScene.instantiate()
	add_child(camera)
	camera.set_target(local_player)
	local_player.camera = camera
