# scripts/board.gd
# Maneja los DATOS del tablero cargados desde el JSON.
# No instancia nodos visuales — eso lo hace board_visual.gd
extends Node

var tiles: Array = []
var board_config: Dictionary = {}

signal tile_clicked(tile_index: int)
signal board_loaded(board_data: Dictionary)

func _ready() -> void:
    load_board("res://data/default_board.json")

func load_board(path: String) -> void:
    board_config = SaveSystem.load_board(path)
    if board_config.is_empty():
        push_error("Board: no se pudo cargar '%s'" % path)
        return
    GameState.board_data = board_config
    tiles = board_config.get("tiles", [])
    board_loaded.emit(board_config)

func get_tile(tile_id: int) -> Dictionary:
    for tile in tiles:
        if tile.get("id", -1) == tile_id:
            return tile
    return {}

func find_nearest_tile(from_position: int, tile_type: String) -> Dictionary:
    var total = tiles.size()
    for offset in range(1, total):
        var index = (from_position + offset) % total
        if tiles[index].get("type", "") == tile_type:
            return tiles[index]
    return {}

func get_tiles_of_type(tile_type: String) -> Array:
    return tiles.filter(func(t): return t.get("type", "") == tile_type)
