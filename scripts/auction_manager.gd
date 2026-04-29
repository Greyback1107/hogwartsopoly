# scripts/auction_manager.gd
# Gestiona la subasta de propiedades cuando ningún jugador
# las compra directamente. Implementa rondas de puja con
# incremento mínimo y eliminación de jugadores sin fondos.
extends Node

# ── Configuración de subasta ──────────────────────────────────────
const MIN_BID_INCREMENT: int = 1    # Mínimo que debe subir cada puja

# ── Estado de la subasta activa ───────────────────────────────────
var _tile:            Dictionary = {}
var _base_price:      int        = 0
var _current_bid:     int        = 0
var _current_winner:  Node       = null
var _active_bidders:  Array      = []   # Jugadores aún en la subasta
var _passed_bidders:  Array      = []   # Jugadores que pasaron esta ronda
var _bidder_index:    int        = 0    # A quién le toca pujar ahora
var _round:           int        = 0    # Número de ronda actual
var _is_active:       bool       = false

# ── Señales ───────────────────────────────────────────────────────
signal auction_started(tile_data: Dictionary, base_price: int, bidders: Array)
signal bid_requested(player: Node, current_bid: int, min_next_bid: int)
signal bid_placed(player: Node, amount: int)
signal bidder_passed(player: Node)
signal bidder_eliminated(player: Node, reason: String)
signal new_round_started(round_number: int, current_bid: int, active_bidders: Array)
signal auction_won(winner: Node, tile_data: Dictionary, final_price: int)
signal auction_cancelled(tile_data: Dictionary)   # Nadie pujó — va al banco

# ─────────────────────────────────────────────────────────────────
# Inicia una nueva subasta
func start_auction(tile_data: Dictionary, base_price: int) -> void:
    _tile         = tile_data
    _base_price   = base_price
    _current_bid  = base_price
    _current_winner = null
    _round        = 1
    _is_active    = true
    _passed_bidders.clear()

    # Todos los jugadores con puntos suficientes entran a la subasta
    _active_bidders = GameState.players.map(
        func(p_data): return _find_player_node(p_data)
    ).filter(
        func(p): return p != null and p.points >= base_price
    )

    if _active_bidders.is_empty():
        # Nadie puede permitírsela — queda en el banco
        _end_auction_no_winner()
        return

    _bidder_index = 0
    auction_started.emit(_tile, _base_price, _active_bidders)
    _request_next_bid()

# ── La UI llama a estos métodos según la acción del jugador ───────

# El jugador activo hace una puja
func on_bid_placed(amount: int) -> void:
    if not _is_active:
        return

    var bidder = _active_bidders[_bidder_index]
    var min_bid = _current_bid + MIN_BID_INCREMENT

    # Validaciones
    if amount < min_bid:
        # Puja inválida — la UI debe mostrar error y volver a pedir
        bid_requested.emit(bidder, _current_bid, min_bid)
        return

    if bidder.points < amount:
        # No tiene fondos — se elimina automáticamente
        _eliminate_bidder(bidder, "Sin fondos suficientes")
        return

    _current_bid    = amount
    _current_winner = bidder
    bid_placed.emit(bidder, amount)
    _advance_bidder()

# El jugador activo pasa (no puja esta ronda)
func on_bid_passed() -> void:
    if not _is_active:
        return

    var bidder = _active_bidders[_bidder_index]
    _passed_bidders.append(bidder)
    bidder_passed.emit(bidder)

    # Si todos los activos restantes pasaron, termina la ronda
    var active_not_passed = _active_bidders.filter(
        func(p): return not _passed_bidders.has(p)
    )
    if active_not_passed.is_empty():
        _end_round()
    else:
        _advance_bidder()

# ─────────────────────────────────────────────────────────────────
func _advance_bidder() -> void:
    # Avanza al siguiente pujador que no haya pasado
    var attempts = 0
    while attempts < _active_bidders.size():
        _bidder_index = (_bidder_index + 1) % _active_bidders.size()
        var next = _active_bidders[_bidder_index]
        if not _passed_bidders.has(next):
            break
        attempts += 1

    # Si quedó solo un pujador activo sin pasar, gana
    var still_active = _active_bidders.filter(
        func(p): return not _passed_bidders.has(p)
    )
    if still_active.size() == 1 and _current_winner == still_active[0]:
        _end_auction_with_winner()
        return
    if still_active.size() == 0:
        _end_auction_with_winner()
        return

    _request_next_bid()

func _end_round() -> void:
    # Si solo queda un pujador activo total, gana
    if _active_bidders.size() == 1:
        _current_winner = _active_bidders[0]
        _end_auction_with_winner()
        return

    # Si hay ganador con puja y todos los demás pasaron, gana
    if _current_winner != null and _passed_bidders.size() >= _active_bidders.size() - 1:
        _end_auction_with_winner()
        return

    # Si nadie pujó en la ronda (todos pasaron sin winner), cancela
    if _current_winner == null:
        _end_auction_no_winner()
        return

    # Nueva ronda — se reinician los que pasaron
    _round        += 1
    _passed_bidders.clear()
    _bidder_index  = 0
    new_round_started.emit(_round, _current_bid, _active_bidders)
    _request_next_bid()

func _eliminate_bidder(bidder: Node, reason: String) -> void:
    _active_bidders.erase(bidder)
    _passed_bidders.erase(bidder)
    bidder_eliminated.emit(bidder, reason)

    if _active_bidders.is_empty():
        # Era el último — si tenía puja activa, gana igual
        if _current_winner != null:
            _end_auction_with_winner()
        else:
            _end_auction_no_winner()
        return

    # Ajusta el índice para no saltarse a nadie
    _bidder_index = _bidder_index % _active_bidders.size()
    _request_next_bid()

func _request_next_bid() -> void:
    if _active_bidders.is_empty():
        return
    _bidder_index = _bidder_index % _active_bidders.size()
    var bidder    = _active_bidders[_bidder_index]
    var min_next  = _current_bid + MIN_BID_INCREMENT
    bid_requested.emit(bidder, _current_bid, min_next)

func _end_auction_with_winner() -> void:
    _is_active = false
    if _current_winner == null:
        _end_auction_no_winner()
        return
    # El ganador paga el precio final — usamos buy_property con override de precio
    _current_winner.lose_points(_current_bid)
    var prop_data = _tile.duplicate()
    prop_data["price"] = _current_bid   # El precio que realmente pagó
    var owned = {
        "id":       _tile.id,
        "name":     _tile.name,
        "type":     _tile.get("type", "property"),
        "group":    _tile.get("color_group", ""),
        "shields":  0,
        "mortgaged": false,
    }
    _current_winner.properties.append(owned)
    AudioManager.play_sfx("buy_property")
    auction_won.emit(_current_winner, _tile, _current_bid)
    _reset()

func _end_auction_no_winner() -> void:
    _is_active = false
    auction_cancelled.emit(_tile)
    _reset()

func _reset() -> void:
    _tile           = {}
    _base_price     = 0
    _current_bid    = 0
    _current_winner = null
    _active_bidders.clear()
    _passed_bidders.clear()
    _bidder_index   = 0
    _round          = 1

# ── Helpers ───────────────────────────────────────────────────────
func _find_player_node(player_data: Dictionary) -> Node:
    # Busca el nodo Player correspondiente en el GameManager
    var gm = get_parent()
    if gm.has_method("get_player_node_by_name"):
        return gm.get_player_node_by_name(player_data.get("name", ""))
    return null

func get_current_state() -> Dictionary:
    return {
        "tile":           _tile,
        "current_bid":    _current_bid,
        "current_winner": _current_winner.player_name if _current_winner else "",
        "active_bidders": _active_bidders.map(func(p): return p.player_name),
        "round":          _round,
    }
