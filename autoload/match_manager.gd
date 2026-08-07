extends Node
## MatchManager
## Singleton (autoload) responsável pela pontuação, condição de vitória e
## pela regra de sudden death (empate na mesma pontuação-alvo).

signal score_changed(player_id: int, new_score: int)
signal match_won(player_id: int)
signal match_reset

var scores: Dictionary = {1: 0, 2: 0}
var game_over: bool = false
var sudden_death: bool = false

var _pending_check: bool = false

func _process(_delta: float) -> void:
	# Processamos a checagem de vitória uma única vez por frame, mesmo que
	# duas máquinas tenham sido destruídas no mesmo frame (por exemplo, dois
	# projéteis diferentes acertando as duas máquinas ao mesmo tempo). Isso
	# garante que um empate "no mesmo instante" seja detectado corretamente
	# em vez de declarar vencedor prematuramente com base em qual sinal
	# chegou primeiro.
	if _pending_check:
		_pending_check = false
		_check_win_condition()

func add_score(player_id: int) -> void:
	if game_over:
		return
	if not scores.has(player_id):
		push_warning("MatchManager.add_score: player_id inválido: %s" % str(player_id))
		return
	scores[player_id] += 1
	score_changed.emit(player_id, scores[player_id])
	_pending_check = true

func reset_match() -> void:
	scores = {1: 0, 2: 0}
	game_over = false
	sudden_death = false
	_pending_check = false
	match_reset.emit()

func _check_win_condition() -> void:
	if game_over:
		return

	var target: int = GameConfig.target_score
	var p1: int = scores[1]
	var p2: int = scores[2]

	if sudden_death:
		# Em sudden death, o primeiro a ficar na frente vence imediatamente.
		if p1 > p2:
			_declare_winner(1)
		elif p2 > p1:
			_declare_winner(2)
		# Se continuarem empatados, a partida simplesmente prossegue.
		return

	var p1_reached: bool = p1 >= target
	var p2_reached: bool = p2 >= target

	if p1_reached and p2_reached:
		# Empate exatamente na pontuação-alvo -> entra em sudden death.
		sudden_death = true
		return
	elif p1_reached:
		_declare_winner(1)
	elif p2_reached:
		_declare_winner(2)

func _declare_winner(player_id: int) -> void:
	game_over = true
	match_won.emit(player_id)
