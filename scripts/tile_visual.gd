# scripts/tile_visual.gd
extends Node2D

var tile_data:    Dictionary = {}
var tile_size:    Vector2    = Vector2(65.0, 110.0)
var shield_count: int        = 0
var _texture:     Texture2D  = null

signal pressed

# Tipos que NO llevan franja de color
const NO_STRIPE_TYPES: Array = [
    "owl_letters", "tax", "spell", "common_room", "jail",
    "go_to_jail", "go", "free_parking", "punishment"
]

# Tipos de esquina — imagen completa, sin texto
const CORNER_TYPES: Array = [
    "go", "jail", "go_to_jail", "free_parking", "punishment"
]

const GROUP_COLORS: Dictionary = {
    "brown":       Color("#6B3A2A"),
    "sky_blue":    Color("#87CEEB"),
    "sky blue":    Color("#87CEEB"),
    "cyan":        Color("#87CEEB"),
    "magenta":     Color("#C71585"),
    "orange":      Color("#FF8C00"),
    "red":         Color("#CC0000"),
    "yellow":      Color("#FFD700"),
    "green":       Color("#2E8B57"),
    "blue":        Color("#00008B"),
    "common_room": Color("#4B0082"),
    "spell":       Color("#9400D3"),
}

const COLOR_BG:     Color = Color("#1A1208")
const COLOR_BORDER: Color = Color("#C9A84C")
const COLOR_TEXT:   Color = Color("#F5E6B0")
const COLOR_PRICE:  Color = Color("#FFD700")
const STRIPE_H:     float = 22.0

# ─────────────────────────────────────────────────────────────────
func setup(data: Dictionary, size: Vector2, rot: float) -> void:
    tile_data        = data
    tile_size        = size
    rotation_degrees = rot
    _try_load_texture()
    queue_redraw()

func _try_load_texture() -> void:
    var tile_id = int(tile_data.get("id", -1))
    if tile_id < 0:
        return
    var path = "res://assets/sprites/tiles/tile_%d.png" % tile_id
    if ResourceLoader.exists(path):
        _texture = load(path)

# ─────────────────────────────────────────────────────────────────
func _draw() -> void:
    if tile_data.is_empty():
        return

    var tile_type  = tile_data.get("type", "property")
    var is_corner  = tile_type in CORNER_TYPES
    var has_stripe = tile_type not in NO_STRIPE_TYPES
    var w = tile_size.x
    var h = tile_size.y

    # Fondo base
    draw_rect(Rect2(Vector2.ZERO, tile_size), COLOR_BG)

    # ── ESQUINAS ──────────────────────────────────────────────────
    if is_corner:
        if _texture != null:
            _draw_texture_fitted(Rect2(Vector2.ZERO, tile_size))
        draw_rect(Rect2(Vector2.ZERO, tile_size), COLOR_BORDER, false, 2.0)
        if _texture == null:
            _draw_centered_text(tile_data.get("name", ""), w, h, 12)
        return

    # ── CASILLAS CON FRANJA DE COLOR ──────────────────────────────
    if has_stripe:
        var color_group = tile_data.get("color_group", "")
        if color_group != "" and GROUP_COLORS.has(color_group):
            draw_rect(Rect2(Vector2(1.0, 1.0), Vector2(w - 2.0, STRIPE_H)),
                GROUP_COLORS[color_group])
        # Imagen ocupa el espacio bajo la franja, manteniendo proporciones
        if _texture != null:
            var img_rect = Rect2(Vector2(1.0, STRIPE_H), Vector2(w - 2.0, h - STRIPE_H - 1.0))
            _draw_texture_fitted(img_rect)
    else:
        # ── CASILLAS SIN FRANJA — imagen ocupa todo ────────────────
        if _texture != null:
            _draw_texture_fitted(Rect2(Vector2.ZERO, tile_size))

    # Borde dorado siempre encima
    draw_rect(Rect2(Vector2.ZERO, tile_size), COLOR_BORDER, false, 1.0)

    var font = ThemeDB.fallback_font

    # ── NOMBRE en la parte superior ───────────────────────────────
    var name_text = tile_data.get("name", "")
    var name_size = 8
    var name_y_base = (STRIPE_H + name_size + 2.0) if has_stripe else (name_size + 3.0)
    var name_lines  = _wrap(name_text, 9)
    var line_h      = float(name_size) + 1.5

    for i in range(name_lines.size()):
        var sz = font.get_string_size(name_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, name_size)
        var x  = w * 0.5 - sz.x * 0.5
        var y  = name_y_base + i * line_h
        # Sombra para legibilidad sobre imagen
        draw_string(font, Vector2(x + 1, y + 1), name_lines[i],
            HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(0, 0, 0, 0.85))
        draw_string(font, Vector2(x, y), name_lines[i],
            HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, COLOR_TEXT)

    # ── PRECIO en la parte inferior ───────────────────────────────
    if tile_data.has("price") and tile_data.price != null:
        var price_str  = "%d pts" % int(tile_data.price)
        var price_size = 8
        var ps = font.get_string_size(price_str, HORIZONTAL_ALIGNMENT_LEFT, -1, price_size)
        var px = w * 0.5 - ps.x * 0.5
        var py = h - 3.0
        draw_string(font, Vector2(px + 1, py + 1), price_str,
            HORIZONTAL_ALIGNMENT_LEFT, -1, price_size, Color(0, 0, 0, 0.85))
        draw_string(font, Vector2(px, py), price_str,
            HORIZONTAL_ALIGNMENT_LEFT, -1, price_size, COLOR_PRICE)

    # ── ESCUDOS ───────────────────────────────────────────────────
    for i in range(shield_count):
        draw_circle(Vector2(w - 8.0 - i * 9.0, h - 8.0), 3.5, Color("#FFD700"))

# ── Dibuja la textura manteniendo proporciones (cover) ────────────
func _draw_texture_fitted(dest: Rect2) -> void:
    if _texture == null:
        return
    var tex_size = Vector2(_texture.get_width(), _texture.get_height())
    var dest_ratio = dest.size.x / dest.size.y
    var tex_ratio  = tex_size.x / tex_size.y

    var src: Rect2
    if tex_ratio > dest_ratio:
        # Imagen más ancha que el destino — recortamos los lados
        var src_w = tex_size.y * dest_ratio
        var src_x = (tex_size.x - src_w) * 0.5
        src = Rect2(src_x, 0, src_w, tex_size.y)
    else:
        # Imagen más alta que el destino — recortamos arriba y abajo
        var src_h = tex_size.x / dest_ratio
        var src_y = (tex_size.y - src_h) * 0.5
        src = Rect2(0, src_y, tex_size.x, src_h)

    draw_texture_rect_region(_texture, dest, src)

# ── Texto centrado (esquinas sin imagen) ──────────────────────────
func _draw_centered_text(text: String, w: float, h: float, font_size: int) -> void:
    var font  = ThemeDB.fallback_font
    var lines = _wrap(text, 10)
    var line_h = float(font_size) + 3.0
    var total  = lines.size() * line_h
    var start  = h * 0.5 - total * 0.5 + font_size
    for i in range(lines.size()):
        var sz = font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
        var x  = w * 0.5 - sz.x * 0.5
        var y  = start + i * line_h
        draw_string(font, Vector2(x + 1, y + 1), lines[i],
            HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
        draw_string(font, Vector2(x, y), lines[i],
            HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, COLOR_TEXT)

# ── Interacción ───────────────────────────────────────────────────
func _input_event(_viewport, event: InputEvent, _shape_idx) -> void:
    if event is InputEventMouseButton \
    and event.button_index == MOUSE_BUTTON_LEFT \
    and event.pressed:
        pressed.emit()

func set_shields(count: int) -> void:
    shield_count = count
    queue_redraw()

func highlight(active: bool) -> void:
    modulate = Color(1.5, 1.5, 0.5) if active else Color.WHITE

func _wrap(text: String, max_chars: int) -> Array:
    if text.length() <= max_chars:
        return [text]
    var words = text.split(" ")
    var lines = []
    var line  = ""
    for word in words:
        var candidate = (line + " " + word).strip_edges()
        if candidate.length() > max_chars and line != "":
            lines.append(line.strip_edges())
            line = word
        else:
            line = candidate
    if line.strip_edges() != "":
        lines.append(line.strip_edges())
    return lines
