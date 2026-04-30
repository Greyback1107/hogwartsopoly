# autoloads/GameState.gd
# Singleton global — existe durante toda la vida del juego.
# Accesible desde cualquier script con GameState.nombre_variable
extends Node

# ── Estado general ────────────────────────────────────────────────
var game_phase: String = "menu"   # "menu" | "setup" | "playing" | "editor" | "game_over"
var current_player_index: int = 0
var turn_count: int = 0
var go_salary: int = 20           # Puntos que se cobran al pasar por Salida de Hogwarts

# ── Jugadores ─────────────────────────────────────────────────────
# Cada entrada es un Dictionary con los datos del jugador.
# Se puebla en la pantalla de configuración antes de iniciar la partida.
var players: Array = []

# ── Tablero activo ────────────────────────────────────────────────
# Diccionario cargado desde el JSON (default_board.json u otro personalizado)
var board_data: Dictionary = {}

# ── Casas de Hogwarts disponibles ─────────────────────────────────
const HOUSES: Array = ["Gryffindor", "Hufflepuff", "Ravenclaw", "Slytherin"]

# ── Señales ───────────────────────────────────────────────────────
signal phase_changed(new_phase: String)
signal turn_changed(player_index: int)

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    pass  # Nada que inicializar aún; la configuración ocurre en setup

# ─────────────────────────────────────────────────────────────────
# Cambia la fase del juego y emite la señal correspondiente
func set_phase(new_phase: String) -> void:
    game_phase = new_phase
    phase_changed.emit(new_phase)

# Avanza al siguiente jugador (con wraparound)
func next_turn() -> void:
    current_player_index = (current_player_index + 1) % players.size()
    turn_count += 1
    turn_changed.emit(current_player_index)

# Devuelve el jugador cuyo turno es ahora
func get_current_player() -> Dictionary:
    if players.is_empty():
        return {}
    return players[current_player_index]

# Reinicia el estado para una partida nueva (sin tocar board_data)
func reset_game() -> void:
    current_player_index = 0
    turn_count = 0
    for player in players:
        player.position    = 0
        player.points      = 50
        player.in_jail     = false
        player.jail_turns  = 0
        player.properties  = []
        player.hand_cards  = []
    set_phase("playing")
