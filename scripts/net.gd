extends Node
## Net (autoload)
## Camada fina sobre o multiplayer de alto nível do Godot (ENet). No máximo
## 2 jogadores humanos por partida — cada um na sua própria máquina. O host
## é sempre o peer ENet de id 1 e sempre controla player_id 1; o segundo
## humano que conectar vira player_id 2. Se ninguém mais entrar, o host tem
## a opção de começar sozinho contra um Bot, que roda inteiramente na
## máquina do host (ver player.gd -> bot_controlled).
##
## IMPORTANTE (setup do projeto): registre este script como autoload
## chamado "Net" em Project Settings -> Autoload (veja instruções no chat).

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal match_started

const DEFAULT_PORT: int = 8910
const MAX_PLAYERS: int = 2

var is_host: bool = false
var is_online: bool = false
var local_player_id: int = 1

## peer_id (ENet) do segundo humano, se/quando conectar. -1 = ninguém ainda.
var player2_peer_id: int = -1
## true quando o host optou por preencher a vaga do player 2 com IA.
var bot_fills_player2: bool = false

func host_game(port: int = DEFAULT_PORT) -> Error:
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		push_warning("Net: falha ao criar servidor (erro %d)." % err)
		return err
	multiplayer.multiplayer_peer = enet
	is_host = true
	is_online = true
	local_player_id = 1
	player2_peer_id = -1
	bot_fills_player2 = false
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK

func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_client(address, port)
	if err != OK:
		push_warning("Net: falha ao conectar em %s (erro %d)." % [address, err])
		return err
	multiplayer.multiplayer_peer = enet
	is_host = false
	is_online = true
	local_player_id = 2
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK

## Modo local sem rede nenhuma, útil pra testar rapidamente sem passar pelo
## lobby (roda direto sozinho contra o bot).
func play_offline_vs_bot() -> void:
	is_host = true
	is_online = false
	local_player_id = 1
	bot_fills_player2 = true

## Chamado pelo host quando um segundo humano conecta e a partida deve
## começar com os dois jogadores humanos.
func start_match_two_players() -> void:
	if not is_host:
		return
	bot_fills_player2 = false
	_rpc_start.rpc()

## Chamado pelo host quando ninguém mais entrou e ele decide jogar contra
## um bot mesmo assim.
func start_match_with_bot() -> void:
	if not is_host:
		return
	bot_fills_player2 = true
	_rpc_start.rpc()

func player2_is_bot() -> bool:
	return bot_fills_player2

func has_second_human() -> bool:
	return player2_peer_id > 0

func _on_peer_connected(id: int) -> void:
	if is_host and player2_peer_id == -1:
		player2_peer_id = id
		_rpc_set_player2_peer.rpc(id)
	player_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if id == player2_peer_id:
		player2_peer_id = -1
	player_left.emit(id)

func _on_connection_failed() -> void:
	push_warning("Net: conexão falhou.")
	is_online = false

func _on_server_disconnected() -> void:
	push_warning("Net: o host desconectou.")
	is_online = false

@rpc("authority", "call_local", "reliable")
func _rpc_set_player2_peer(id: int) -> void:
	player2_peer_id = id

@rpc("authority", "call_local", "reliable")
func _rpc_start() -> void:
	match_started.emit()
