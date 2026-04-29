# scripts/token_manager.gd
extends Node3D

const TOKEN_MODELS: Dictionary = {
    "locomotora":  "res://assets/models/tokens/locomotora.glb",
    "noctambulo":  "res://assets/models/tokens/noctambulo.glb",
    "hagrid_moto": "res://assets/models/tokens/hagrid_moto.glb",
    "saeta":       "res://assets/models/tokens/saeta.glb",
    "hipogrifo":   "res://assets/models/tokens/hipogrifo.glb",
    "thestral":    "res://assets/models/tokens/thestral.glb",
}

const TOKEN_SCALES: Dictionary = {
    "locomotora":  0.90, "noctambulo":  0.80,
    "hagrid_moto": 0.72, "saeta":       0.68,
    "hipogrifo":   0.98, "thestral":    0.98,
}

const TOKEN_HEIGHT: float = 0.16   # Altura sobre la casilla
const SLOT_OFFSETS: Array = [
    Vector2(0, 0),    Vector2(0.22, 0),
    Vector2(-0.22, 0), Vector2(0, 0.22),
    Vector2(0.22, 0.22), Vector2(-0.22, 0.22)
]

var _gold_mat:    StandardMaterial3D = null
var token_nodes:  Array = []   # Contenedores externos (posición real)
var float_tweens: Array = []   # Tweens de flotación por token
var board_scene:  Node3D = null

func _ready() -> void:
    board_scene = get_parent()
    _build_gold_material()
    print("TokenManager listo. board_scene: ", board_scene)

func _build_gold_material() -> void:
    _gold_mat = StandardMaterial3D.new()
    _gold_mat.albedo_color        = Color("#D4A843")
    _gold_mat.metallic            = 1.0
    _gold_mat.roughness           = 0.12
    _gold_mat.emission_enabled    = true
    _gold_mat.emission            = Color("#FFD700") * 0.8
    _gold_mat.clearcoat           = 1.0
    _gold_mat.clearcoat_roughness = 0.08
    _gold_mat.shading_mode        = BaseMaterial3D.SHADING_MODE_UNSHADED

# ── Crear tokens ──────────────────────────────────────────────────
func create_tokens(players: Array) -> void:
    # Limpiar tokens anteriores
    for tw in float_tweens:
        if tw and is_instance_valid(tw):
            tw.kill()
    float_tweens.clear()
    for child in get_children():
        child.queue_free()
    token_nodes.clear()

    for i in range(players.size()):
        var p      = players[i]
        var tok_id = p.get("token", "locomotora")
        # Contenedor externo — maneja posición XZ en el tablero
        var outer  = Node3D.new()
        outer.name = "Token_%d" % i
        add_child(outer)
        token_nodes.append(outer)

        # Contenedor interno — maneja el offset Y de flotación
        var inner = Node3D.new()
        inner.name = "Inner"
        outer.add_child(inner)

        # Modelo 3D dentro del inner
        var model = _load_model(tok_id)
        inner.add_child(model)

        # Posición inicial en casilla 0
        var base_pos = _get_base_pos(0, i, players.size())
        outer.position = base_pos

        # Tween de flotación solo afecta al inner.position.y
        _start_float(inner, i)

func _load_model(token_id: String) -> Node3D:
    var path = TOKEN_MODELS.get(token_id, "")
    if path != "" and ResourceLoader.exists(path):
        var inst  = load(path).instantiate()
        inst.scale = Vector3.ONE * TOKEN_SCALES.get(token_id, 0.25)
        _apply_gold_recursive(inst)
        return inst
    # Fallback: cilindro dorado
    var mi  = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = 0.07; cyl.bottom_radius = 0.10; cyl.height = 0.20
    mi.mesh = cyl
    mi.material_override = _gold_mat.duplicate()
    return mi

func _apply_gold_recursive(node: Node) -> void:
    if node is MeshInstance3D:
        node.material_override = _gold_mat.duplicate()
        for i in range(node.get_surface_override_material_count()):
            node.set_surface_override_material(i, _gold_mat.duplicate())
    for child in node.get_children():
        _apply_gold_recursive(child)

func _start_float(inner: Node3D, slot: int) -> void:
    var tween = create_tween().set_loops()
    var phase = 1.0 + slot * 0.28
    tween.tween_property(inner, "position:y",  0.06, phase) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(inner, "position:y", -0.02, phase) \
        .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    float_tweens.append(tween)

# ── Mover token ───────────────────────────────────────────────────
func move_token_to(player_index: int, tile_id: int) -> void:
    if player_index >= token_nodes.size():
        return
    var outer  = token_nodes[player_index]
    var target = _get_base_pos(tile_id, player_index, GameState.players.size())

    # Arco de salto — solo movemos el outer (posición base), no el inner
    var start  = outer.position
    var peak_y = max(start.y, target.y) + 0.6
    var mid    = Vector3((start.x + target.x) * 0.5, peak_y, (start.z + target.z) * 0.5)

    var tw = create_tween()
    tw.tween_property(outer, "position", mid, 0.20) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_property(outer, "position", target, 0.20) \
        .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    await tw.finished
    
    var rot = _get_token_rotation(tile_id)
    var rot_tween = create_tween()
    rot_tween.tween_property(outer, "rotation_degrees:y", rot, 0.15)

    # Mover cámara al jugador activo
    if player_index == GameState.current_player_index:
        var cam = get_parent().get_node_or_null("IsometricCamera")
        if cam and cam.has_method("focus_on_tile"):
            cam.focus_on_tile(tile_id)
            
# Rootar tokens

func _get_token_rotation(tile_id: int) -> float:
    # Devuelve los grados de rotación Y para que el token
    # quede orientado hacia el interior del tablero
    if tile_id <= 10:
        return 0.0      # Fila inferior — mira hacia arriba (norte)
    elif tile_id <= 20:
        return 90.0     # Columna izquierda — mira hacia la derecha (este)
    elif tile_id <= 30:
        return 180.0    # Fila superior — mira hacia abajo (sur)
    else:
        return 270.0    # Columna derecha — mira hacia la izquierda (oeste)

# ── Highlight ─────────────────────────────────────────────────────
func highlight_token(player_index: int, active: bool) -> void:
    if player_index >= token_nodes.size():
        return
    var tween = create_tween()
    tween.tween_property(token_nodes[player_index], "scale",
        Vector3.ONE * (1.25 if active else 1.0), 0.2)

# ── Posición base de una casilla (XYZ sin flotación) ──────────────
func _get_base_pos(tile_id: int, slot: int, total: int) -> Vector3:
    if board_scene == null or not board_scene.has_method("get_tile_center_3d"):
        return Vector3(0, TOKEN_HEIGHT, 0)
    var center = board_scene.get_tile_center_3d(tile_id)
    var off    = SLOT_OFFSETS[slot] if slot < SLOT_OFFSETS.size() else Vector2.ZERO
    # center.y ya incluye TILE_THICK/2, sumamos TOKEN_HEIGHT encima
    return Vector3(center.x + off.x, center.y + TOKEN_HEIGHT, center.z + off.y)
