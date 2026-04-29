# scripts/board_scene_3d.gd
extends Node3D

@onready var tiles_root:  Node3D = $TilesRoot
@onready var castle_root: Node3D = $CastleRoot
@onready var tokens_root: Node3D = $TokensRoot
@onready var cam_ctrl:    Node3D = $IsometricCamera

# ── Dimensiones exactas del tablero ──────────────────────────────
# 2 esquinas × 1.22 + 9 normales × nw = 5.0 (cada lado es BOARD_TOTAL/2)
# nw = (5.0 - 1.22) / 9 = 0.4200 ... no, vamos con unidades simples:
# BOARD_TOTAL = 10, CORNER = 1.22, 9 × NORMAL_W + 2 × CORNER = 10
# NORMAL_W = (10 - 2*1.22) / 9 = 7.56 / 9 = 0.84
const BOARD_TOTAL: float = 10.0
const CORNER_SIZE: float = 1.22
const NORMAL_W:    float = 0.84    # Ancho casilla normal
const NORMAL_H:    float = 1.22    # Alto casilla normal (misma que esquina)
const TILE_THICK:  float = 0.06
const BOARD_Y:     float = 0.0
const GAP:         float = 0.008   # Separación visual entre casillas

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    if GameState.board_data.is_empty():
        GameState.board_data = SaveSystem.load_board("res://data/default_board.json")
    if GameState.players.is_empty():
        GameState.players = [
            {"name": "Harry",    "house": "Gryffindor", "token": "locomotora",
             "points": 100, "position": 0, "in_jail": false,
             "jail_turns": 0, "properties": [], "hand_cards": []},
            {"name": "Hermione", "house": "Ravenclaw",  "token": "hipogrifo",
             "points": 100, "position": 0, "in_jail": false,
             "jail_turns": 0, "properties": [], "hand_cards": []},
        ]
    _build_board_base()
    _build_tiles()
    _setup_castle()
    _register_players()

# ── Base del tablero ──────────────────────────────────────────────
func _build_board_base() -> void:
    var mi   = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size    = Vector3(BOARD_TOTAL + 0.1, 0.05, BOARD_TOTAL + 0.1)
    mi.position  = Vector3(0, -0.025, 0)
    mi.mesh      = mesh
    var mat      = StandardMaterial3D.new()
    mat.albedo_color  = Color("#0D0A04")
    mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = mat
    add_child(mi)

    # Marco dorado
    _add_gold_frame()

func _add_gold_frame() -> void:
    var half  = BOARD_TOTAL * 0.5
    var thick = 0.04
    var h     = 0.03
    var mat   = StandardMaterial3D.new()
    mat.albedo_color     = Color("#C9A84C")
    mat.emission_enabled = true
    mat.emission         = Color("#C9A84C") * 0.6
    mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED

    for side in [
        [Vector3(0, h, -half - thick*0.5),  Vector3(BOARD_TOTAL + thick*2, h*2, thick)],
        [Vector3(0, h,  half + thick*0.5),  Vector3(BOARD_TOTAL + thick*2, h*2, thick)],
        [Vector3(-half - thick*0.5, h, 0),  Vector3(thick, h*2, BOARD_TOTAL)],
        [Vector3( half + thick*0.5, h, 0),  Vector3(thick, h*2, BOARD_TOTAL)],
    ]:
        var bm   = MeshInstance3D.new()
        var mesh = BoxMesh.new()
        mesh.size    = side[1]
        bm.mesh      = mesh
        bm.position  = side[0]
        bm.material_override = mat
        add_child(bm)

# ── Casillas ──────────────────────────────────────────────────────
func _build_tiles() -> void:
    for tile_data in GameState.board_data.get("tiles", []):
        var tid = int(tile_data.get("id", 0))
        _create_tile(tile_data, tid)

func _create_tile(tile_data: Dictionary, tid: int) -> void:
    var pos    = get_tile_center_3d(tid)
    var size2d = _tile_size(tid)
    var rot_y  = _tile_rotation_y(tid)   # Rotación según el lado del tablero

    var mi   = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    # Usamos size.x como ancho y size.y como profundidad del plano
    mesh.size   = Vector3(size2d.x - GAP, TILE_THICK, size2d.y - GAP)
    mi.mesh     = mesh
    mi.position = pos
    mi.rotation_degrees.y = rot_y
    mi.name     = "Tile_%d" % tid

    var mat = StandardMaterial3D.new()
    var tex_path = "res://assets/sprites/tiles/tile_%d.png" % tid
    if ResourceLoader.exists(tex_path):
        var tex = load(tex_path) as Texture2D
        mat.albedo_texture = tex
        # Sin rotación del UV — la imagen ya viene orientada correctamente
        # porque rotamos el mesh completo con rot_y
    else:
        mat.albedo_color = Color("#2C2010")
    # UNSHADED: se ve igual con o sin luz
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = mat

    tiles_root.add_child(mi)

# ── Castillo en el centro ─────────────────────────────────────────
func _setup_castle() -> void:
    if castle_root == null:
        return
    # Centrado exacto en el tablero, apoyado sobre la superficie
    castle_root.position = Vector3(0.0, TILE_THICK + 0.02, 0.0)

# ── Registro de jugadores ─────────────────────────────────────────
func _register_players() -> void:
    var gm = get_parent().get_node_or_null("GameManager")
    if gm == null:
        return
    var logical_players: Array = []
    for i in range(GameState.players.size()):
        var p_node = Node.new()
        p_node.set_script(load("res://scripts/player.gd"))
        p_node.name = "Player_%d" % i
        get_parent().add_child.call_deferred(p_node)
        p_node.setup(GameState.players[i])
        logical_players.append(p_node)
    gm.register_players(GameState.players, logical_players)
    gm.start_game.call_deferred()

# ── Coordenadas y rotación de casillas ───────────────────────────
func get_tile_center_3d(tile_id: int) -> Vector3:
    var half = BOARD_TOTAL * 0.5
    var cs   = CORNER_SIZE
    var nw   = NORMAL_W
    var nh   = NORMAL_H
    var x:   float
    var z:   float

    match tile_id:
        0:
            x =  half - cs * 0.5;  z =  half - cs * 0.5
        10:
            x = -half + cs * 0.5;  z =  half - cs * 0.5
        20:
            x = -half + cs * 0.5;  z = -half + cs * 0.5
        30:
            x =  half - cs * 0.5;  z = -half + cs * 0.5
        _:
            if tile_id < 10:
                x = half - cs - (tile_id - 0.5) * nw
                z = half - nh * 0.5
            elif tile_id < 20:
                var i = tile_id - 10
                x = -half + nh * 0.5
                z =  half - cs - (i - 0.5) * nw
            elif tile_id < 30:
                var i = tile_id - 20
                x = -half + cs + (i - 0.5) * nw
                z = -half + nh * 0.5
            else:
                var i = tile_id - 30
                x =  half - nh * 0.5
                z = -half + cs + (i - 0.5) * nw

    return Vector3(x, BOARD_Y + TILE_THICK * 0.5, z)

func _tile_rotation_y(tile_id: int) -> float:
    # Las imágenes PNG vienen orientadas para verse desde el borde exterior.
    # Rotamos el mesh completo para que cada lado mire hacia el interior.
    if tile_id in [0, 10, 20, 30]:
        return 0.0        # Esquinas sin rotación especial
    elif tile_id < 10:
        return 0.0        # Fila inferior — imagen ya correcta
    elif tile_id < 20:
        return 90.0       # Columna izquierda
    elif tile_id < 30:
        return 180.0      # Fila superior
    else:
        return 270.0      # Columna derecha

func _tile_size(tile_id: int) -> Vector2:
    if tile_id in [0, 10, 20, 30]:
        return Vector2(CORNER_SIZE, CORNER_SIZE)
    # Para los lados: el ancho siempre es NORMAL_W y el alto NORMAL_H
    # pero al rotar 90/270°, x y z se intercambian en el mundo
    # Así que siempre pasamos (NORMAL_W, NORMAL_H) y la rotación hace el resto
    return Vector2(NORMAL_W, NORMAL_H)

func highlight_tile(tile_id: int, active: bool) -> void:
    var node = tiles_root.get_node_or_null("Tile_%d" % tile_id)
    if node == null:
        return
    var mat = node.get_active_material(0)
    if mat == null:
        return
    mat.emission_enabled = active
    mat.emission         = Color("#C9A84C") * (0.5 if active else 0.0)
