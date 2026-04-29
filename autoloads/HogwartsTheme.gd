# autoloads/HogwartsTheme.gd
# Crea y aplica el tema visual estilo Hogwarts Legacy a toda la UI.
# Se registra como Autoload para que esté disponible globalmente.
extends Node

# ── Paleta ────────────────────────────────────────────────────────
const C_BG_DARK:    Color = Color("#0D0A04")
const C_BG_PANEL:   Color = Color("#1A1208")
const C_BG_INPUT:   Color = Color("#2C1810")
const C_GOLD:       Color = Color("#C9A84C")
const C_GOLD_DARK:  Color = Color("#8B6914")
const C_GOLD_LIGHT: Color = Color("#F5E6B0")
const C_TEXT:       Color = Color("#E8D5A3")
const C_TEXT_DIM:   Color = Color("#8B9B6B")
const C_BORDER:     Color = Color("#5A3E1B")

var theme: Theme = null

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    theme = _build_theme()
    # Aplicamos el tema a la ventana raíz para que afecte a toda la UI
    get_tree().root.theme = theme

func get_theme() -> Theme:
    return theme

# ─────────────────────────────────────────────────────────────────
func _build_theme() -> Theme:
    var t = Theme.new()

    # ── StyleBoxes base ───────────────────────────────────────────
    var panel_style   = _make_panel_style(C_BG_PANEL, C_BORDER, 2.0, 8.0)
    var dark_style    = _make_panel_style(C_BG_DARK,  C_GOLD_DARK, 1.0, 6.0)
    var input_style   = _make_panel_style(C_BG_INPUT, C_GOLD_DARK, 1.5, 4.0)
    var button_normal = _make_panel_style(C_BG_DARK,  C_GOLD_DARK, 1.0, 6.0)
    var button_hover  = _make_panel_style(C_BG_INPUT, C_GOLD,      1.5, 6.0)
    var button_pressed= _make_panel_style(Color("#3D2E0A"), C_GOLD, 2.0, 6.0)
    var button_disabled=_make_panel_style(C_BG_DARK,  C_BORDER,    1.0, 6.0)

    # ── Panel ─────────────────────────────────────────────────────
    t.set_stylebox("panel", "Panel", panel_style)
    t.set_stylebox("panel", "PanelContainer", panel_style)

    # ── Button ────────────────────────────────────────────────────
    t.set_stylebox("normal",   "Button", button_normal)
    t.set_stylebox("hover",    "Button", button_hover)
    t.set_stylebox("pressed",  "Button", button_pressed)
    t.set_stylebox("disabled", "Button", button_disabled)
    t.set_stylebox("focus",    "Button", button_hover)
    t.set_color("font_color",          "Button", C_GOLD)
    t.set_color("font_hover_color",    "Button", C_GOLD_LIGHT)
    t.set_color("font_pressed_color",  "Button", C_GOLD_LIGHT)
    t.set_color("font_disabled_color", "Button", C_TEXT_DIM)
    t.set_constant("outline_size", "Button", 0)

    # ── Label ─────────────────────────────────────────────────────
    t.set_color("font_color",         "Label", C_TEXT)
    t.set_color("font_shadow_color",  "Label", Color(0, 0, 0, 0.6))
    t.set_constant("shadow_offset_x", "Label", 1)
    t.set_constant("shadow_offset_y", "Label", 1)

    # ── RichTextLabel ─────────────────────────────────────────────
    t.set_color("default_color",      "RichTextLabel", C_TEXT)
    t.set_stylebox("normal", "RichTextLabel", dark_style)

    # ── LineEdit ─────────────────────────────────────────────────
    t.set_stylebox("normal", "LineEdit", input_style)
    t.set_stylebox("focus",  "LineEdit", _make_panel_style(C_BG_INPUT, C_GOLD, 2.0, 4.0))
    t.set_color("font_color",            "LineEdit", C_TEXT)
    t.set_color("font_placeholder_color","LineEdit", C_TEXT_DIM)
    t.set_color("caret_color",           "LineEdit", C_GOLD)

    # ── SpinBox ───────────────────────────────────────────────────
    t.set_stylebox("normal", "SpinBox", input_style)
    t.set_color("font_color", "SpinBox", C_TEXT)

    # ── ScrollContainer ───────────────────────────────────────────
    t.set_stylebox("panel", "ScrollContainer", dark_style)

    # ── ProgressBar ───────────────────────────────────────────────
    var pb_bg   = _make_panel_style(C_BG_DARK,  C_BORDER,    1.0, 4.0)
    var pb_fill = _make_panel_style(C_GOLD_DARK, C_GOLD,     1.0, 4.0)
    t.set_stylebox("background", "ProgressBar", pb_bg)
    t.set_stylebox("fill",       "ProgressBar", pb_fill)

    # ── Separador ─────────────────────────────────────────────────
    var sep_style = StyleBoxLine.new()
    sep_style.color = C_BORDER
    sep_style.thickness = 1
    t.set_stylebox("separator", "HSeparator", sep_style)

    return t

# ── Helpers ───────────────────────────────────────────────────────
func _make_panel_style(bg: Color, border: Color, border_w: float, radius: float) -> StyleBoxFlat:
    var s = StyleBoxFlat.new()
    s.bg_color             = bg
    s.border_color         = border
    s.set_border_width_all(int(border_w))
    s.set_corner_radius_all(int(radius))
    s.anti_aliasing         = 1
    s.set_content_margin_all(8)
    return s

# ── API para crear estilos desde otros scripts ────────────────────
func make_gold_panel(radius: float = 8.0) -> StyleBoxFlat:
    return _make_panel_style(C_BG_PANEL, C_GOLD, 2.0, radius)

func make_dark_panel(radius: float = 6.0) -> StyleBoxFlat:
    return _make_panel_style(C_BG_DARK, C_BORDER, 1.0, radius)
