extends CanvasLayer
## Scoreboard
## HUD simples: mostra a pontuação dos dois players e uma mensagem de
## vitória/sudden death. Puramente reativo aos sinais do MatchManager.

@onready var _label_p1: Label = $Root/TopBar/Player1Score
@onready var _label_p2: Label = $Root/TopBar/Player2Score
@onready var _label_status: Label = $Root/StatusLabel

func _ready() -> void:
	MatchManager.score_changed.connect(_on_score_changed)
	MatchManager.match_won.connect(_on_match_won)
	MatchManager.match_reset.connect(_on_match_reset)
	_refresh_scores()
	_label_status.visible = false

func _on_score_changed(_player_id: int, _new_score: int) -> void:
	_refresh_scores()
	if MatchManager.sudden_death and not MatchManager.game_over:
		_label_status.text = "EMPATE! Sudden death — próxima máquina destruída vence."
		_label_status.visible = true

func _on_match_won(player_id: int) -> void:
	_label_status.text = "Player %d venceu a partida!" % player_id
	_label_status.visible = true

func _on_match_reset() -> void:
	_refresh_scores()
	_label_status.visible = false

func _refresh_scores() -> void:
	_label_p1.text = "Player 1: %d / %d" % [MatchManager.scores[1], GameConfig.target_score]
	_label_p2.text = "Player 2: %d / %d" % [MatchManager.scores[2], GameConfig.target_score]
