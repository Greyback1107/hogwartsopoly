# scripts/piece_visual.gd
# Representa visualmente la pieza de un jugador en el tablero.
# Se mueve casilla a casilla con una animación de salto.
# Un nodo de este tipo se crea por cada jugador al inicio.
extends Node2D

# ── Configuración visual ──────────────────────────────────────────
const PIECE_RADIUS:  float = 10.0
const JUMP_HEIGHT:   float = 30.0    # Altura del arco al moverse
const MOVE_DURATION: float = 0.25    # Segundos por casilla

# Colores por casa — coinciden con setup_screen.gd
const HOUSE_COLORS: Dictionary = {
    "Gryffindor": Color("#CC0000"),
    "Hufflepuff":  Color("#FFD700"),
    "Ravenclaw":   Color("#0044AA"),
    "Slytherin":   Color("#008800"),
}

# ── Estado ────────────────────────────────────────────────────────
var player_name:  String  = ""
var house:        String  = ""
var piece_color:  Color   = Color.WHITE
var slot_index:   int     = 0   # Offset lateral cuando hay varias piezas en la misma casilla

# Referencia al BoardLayout para saber dónde está cada casilla
var board_layout: Node = null

# ── Señales ───────────────────────────────────────────────────────
signal move_finished

# ─────────────────────────────────────────────────────────────────
func setup(p_name: String, p_house: String, slot: int, layout: Node) -> void:
    player_name  = p_name
    house        = p_house
    piece_color  = HOUSE_COLORS.get(p_house, Color.WHITE)
    slot_index   = slot
    board_layout = layout
    queue_redraw()

func _draw() -> void:
    # Sombra
    draw_circle(Vector2(2, 2), PIECE_RADIUS, Color(0, 0, 0, 0.4))
    # Cuerpo de la pieza
    draw_circle(Vector2.ZERO, PIECE_RADIUS, piece_color)
    # Borde blanco
    draw_arc(Vector2.ZERO, PIECE_RADIUS, 0, TAU, 32, Color.WHITE, 1.5)
    # Inicial del jugador
    var font = ThemeDB.fallback_font
    var initial = player_name.substr(0, 1).to_upper()
    var sz      = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
    draw_string(font, Vector2(-sz.x * 0.5, sz.y * 0.3),
        initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

# ── Movimiento animado casilla a casilla ──────────────────────────
func move_to_tile(tile_id: int) -> void:
    if board_layout == null:
        move_finished.emit()
        return
    var target = board_layout.get_tile_center(tile_id) + _slot_offset()
    await _animate_jump(target)
    move_finished.emit()

# Mueve pasando por cada casilla intermedia (para el movimiento visual)
func move_through_tiles(from_id: int, steps: int, board_size: int) -> void:
    for i in range(1, steps + 1):
        var next_id = (from_id + i) % board_size
        var target  = board_layout.get_tile_center(next_id) + _slot_offset()
        await _animate_jump(target)
        await get_tree().create_timer(0.05).timeout
    move_finished.emit()

func _animate_jump(target: Vector2) -> void:
    var start    = global_position
    var mid      = (start + target) * 0.5 + Vector2(0, -JUMP_HEIGHT)
    var tween    = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_QUAD)
    tween.tween_property(self, "global_position", mid, MOVE_DURATION * 0.5)
    tween.set_ease(Tween.EASE_IN)
    tween.tween_property(self, "global_position", target, MOVE_DURATION * 0.5)
    await tween.finished

# Posiciona la pieza instantáneamente (sin animación, para el inicio)
func place_at_tile(tile_id: int) -> void:
    if board_layout == null:
        return
    global_position = board_layout.get_tile_center(tile_id) + _slot_offset()

# ── Offset para que varias piezas en la misma casilla no se solapen ─
func _slot_offset() -> Vector2:
    const OFFSETS = [
        Vector2(0, 0), Vector2(12, 0), Vector2(-12, 0),
        Vector2(0, 12), Vector2(12, 12), Vector2(-12, 12)
    ]
    if slot_index < OFFSETS.size():
        return OFFSETS[slot_index]
    return Vector2(slot_index * 8, 0)

# ── Animación de highlight (al seleccionar la pieza) ─────────────
func highlight(active: bool) -> void:
    var tween = create_tween()
    if active:
        tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
    else:
        tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

# ── Animación en Azkaban (pulsa en rojo) ─────────────────────────
func play_jail_animation() -> void:
    var tween = create_tween().set_loops(3)
    tween.tween_property(self, "modulate", Color.RED, 0.2)
    tween.tween_property(self, "modulate", Color.WHITE, 0.2)
