# scripts/tile.gd
# Una sola clase para las 40 casillas del tablero.
# Cada instancia recibe sus datos del JSON mediante setup().
extends Area2D

# ── Datos de esta casilla (cargados desde el JSON) ─────────────────
var tile_data: Dictionary = {}

# ── Señales ───────────────────────────────────────────────────────
signal clicked

# ── Nodos hijos (conéctales en tile.tscn) ─────────────────────────
@onready var label:       Label         = $Label
@onready var color_rect:  ColorRect     = $ColorRect
@onready var collision:   CollisionShape2D = $CollisionShape2D

# ─────────────────────────────────────────────────────────────────
func setup(data: Dictionary) -> void:
    tile_data = data
    if label:
        label.text = data.get("name", "")
    _apply_color()

func _apply_color() -> void:
    if color_rect == null:
        return
    var color_group = tile_data.get("color_group", null)
    if color_group == null:
        return
    color_rect.color = _group_to_color(color_group)

func _group_to_color(group: String) -> Color:
    match group:
        "brown":       return Color("#6B3A2A")
        "sky_blue":    return Color("#87CEEB")
        "magenta":     return Color("#C71585")
        "orange":      return Color("#FF8C00")
        "red":         return Color("#CC0000")
        "yellow":      return Color("#FFD700")
        "green":       return Color("#2E8B57")
        "blue":        return Color("#00008B")
        "common_room": return Color("#4B0082")
        "spell":       return Color("#9400D3")
        _:             return Color("#888888")

# ── Detección de clic ─────────────────────────────────────────────
func _on_input_event(_viewport, event: InputEvent, _shape_idx) -> void:
    if event is InputEventMouseButton and event.pressed:
        clicked.emit()

# ── Lógica de renta ───────────────────────────────────────────────

# Calcula cuánto debe pagar landing_player al owner al caer en esta casilla.
# Retorna 0 si la casilla no cobra renta o si aplica una exención.
func calculate_rent(landing_player: Dictionary, owner: Dictionary) -> int:
    # Exención por casa (salas comunes)
    if tile_data.has("landing_rules"):
        var rules = tile_data.landing_rules
        if rules.has("if_visitor_is_owner_house"):
            var ex = rules.if_visitor_is_owner_house
            if landing_player.get("house", "") == ex.house and ex.get("exempt_from_rent", false):
                return 0

    # Hechizos: renta basada en dados
    if tile_data.has("rent_rule"):
        return _calculate_spell_rent(tile_data.rent_rule, owner)

    # Propiedad normal: renta según escudos
    if tile_data.has("rent"):
        var shields: int = _count_shields(owner)
        var rent_table: Array = tile_data.rent
        shields = clamp(shields, 0, rent_table.size() - 1)
        return rent_table[shields]

    return 0

func _calculate_spell_rent(rule: Dictionary, owner: Dictionary) -> int:
    var spells_owned: int = 0
    for prop in owner.get("properties", []):
        if prop.get("type", "") == "spell":
            spells_owned += 1

    var variant: Dictionary
    if spells_owned >= 2:
        variant = rule.condition_variants.both
    else:
        variant = rule.condition_variants.one

    var dice_parts = variant.formula.split("d")
    var num_dice   = int(dice_parts[0])
    var faces      = int(dice_parts[1])

    var results: Array = []
    for i in range(num_dice):
        results.append(randi_range(1, faces))

    var dice_total: int = 0
    match variant.rule:
        "take_highest": dice_total = results.max()
        "take_both":    dice_total = results.reduce(func(a, b): return a + b)

    return dice_total * variant.get("multiplier", 1)

func _count_shields(owner: Dictionary) -> int:
    var count: int = 0
    for prop in owner.get("properties", []):
        if prop.get("id", -1) == tile_data.get("id", -2):
            count = prop.get("shields", 0)
    return count

# ── Tipo de casilla ────────────────────────────────────────────────
func get_type() -> String:
    return tile_data.get("type", "")

func is_ownable() -> bool:
    return get_type() in ["property", "spell"]
