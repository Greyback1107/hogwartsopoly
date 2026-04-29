# scripts/board_scene_3d.gd
extends Node3D

@onready var tiles_root:  Node3D = $TilesRoot
@onready var castle_root: Node3D = $CastleRoot
@onready var tokens_root: Node3D = $TokensRoot
@onready var cam_ctrl:    Node3D = $IsometricCamera

const BOARD_TOTAL: float = 10.0
const CORNER_SIZE: float = 1.22
const NORMAL_W:    float = 0.84
const NORMAL_H:    float = 1.22
const TILE_THICK:  float = 0.06
const BOARD_Y:     float = 0.0
const GAP:         float = 0.01

# Tipos sin franja de color
const NO_STRIPE: Array = [
    "owl_letters", "tax", "spell", "common_room",
    "jail", "go_to_jail", "go", "free_parking", "punishment"
]

const GROUP_COLORS: Dictionary = {
    "brown":       Color("#6B3A2A"), "sky_blue":    Color("#87CEEB"),
    "sky blue":    Color("#87CEEB"), "cyan":        Color("#87CEEB"),
    "magenta":     Color("#C71585"), "orange":      Color("#FF8C00"),
    "red":         Color("#CC0000"), "yellow":      Color("#FFD700"),
    "green":       Color("#2E8B57"), "blue":        Color("#00008B"),
    "common_room": Color("#4B0082"), "spell":       Color("#9400D3"),
}

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    if GameState.board_data.is_empty():
        GameState.board_data = SaveSystem.load_board("res://data/default_board.json")
    if GameState.players.is_empty():
        GameState.players = [
            {"name": "Harry",    "house": "Gryffindor", "token": "locomotora",
             "points": 100, "position": 0, "in_jail": false,
             "jail_turns": 0, "properties": [], "hand_cards": []},
            {"name": "Hermione", "house": "Ravenclaw", "token": "hipogrifo",
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
    mesh.size   = Vector3(BOARD_TOTAL + 0.1, 0.05, BOARD_TOTAL + 0.1)
    mi.position = Vector3(0, -0.025, 0)
    mi.mesh     = mesh
    var mat     = StandardMaterial3D.new()
    mat.albedo_color = Color("#0D0A04")
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mi.material_override = mat
    add_child(mi)
    _add_gold_frame()

func _add_gold_frame() -> void:
    var half  = BOARD_TOTAL * 0.5
    var thick = 0.05
    var h     = 0.04
    var mat   = StandardMaterial3D.new()
    mat.albedo_color     = Color("#C9A84C")
    mat.emission_enabled = true
    mat.emission         = Color("#C9A84C") * 0.6
    mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
    for side in [
        [Vector3(0, h, -(half + thick*0.5)), Vector3(BOARD_TOTAL + thick*2, h*2, thick)],
        [Vector3(0, h,   half + thick*0.5),  Vector3(BOARD_TOTAL + thick*2, h*2, thick)],
        [Vector3(-(half + thick*0.5), h, 0), Vector3(thick, h*2, BOARD_TOTAL)],
        [Vector3(  half + thick*0.5,  h, 0), Vector3(thick, h*2, BOARD_TOTAL)],
    ]:
        var bm   = MeshInstance3D.new()
        var bmesh = BoxMesh.new()
        bmesh.size  = side[1]
        bm.mesh     = bmesh
        bm.position = side[0]
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
    var rot_y  = _tile_rotation_y(tid)
    var tile_type = tile_data.get("type", "property")
    var is_corner = tile_type in ["go", "jail", "go_to_jail", "free_parking", "punishment"]
    var has_stripe = tile_type not in NO_STRIPE

    # ── Nodo contenedor para agrupar planos ──────────────────────
    var container = Node3D.new()
    container.name     = "Tile_%d" % tid
    container.position = pos
    container.rotation_degrees.y = rot_y
    tiles_root.add_child(container)

    # ── Plano principal con la imagen ─────────────────────────────
    var quad = MeshInstance3D.new()
    var qmesh = QuadMesh.new()
    qmesh.size = Vector2(size2d.x - GAP, size2d.y - GAP)
    quad.mesh  = qmesh
    # QuadMesh mira hacia +Z por defecto — rotarlo para que quede horizontal
    quad.rotation_degrees.x = -90.0
    quad.position.y = TILE_THICK * 0.5 + 0.001

    var mat = StandardMaterial3D.new()
    var tex_path = "res://assets/sprites/tiles/tile_%d.png" % tid
    if ResourceLoader.exists(tex_path):
        mat.albedo_texture = load(tex_path)
    else:
        mat.albedo_color = Color("#2A1A08")
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    quad.material_override = mat
    container.add_child(quad)

    # ── Franja de color (solo propiedades normales) ────────────────
    if has_stripe and not is_corner:
        var color_group = tile_data.get("color_group", "")
        if color_group != "" and GROUP_COLORS.has(color_group):
            var stripe_quad = MeshInstance3D.new()
            var smesh = QuadMesh.new()
            # La franja ocupa el 20% superior de la casilla
            var stripe_h = size2d.y * 0.20
            smesh.size = Vector2(size2d.x - GAP, stripe_h)
            stripe_quad.mesh = smesh
            stripe_quad.rotation_degrees.x = -90.0
            # Posicionar la franja en la parte superior (borde exterior)
            stripe_quad.position.y = TILE_THICK * 0.5 + 0.003
            stripe_quad.position.z = -(size2d.y * 0.5 - stripe_h * 0.5)
            var smat = StandardMaterial3D.new()
            smat.albedo_color = GROUP_COLORS[color_group]
            smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            stripe_quad.material_override = smat
            container.add_child(stripe_quad)

    # ── Texto superpuesto (nombre y precio) ───────────────────────
    if not is_corner:
        _add_tile_text(container, tile_data, size2d, has_stripe)

    # ── Base volumétrica (el grosor de la casilla) ────────────────
    var base = MeshInstance3D.new()
    var bmesh = BoxMesh.new()
    bmesh.size = Vector3(size2d.x - GAP, TILE_THICK, size2d.y - GAP)
    base.mesh  = bmesh
    var bmat   = StandardMaterial3D.new()
    bmat.albedo_color = Color("#1A1208")
    bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    base.material_override = bmat
    container.add_child(base)

func _add_tile_text(container: Node3D, tile_data: Dictionary, size2d: Vector2, has_stripe: bool) -> void:
    var font      = ThemeDB.fallback_font
    var font_size = 9
    var name_text = tile_data.get("name", "")
    var price     = tile_data.get("price", null)

    # Crear imagen para el texto
    var img_w = 128
    var img_h = 32
    var img   = Image.create(img_w, img_h, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))

    # Dibujar nombre
    # Nota: Image.draw_string no existe directamente — usamos Label3D en su lugar

    # ── Nombre con Label3D ────────────────────────────────────────
    var name_label = Label3D.new()
    name_label.text           = _wrap_text(name_text, 10)
    name_label.font_size      = 10
    name_label.modulate       = Color("#F5E6B0")
    name_label.outline_size   = 4
    name_label.outline_modulate = Color(0, 0, 0, 0.9)
    name_label.billboard      = BaseMaterial3D.BILLBOARD_DISABLED
    name_label.double_sided   = true
    name_label.pixel_size     = 0.004
    name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_label.rotation_degrees.x = -90.0
    # Posición: parte superior de la casilla (bajo la franja si existe)
    var stripe_offset = size2d.y * 0.20 if has_stripe else 0.0
    name_label.position.y = TILE_THICK * 0.5 + 0.01
    name_label.position.z = -(size2d.y * 0.5 - stripe_offset - 0.12)
    container.add_child(name_label)

    # ── Precio con Label3D ────────────────────────────────────────
    if price != null and typeof(price) in [TYPE_INT, TYPE_FLOAT]:
        var price_label = Label3D.new()
        price_label.text          = "%d pts" % int(price)
        price_label.font_size     = 9
        price_label.modulate      = Color("#FFD700")
        price_label.outline_size  = 4
        price_label.outline_modulate = Color(0, 0, 0, 0.9)
        price_label.billboard     = BaseMaterial3D.BILLBOARD_DISABLED
        price_label.double_sided  = true
        price_label.pixel_size    = 0.004
        price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        price_label.rotation_degrees.x = -90.0
        # Posición: parte inferior de la casilla
        price_label.position.y = TILE_THICK * 0.5 + 0.01
        price_label.position.z = size2d.y * 0.5 - 0.10
        container.add_child(price_label)

# ── Castillo ──────────────────────────────────────────────────────
func _setup_castle() -> void:
    if castle_root == null:
        return
    castle_root.position = Vector3(0.0, TILE_THICK + 0.08, 0.0)

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
    print("register_players llamado, llamando start_game...")
    gm.start_game.call_deferred()

# ── Coordenadas 3D ────────────────────────────────────────────────
func get_tile_center_3d(tile_id: int) -> Vector3:
    var half = BOARD_TOTAL * 0.5
    var cs   = CORNER_SIZE
    var nw   = NORMAL_W
    var nh   = NORMAL_H
    var x:   float
    var z:   float

    match tile_id:
        0:  x =  half - cs * 0.5; z =  half - cs * 0.5
        10: x = -half + cs * 0.5; z =  half - cs * 0.5
        20: x = -half + cs * 0.5; z = -half + cs * 0.5
        30: x =  half - cs * 0.5; z = -half + cs * 0.5
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
    if tile_id in [0, 10, 20, 30]: return 0.0
    elif tile_id < 10:  return 0.0
    elif tile_id < 20:  return 270.0
    elif tile_id < 30:  return 180.0
    else:               return 90.0

func _tile_size(tile_id: int) -> Vector2:
    if tile_id in [0, 10, 20, 30]:
        return Vector2(CORNER_SIZE, CORNER_SIZE)
    return Vector2(NORMAL_W, NORMAL_H)

func highlight_tile(tile_id: int, active: bool) -> void:
    var node = tiles_root.get_node_or_null("Tile_%d" % tile_id)
    if node == null:
        return
    # Buscar el quad principal (primer hijo)
    if node.get_child_count() > 0:
        var quad = node.get_child(0)
        if quad is MeshInstance3D:
            var mat = quad.get_active_material(0)
            if mat:
                mat.emission_enabled = active
                mat.emission = Color("#C9A84C") * (0.4 if active else 0.0)

func _wrap_text(text: String, max_chars: int) -> String:
    if text.length() <= max_chars:
        return text
    var words  = text.split(" ")
    var result = ""
    var line   = ""
    for word in words:
        var candidate = (line + " " + word).strip_edges()
        if candidate.length() > max_chars and line != "":
            result += line.strip_edges() + "\n"
            line    = word
        else:
            line = candidate
    result += line.strip_edges()
    return result
