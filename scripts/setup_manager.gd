# autoloads/SetupManager... NO — scripts/setup_manager.gd
# Lógica pura del setup. Sin UI.
extends Node

const TOKENS: Array = [
    {"id": "locomotora",  "name": "Expreso de Hogwarts"},
    {"id": "noctambulo",  "name": "Autobús Noctámbulo"},
    {"id": "hagrid_moto", "name": "Moto de Hagrid"},
    {"id": "saeta",       "name": "Saeta de Fuego"},
    {"id": "hipogrifo",   "name": "Hipogrifo"},
    {"id": "thestral",    "name": "Thestral"},
]

var total_players:      int    = 2
var current_player_idx: int    = 0
var configured_players: Array  = []
var selected_board_path: String = "res://data/default_board.json"
var taken_tokens:        Array  = []

signal setup_step_changed(step: int)
signal player_slot_ready(player_data: Dictionary, slot_index: int)
signal setup_complete(players: Array, board_path: String)

func _ready() -> void:
    pass

func reset() -> void:
    total_players       = 2
    current_player_idx  = 0
    configured_players.clear()
    taken_tokens.clear()
    selected_board_path = "res://data/default_board.json"

func set_total_players(n: int) -> void:
    total_players      = clamp(n, 2, 6)
    current_player_idx = 0
    configured_players.clear()
    taken_tokens.clear()
    emit_signal("setup_step_changed", 2)

func confirm_player(player_name: String, house: String, token_id: String) -> void:
    if player_name.strip_edges() == "":
        push_warning("SetupManager: nombre vacío")
        return
    if house not in GameState.HOUSES:
        push_warning("SetupManager: casa inválida")
        return

    var player_data: Dictionary = {
        "name":       player_name.strip_edges(),
        "house":      house,
        "token":      token_id,
        "points":     50,
        "position":   0,
        "in_jail":    false,
        "jail_turns": 0,
        "properties": [],
        "hand_cards": [],
    }
    configured_players.append(player_data)
    taken_tokens.append(token_id)
    current_player_idx += 1
    emit_signal("player_slot_ready", player_data, current_player_idx - 1)

    if current_player_idx >= total_players:
        emit_signal("setup_step_changed", 3)
    else:
        emit_signal("setup_step_changed", 2)

func select_board(path: String) -> void:
    selected_board_path = path
    emit_signal("setup_step_changed", 4)

func use_default_board() -> void:
    select_board("res://data/default_board.json")

func confirm_setup() -> void:
    var board_data = SaveSystem.load_board(selected_board_path)
    if board_data.is_empty():
        push_error("SetupManager: no se pudo cargar el tablero")
        return
    GameState.board_data = board_data
    GameState.players    = configured_players.duplicate(true)
    emit_signal("setup_complete", configured_players, selected_board_path)

func undo_last_player() -> void:
    if configured_players.is_empty():
        return
    var last = configured_players.pop_back()
    taken_tokens.erase(last.get("token", ""))
    current_player_idx -= 1
    emit_signal("setup_step_changed", 2)

func get_available_tokens() -> Array:
    return TOKENS.filter(func(t): return t.id not in taken_tokens)

func get_current_slot_label() -> String:
    return "Jugador %d de %d" % [current_player_idx + 1, total_players]

func go_back_to_player_count() -> void:
    configured_players.clear()
    taken_tokens.clear()
    current_player_idx = 0
    emit_signal("setup_step_changed", 1)

func go_back_to_player_config() -> void:
    emit_signal("setup_step_changed", 2)
