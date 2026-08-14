extends Control
## Lobby
## Menu inicial: hospedar partida, entrar numa partida existente (IP do
## host), ou — se for o host e ninguém mais entrar — começar sozinho contra
## um Bot. Ao iniciar, troca para scenes/main.tscn em todos os peers.

@onready var _address_edit: LineEdit = $CenterContainer/VBox/JoinRow/AddressEdit
@onready var _host_button: Button = $CenterContainer/VBox/HostButton
@onready var _join_button: Button = $CenterContainer/VBox/JoinRow/JoinButton
@onready var _bot_button: Button = $CenterContainer/VBox/BotButton
@onready var _status_label: Label = $CenterContainer/VBox/StatusLabel

func _ready() -> void:
	_bot_button.visible = false
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_bot_button.pressed.connect(_on_bot_pressed)
	Net.player_joined.connect(_on_player_joined)
	Net.match_started.connect(_on_match_started)

func _on_host_pressed() -> void:
	var err := Net.host_game()
	if err != OK:
		_status_label.text = "Não foi possível abrir a porta (erro %d)." % err
		return
	_status_label.text = "Aguardando um segundo jogador conectar...\nOu comece sozinho contra um Bot."
	_host_button.disabled = true
	_join_button.disabled = true
	_address_edit.editable = false
	_bot_button.visible = true

func _on_join_pressed() -> void:
	var address: String = _address_edit.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	var err := Net.join_game(address)
	if err != OK:
		_status_label.text = "Não foi possível conectar a %s (erro %d)." % [address, err]
		return
	_status_label.text = "Conectando a %s..." % address
	_host_button.disabled = true
	_join_button.disabled = true

func _on_bot_pressed() -> void:
	_status_label.text = "Iniciando contra o Bot..."
	_bot_button.disabled = true
	Net.start_match_with_bot()

func _on_player_joined(_peer_id: int) -> void:
	_status_label.text = "Segundo jogador conectado! Iniciando partida..."
	Net.start_match_two_players()

func _on_match_started() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
