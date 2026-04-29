# scripts/purchase_manager.gd
# Maneja la oferta de compra directa cuando un jugador cae
# en una propiedad sin dueño. Si el jugador rechaza o no tiene
# fondos, delega a AuctionManager para iniciar la subasta.
extends Node

# ── Referencia al manejador de subastas (nodo hermano) ────────────
@onready var auction_manager: Node = $"../AuctionManager"

# ── Estado interno ────────────────────────────────────────────────
var _pending_player: Node        = null
var _pending_tile:   Dictionary  = {}

# ── Señales ───────────────────────────────────────────────────────
signal purchase_completed(player: Node, tile_data: Dictionary)
signal purchase_declined(tile_data: Dictionary)
signal show_purchase_ui(player: Node, tile_data: Dictionary)
signal hide_purchase_ui

# ─────────────────────────────────────────────────────────────────
# Llamado por GameManager cuando un jugador cae en propiedad libre
func offer_purchase(player: Node, tile_data: Dictionary) -> void:
    _pending_player = player
    _pending_tile   = tile_data
    show_purchase_ui.emit(player, tile_data)

# ── Respuestas del jugador (la UI llama a estos métodos) ──────────

# El jugador acepta comprar
func on_player_accepts() -> void:
    print("=== on_player_accepts llamado ===")
    if _pending_player == null:
        return
    var price: int = int(_pending_tile.get("price", 0))

    if _pending_player.points < price:
        _go_to_auction()
        return

    _pending_player.buy_property(_pending_tile)
    AudioManager.play_sfx("buy_property")
    purchase_completed.emit(_pending_player, _pending_tile)
    hide_purchase_ui.emit()
    _clear()

# El jugador rechaza comprar
func on_player_declines() -> void:
    print("=== on_player_declines llamado ===")
    hide_purchase_ui.emit()
    _go_to_auction()

# ─────────────────────────────────────────────────────────────────
func _go_to_auction() -> void:
    purchase_declined.emit(_pending_tile)
    # El precio base de la subasta es la mitad del precio de catálogo
    var base_price: int = _pending_tile.get("price", 0) / 2
    base_price = max(base_price, 1)   # mínimo 1 punto
    auction_manager.start_auction(_pending_tile, base_price)
    _clear()

func _clear() -> void:
    _pending_player = null
    _pending_tile   = {}
