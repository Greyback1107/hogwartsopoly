# autoloads/SaveSystem.gd
# Singleton global para persistencia de partidas.
# Guarda en la carpeta de usuario (AppData en Windows).
extends Node

const SAVE_PATH: String = "user://savegame.json"
const BOARDS_DIR: String = "user://boards/"   # Tableros personalizados del editor

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    # Crea el directorio de tableros si no existe
    if not DirAccess.dir_exists_absolute(BOARDS_DIR):
        DirAccess.make_dir_absolute(BOARDS_DIR)

# ── Partida ───────────────────────────────────────────────────────
func save_game() -> void:
    var data: Dictionary = {
        "version":              "1.0",
        "timestamp":            Time.get_datetime_string_from_system(),
        "current_player_index": GameState.current_player_index,
        "turn_count":           GameState.turn_count,
        "players":              GameState.players,
        "board_name":           GameState.board_data.get("name", ""),
    }
    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data, "\t"))
        file.close()
        print("SaveSystem: partida guardada")
    else:
        push_error("SaveSystem: no se pudo abrir el archivo para guardar")

func load_game() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH):
        return {}
    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        push_error("SaveSystem: no se pudo abrir el archivo de guardado")
        return {}
    var content = file.get_as_text()
    file.close()
    var result = JSON.parse_string(content)
    if result == null:
        push_error("SaveSystem: el archivo de guardado está corrupto")
        return {}
    return result

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)

# ── Tableros personalizados ───────────────────────────────────────
func save_custom_board(board_data: Dictionary, filename: String) -> void:
    var path = BOARDS_DIR + filename + ".json"
    var file = FileAccess.open(path, FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(board_data, "\t"))
        file.close()

func load_board(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        push_error("SaveSystem: tablero no encontrado en '%s'" % path)
        return {}
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var content = file.get_as_text()
    file.close()
    var result = JSON.parse_string(content)
    return result if result != null else {}

func get_custom_boards() -> Array:
    # Devuelve lista de rutas de tableros guardados por el usuario
    var boards: Array = []
    var dir = DirAccess.open(BOARDS_DIR)
    if dir:
        dir.list_dir_begin()
        var filename = dir.get_next()
        while filename != "":
            if filename.ends_with(".json"):
                boards.append(BOARDS_DIR + filename)
            filename = dir.get_next()
    return boards
