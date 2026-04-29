# scripts/setup_screen.gd
extends Control

@onready var setup_manager: Node = $SetupManager

# Paneles — se crean por código
var panel_count:   Control = null
var panel_config:  Control = null
var panel_board:   Control = null
var panel_summary: Control = null

# Widgets activos
var lbl_slot:       Label         = null
var input_name:     LineEdit      = null
var house_selector: HBoxContainer = null
var token_grid:     GridContainer = null
var btn_back_cfg:   Button        = null

var summary_list: VBoxContainer = null

var _selected_house: String = ""
var _selected_token: String = ""

const HOUSE_COLORS: Dictionary = {
    "Gryffindor": Color("#9B0000"),
    "Hufflepuff":  Color("#B8900A"),
    "Ravenclaw":   Color("#1A3A7A"),
    "Slytherin":   Color("#1A5E2A"),
}
const HOUSE_COLORS_DIM: Dictionary = {
    "Gryffindor": Color("#3A0000"),
    "Hufflepuff":  Color("#3A2E00"),
    "Ravenclaw":   Color("#0A1530"),
    "Slytherin":   Color("#0A2210"),
}

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    # Fondo oscuro
    var bg = ColorRect.new()
    bg.color = Color("#0D0A04")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(bg)

    setup_manager.setup_step_changed.connect(_on_step_changed)
    setup_manager.setup_complete.connect(_on_setup_complete)
    setup_manager.reset()

    _build_all_panels()
    _show_panel(panel_count)

# ── Contenedor raíz centrado ──────────────────────────────────────
func _make_centered_container() -> CenterContainer:
    var cc = CenterContainer.new()
    cc.set_anchors_preset(Control.PRESET_FULL_RECT)
    return cc

func _make_card(min_width: float = 600.0) -> PanelContainer:
    var card = PanelContainer.new()
    card.custom_minimum_size = Vector2(min_width, 0)
    return card

func _make_vbox(spacing: int = 12) -> VBoxContainer:
    var vb = VBoxContainer.new()
    vb.add_theme_constant_override("separation", spacing)
    return vb

func _make_label(text: String, font_size: int = 16, centered: bool = true) -> Label:
    var lbl = Label.new()
    lbl.text = text
    lbl.add_theme_font_size_override("font_size", font_size)
    if centered:
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return lbl

func _make_button(text: String, min_w: float = 140, min_h: float = 48) -> Button:
    var btn = Button.new()
    btn.text = text
    btn.custom_minimum_size = Vector2(min_w, min_h)
    return btn

# ─────────────────────────────────────────────────────────────────
func _build_all_panels() -> void:
    panel_count   = _build_panel_count()
    panel_config  = _build_panel_config()
    panel_board   = _build_panel_board()
    panel_summary = _build_panel_summary()
    for p in [panel_count, panel_config, panel_board, panel_summary]:
        add_child(p)

# ── Panel 1: Número de jugadores ──────────────────────────────────
func _build_panel_count() -> Control:
    var cc   = _make_centered_container()
    var card = _make_card(500)
    var vb   = _make_vbox(16)
    card.add_child(vb)
    cc.add_child(card)

    vb.add_child(_make_label("HogwartsOpoly", 32))
    vb.add_child(_make_label("¿Cuántos jugadores?", 22))

    var sep = Control.new(); sep.custom_minimum_size = Vector2(0, 8)
    vb.add_child(sep)

    var row = HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 12)
    vb.add_child(row)
    for n in range(2, 7):
        var btn = _make_button(str(n), 72, 72)
        btn.add_theme_font_size_override("font_size", 28)
        btn.pressed.connect(func(): setup_manager.set_total_players(n))
        row.add_child(btn)

    var sep2 = Control.new(); sep2.custom_minimum_size = Vector2(0, 8)
    vb.add_child(sep2)

    var btn_back = _make_button("← Volver al menú", 200, 44)
    btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
    vb.add_child(btn_back)

    return cc

# ── Panel 2: Config de jugador ────────────────────────────────────
func _build_panel_config() -> Control:
    var cc   = _make_centered_container()
    var card = _make_card(620)
    var vb   = _make_vbox(14)
    card.add_child(vb)
    cc.add_child(card)

    # Slot label
    lbl_slot = _make_label("Jugador 1 de 2", 22)
    vb.add_child(lbl_slot)

    var sep = Control.new(); sep.custom_minimum_size = Vector2(0, 4)
    vb.add_child(sep)

    # Nombre — centrado con ancho limitado
    vb.add_child(_make_label("Nombre del jugador:", 14))
    var name_center = CenterContainer.new()
    input_name = LineEdit.new()
    input_name.placeholder_text = "Escribe tu nombre..."
    input_name.custom_minimum_size = Vector2(320, 44)
    input_name.alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_center.add_child(input_name)
    vb.add_child(name_center)

    var sep2 = Control.new(); sep2.custom_minimum_size = Vector2(0, 4)
    vb.add_child(sep2)

    # Casa
    vb.add_child(_make_label("Elige tu casa:", 14))
    var house_center = CenterContainer.new()
    house_selector = HBoxContainer.new()
    house_selector.add_theme_constant_override("separation", 10)
    house_center.add_child(house_selector)
    vb.add_child(house_center)

    var sep3 = Control.new(); sep3.custom_minimum_size = Vector2(0, 4)
    vb.add_child(sep3)

    # Token
    vb.add_child(_make_label("Elige tu token:", 14))
    var token_center = CenterContainer.new()
    token_grid = GridContainer.new()
    token_grid.columns = 3
    token_grid.add_theme_constant_override("h_separation", 10)
    token_grid.add_theme_constant_override("v_separation", 10)
    token_center.add_child(token_grid)
    vb.add_child(token_center)

    var sep4 = Control.new(); sep4.custom_minimum_size = Vector2(0, 8)
    vb.add_child(sep4)

    # Botones de acción
    var btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_row.add_theme_constant_override("separation", 12)
    vb.add_child(btn_row)

    var btn_back_count = _make_button("← Número de jugadores", 200, 44)
    btn_back_count.pressed.connect(func(): setup_manager.go_back_to_player_count())
    btn_row.add_child(btn_back_count)

    btn_back_cfg = _make_button("← Jugador anterior", 180, 44)
    btn_back_cfg.pressed.connect(func(): setup_manager.undo_last_player())
    btn_row.add_child(btn_back_cfg)

    var btn_confirm = _make_button("Confirmar →", 160, 44)
    btn_confirm.pressed.connect(_on_confirm_pressed)
    btn_row.add_child(btn_confirm)

    return cc

# ── Panel 3: Tablero ──────────────────────────────────────────────
func _build_panel_board() -> Control:
    var cc   = _make_centered_container()
    var card = _make_card(500)
    var vb   = _make_vbox(16)
    card.add_child(vb)
    cc.add_child(card)

    vb.add_child(_make_label("Selecciona el tablero", 24))

    var sep = Control.new(); sep.custom_minimum_size = Vector2(0, 8)
    vb.add_child(sep)

    var btn_default = _make_button("Tablero clásico de Hogwarts", 300, 60)
    btn_default.add_theme_font_size_override("font_size", 16)
    btn_default.pressed.connect(func(): setup_manager.use_default_board())
    var btn_default_center = CenterContainer.new()
    btn_default_center.add_child(btn_default)
    vb.add_child(btn_default_center)

    var sep2 = Control.new(); sep2.custom_minimum_size = Vector2(0, 8)
    vb.add_child(sep2)

    var btn_back = _make_button("← Volver a jugadores", 200, 44)
    btn_back.pressed.connect(func(): setup_manager.go_back_to_player_config())
    var back_center = CenterContainer.new()
    back_center.add_child(btn_back)
    vb.add_child(back_center)

    return cc

# ── Panel 4: Resumen ──────────────────────────────────────────────
func _build_panel_summary() -> Control:
    var cc   = _make_centered_container()
    var card = _make_card(600)
    var vb   = _make_vbox(16)
    card.add_child(vb)
    cc.add_child(card)

    vb.add_child(_make_label("Resumen de jugadores", 24))

    var sep = Control.new(); sep.custom_minimum_size = Vector2(0, 4)
    vb.add_child(sep)

    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 180)
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vb.add_child(scroll)

    summary_list = VBoxContainer.new()
    summary_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    summary_list.add_theme_constant_override("separation", 6)
    scroll.add_child(summary_list)

    var sep2 = Control.new(); sep2.custom_minimum_size = Vector2(0, 8)
    vb.add_child(sep2)

    var btn_row = HBoxContainer.new()
    btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
    btn_row.add_theme_constant_override("separation", 20)
    vb.add_child(btn_row)

    var btn_back = _make_button("← Cambiar tablero", 180, 48)
    btn_back.pressed.connect(func(): setup_manager.go_back_to_player_config())
    btn_row.add_child(btn_back)

    var btn_start = _make_button("¡Comenzar partida! →", 220, 56)
    btn_start.add_theme_font_size_override("font_size", 18)
    btn_start.pressed.connect(setup_manager.confirm_setup)
    btn_row.add_child(btn_start)

    return cc

# ── Navegación ────────────────────────────────────────────────────
func _on_step_changed(step: int) -> void:
    match step:
        1: _show_panel(panel_count)
        2:
            _refresh_player_config()
            _show_panel(panel_config)
        3: _show_panel(panel_board)
        4:
            _build_summary_list()
            _show_panel(panel_summary)

func _show_panel(panel: Control) -> void:
    for p in [panel_count, panel_config, panel_board, panel_summary]:
        if p != null:
            p.visible = false
    if panel != null:
        panel.visible = true

# ── Refresh config jugador ────────────────────────────────────────
func _refresh_player_config() -> void:
    _selected_house = ""
    _selected_token = ""

    if lbl_slot:
        lbl_slot.text = setup_manager.get_current_slot_label()
    if input_name:
        input_name.text = ""
        input_name.grab_focus()
    if btn_back_cfg:
        btn_back_cfg.visible = setup_manager.current_player_idx > 0

    # Reconstruir casas
    if house_selector:
        for child in house_selector.get_children():
            child.queue_free()
        for house in GameState.HOUSES:
            var btn = Button.new()
            btn.text = house
            btn.custom_minimum_size = Vector2(130, 52)
            _set_house_style(btn, house, false)
            btn.add_theme_color_override("font_color", Color("#E8D5A3"))
            btn.pressed.connect(func(): _select_house(house, btn))
            house_selector.add_child(btn)

    # Reconstruir tokens — solo los no tomados
    if token_grid:
        for child in token_grid.get_children():
            child.queue_free()
        for token in setup_manager.get_available_tokens():
            var btn = Button.new()
            btn.text = token.name
            btn.custom_minimum_size = Vector2(160, 52)
            btn.pressed.connect(func(): _select_token(token.id, btn))
            token_grid.add_child(btn)

func _set_house_style(btn: Button, house: String, selected: bool) -> void:
    var style = StyleBoxFlat.new()
    style.bg_color     = HOUSE_COLORS.get(house, Color("#555")) if selected \
                         else HOUSE_COLORS_DIM.get(house, Color("#222"))
    style.border_color = Color("#FFD700") if selected else Color("#C9A84C")
    style.set_border_width_all(2 if selected else 1)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(8)
    btn.add_theme_stylebox_override("normal",  style)
    btn.add_theme_stylebox_override("hover",   style)
    btn.add_theme_stylebox_override("pressed", style)

func _select_house(house: String, btn: Button) -> void:
    _selected_house = house
    if house_selector:
        for child in house_selector.get_children():
            _set_house_style(child, child.text, false)
    _set_house_style(btn, house, true)

func _select_token(token_id: String, btn: Button) -> void:
    _selected_token = token_id
    if token_grid:
        for child in token_grid.get_children():
            child.modulate = Color.WHITE
    btn.modulate = Color(1.5, 1.3, 0.3)

func _on_confirm_pressed() -> void:
    if _selected_house == "":
        if house_selector: _shake(house_selector)
        return
    if _selected_token == "":
        if token_grid: _shake(token_grid)
        return
    var name_text = input_name.text.strip_edges() if input_name else ""
    if name_text == "":
        name_text = "Jugador %d" % (setup_manager.current_player_idx + 1)
    setup_manager.confirm_player(name_text, _selected_house, _selected_token)

# ── Resumen ───────────────────────────────────────────────────────
func _build_summary_list() -> void:
    if summary_list == null:
        return
    for child in summary_list.get_children():
        child.queue_free()
    for player in setup_manager.configured_players:
        var row = HBoxContainer.new()
        row.custom_minimum_size = Vector2(0, 48)
        row.add_theme_constant_override("separation", 10)

        var stripe = ColorRect.new()
        stripe.color = HOUSE_COLORS.get(player.get("house", ""), Color.GRAY)
        stripe.custom_minimum_size = Vector2(8, 48)
        row.add_child(stripe)

        var lbl = Label.new()
        lbl.text = "  %s  —  %s  —  %s" % [
            player.get("name", "?"),
            player.get("house", "?"),
            player.get("token", "?")
        ]
        lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(lbl)
        summary_list.add_child(row)

# ── Ir al juego ───────────────────────────────────────────────────
func _on_setup_complete(_players: Array, _board_path: String) -> void:
    var overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)
    var tween = create_tween()
    tween.tween_property(overlay, "color:a", 1.0, 0.4)
    tween.tween_callback(func():
        get_tree().change_scene_to_file("res://scenes/board.tscn")
    )

# ── Shake de error ────────────────────────────────────────────────
func _shake(node: Control) -> void:
    var origin = node.position
    var tween  = create_tween()
    tween.tween_property(node, "position", origin + Vector2(8, 0), 0.05)
    tween.tween_property(node, "position", origin - Vector2(8, 0), 0.05)
    tween.tween_property(node, "position", origin + Vector2(5, 0), 0.04)
    tween.tween_property(node, "position", origin, 0.04)
