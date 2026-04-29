# scripts/player.gd
# Representa a un jugador en el tablero.
# Sus datos se sincronizan con el Dictionary en GameState.players[i].
extends Node

# ── Datos del jugador ─────────────────────────────────────────────
var player_name:  String  = ""
var house:        String  = ""       # "Gryffindor" | "Hufflepuff" | "Ravenclaw" | "Slytherin"
var token:        String  = ""       # Nombre del token elegido
var points:       int     = 0        # Puntos de casa (equivalente al dinero)
var tile_position:     int     = 0        # Casilla actual (0–39)
var in_jail:      bool    = false
var jail_turns:   int     = 0        # Turnos que lleva en Azkaban
var consecutive_doubles: int = 0     # Dobles consecutivos (3 = Azkaban)

var properties:   Array   = []       # Array de Dictionaries con las propiedades compradas
var hand_cards:   Array   = []       # Cartas guardadas (keep: true)

# ── Señales ───────────────────────────────────────────────────────
signal moved(new_position: int, passed_go: bool)
signal points_changed(new_total: int)
signal sent_to_jail
signal released_from_jail

# ─────────────────────────────────────────────────────────────────
func setup(data: Dictionary) -> void:
    player_name = data.get("name",  "Jugador")
    house       = data.get("house", "Gryffindor")
    token       = data.get("token", "varita")
    points      = data.get("points", 0)
    tile_position    = data.get("position", 0)

# ── Movimiento ────────────────────────────────────────────────────
func move(steps: int) -> void:
    var board_size: int = GameState.board_data.get("tiles", []).size()
    if board_size == 0:
        board_size = 40
    var old_position = tile_position
    tile_position = (tile_position + steps) % board_size

    # Detecta si pasó por la casilla de Salida (id 0)
    var passed_go: bool = (steps > 0) and (tile_position < old_position or old_position + steps >= board_size)
    if passed_go:
        gain_points(GameState.go_salary)

    AudioManager.play_sfx("piece_move")
    moved.emit(tile_position, passed_go)

func move_to(tile_id: int, collect_go: bool = true) -> void:
    var board_size: int = GameState.board_data.get("tiles", []).size()
    if board_size == 0:
        board_size = 40
    var passed_go: bool = collect_go and (tile_id <= tile_position) and (tile_id != 0)
    if passed_go:
        gain_points(GameState.go_salary)
    tile_position = tile_id
    AudioManager.play_sfx("piece_move")
    moved.emit(tile_position, passed_go)

# ── Puntos ────────────────────────────────────────────────────────
func gain_points(amount: int) -> void:
    points += amount
    _sync_to_gamestate()
    points_changed.emit(points)

func lose_points(amount: int) -> void:
    points -= amount
    _sync_to_gamestate()
    points_changed.emit(points)

func _sync_to_gamestate() -> void:
    # Actualiza el Dictionary de GameState para que el HUD lo refleje
    for p in GameState.players:
        if p.get("name", "") == player_name:
            p["points"] = points
            break

func is_bankrupt() -> bool:
    return points < 0

# ── Azkaban ───────────────────────────────────────────────────────
func go_to_jail() -> void:
    in_jail   = true
    jail_turns = 0
    tile_position  = 10         # id de la casilla de Azkaban
    consecutive_doubles = 0
    sent_to_jail.emit()
    AudioManager.play_sfx("go_to_jail")

func release_from_jail() -> void:
    in_jail    = false
    jail_turns = 0
    released_from_jail.emit()

# ── Propiedades ───────────────────────────────────────────────────
func buy_property(tile_data: Dictionary) -> void:
    lose_points(int(tile_data.get("price", 0)))
    var owned = {
        "id":       int(tile_data.get("id", -1)),
        "name":     tile_data.get("name", ""),
        "type":     tile_data.get("type", "property"),
        "group":    tile_data.get("color_group", ""),
        "shields":  0,
        "mortgaged": false,
    }
    properties.append(owned)
    AudioManager.play_sfx("buy_property")

func add_shield_to(tile_id: int) -> void:
    for prop in properties:
        if prop.id == tile_id:
            prop.shields += 1
            return

func owns_tile(tile_id: int) -> bool:
    for prop in properties:
        if prop.get("id", -1) == tile_id:
            return true
    return false

func owns_complete_group(color_group: String) -> bool:
    var board_tiles: Array = GameState.board_data.get("tiles", [])
    var group_tiles = board_tiles.filter(func(t): return t.get("color_group", "") == color_group)
    for t in group_tiles:
        if not owns_tile(t.id):
            return false
    return group_tiles.size() > 0

# ── Cartas en mano ────────────────────────────────────────────────
func add_card(card: Dictionary) -> void:
    hand_cards.append(card)

func remove_card(card_id: String) -> void:
    hand_cards = hand_cards.filter(func(c): return c.get("id", "") != card_id)

func has_get_out_of_jail() -> bool:
    for card in hand_cards:
        if card.get("effect", {}).get("action", "") == "get_out_of_jail_free":
            return true
    return false

# ── Serialización (para guardar partida) ──────────────────────────
func to_dict() -> Dictionary:
    return {
        "name":       player_name,
        "house":      house,
        "token":      token,
        "points":     points,
        "position":   tile_position,
        "in_jail":    in_jail,
        "jail_turns": jail_turns,
        "properties": properties,
        "hand_cards": hand_cards,
    }
