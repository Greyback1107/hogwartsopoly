# scripts/bridge_3d.gd
# Conecta señales del GameManager con el sistema 3D.
extends Node

var _game_manager:  Node = null
var _board_scene:   Node3D = null
var _token_manager: Node3D = null
var _cam_ctrl:      Node3D = null
var _initialized:   bool   = false
var _connected_move_players: Dictionary = {}

func _ready() -> void:
    # Esperar suficientes frames para que start_game ya haya corrido
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().process_frame
    _connect_all()
    # Forzar creación de tokens manualmente en caso de que turn_started ya pasó
    await get_tree().process_frame
    if _token_manager and _token_manager.token_nodes.is_empty():
        print("Forzando create_tokens desde _ready")
        _token_manager.create_tokens(GameState.players)

func _connect_all() -> void:
    var parent = get_parent()
    if parent == null:
        return
    _game_manager  = parent.get_node_or_null("GameManager")
    _board_scene   = parent.get_node_or_null("BoardScene3D")
    _token_manager = _board_scene.get_node_or_null("TokensRoot") if _board_scene else null
    _cam_ctrl      = _board_scene.get_node_or_null("IsometricCamera") if _board_scene else null

    if _game_manager == null or _token_manager == null:
        push_error("Bridge3D: no se encontraron nodos necesarios")
        return

    _game_manager.turn_started.connect(_on_turn_started)
    print("Señal turn_started conectada: ", _game_manager.turn_started.is_connected(_on_turn_started))
    _game_manager.game_over.connect(_on_game_over)
    _connect_player_moves()
    _token_manager.create_tokens(GameState.players)
    _initialized = true
    print("Bridge conectado. game_manager: ", _game_manager)
    print("Bridge token_manager: ", _token_manager)

func _connect_player_moves() -> void:
    for i in range(GameState.players.size()):
        _connect_single_player_move(i)

func _connect_single_player_move(i: int) -> void:
    if _connected_move_players.has(i):
        return
    var p_node = get_tree().root.find_child("Player_%d" % i, true, false)
    if p_node == null or not p_node.has_signal("moved"):
        return
    var idx = i
    p_node.moved.connect(func(new_pos: int, _passed_go: bool):
        if _token_manager:
            _token_manager.move_token_to(idx, new_pos)
    )
    _connected_move_players[i] = true

func _on_turn_started(player_index: int) -> void:
    _connect_player_moves()
    print("Turn started idx:", player_index, " tokens:", _token_manager.token_nodes.size() if _token_manager else "null")
    print("=== TURN STARTED llamado, idx: ", player_index)
    
    # Crear tokens si aún no existen
    if _token_manager and _token_manager.token_nodes.is_empty():
        print("Creando tokens...")
        _token_manager.create_tokens(GameState.players)
        # Esperar un frame para que los tokens existan antes de hacer highlight
        await get_tree().process_frame
    
    if _token_manager:
        for i in range(_token_manager.token_nodes.size()):
            _token_manager.highlight_token(i, i == player_index)

    if _cam_ctrl and _cam_ctrl.has_method("focus_on_tile"):
        var p_node = get_tree().root.find_child("Player_%d" % player_index, true, false)
        if p_node:
            _cam_ctrl.focus_on_tile(p_node.tile_position)

func _on_game_over(_winner: Node) -> void:
    var castle = _board_scene.get_node_or_null("CastleRoot") if _board_scene else null
    if castle and castle.has_method("set_glow_intensity"):
        var tween = create_tween().set_loops(6)
        tween.tween_method(castle.set_glow_intensity, 0.06, 0.5, 0.5)
        tween.tween_method(castle.set_glow_intensity, 0.5, 0.06, 0.5)
