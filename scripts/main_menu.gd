# scripts/main_menu.gd
extends Control

const SCENE_SETUP:  String = "res://scenes/setup_screen.tscn"
const SCENE_BOARD:  String = "res://scenes/board.tscn"
const SCENE_EDITOR: String = "res://scenes/board_editor.tscn"

@onready var btn_new_game: Button  = $CenterContainer/VBox/BtnNewGame
@onready var btn_load:     Button  = $CenterContainer/VBox/BtnLoad
@onready var btn_editor:   Button  = $CenterContainer/VBox/BtnEditor
@onready var btn_rules:    Button  = $CenterContainer/VBox/BtnRules
@onready var btn_quit:     Button  = $CenterContainer/VBox/BtnQuit
@onready var lbl_title:    Label   = $TitleContainer/LblTitle
@onready var lbl_subtitle: Label   = $TitleContainer/LblSubtitle
@onready var lbl_version:  Label   = $LblVersion
@onready var rules_panel:  Control = $RulesPanel

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    _connect_buttons()
    _animate_title()
    if rules_panel:
        rules_panel.visible = false
    if lbl_version:
        lbl_version.text = "v0.1 — Alpha"

func _connect_buttons() -> void:
    if btn_new_game: btn_new_game.pressed.connect(_on_new_game)
    if btn_load:     btn_load.pressed.connect(_on_load_game)
    if btn_editor:   btn_editor.pressed.connect(_on_open_editor)
    if btn_rules:    btn_rules.pressed.connect(_on_show_rules)
    if btn_quit:     btn_quit.pressed.connect(_on_quit)
    if btn_load:     btn_load.disabled = not SaveSystem.has_save()

func _animate_title() -> void:
    if lbl_title == null:
        return
    lbl_title.modulate.a = 0.0
    var tween = create_tween()
    tween.tween_property(lbl_title, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)
    if lbl_subtitle:
        lbl_subtitle.modulate.a = 0.0
        tween.tween_property(lbl_subtitle, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)

func _on_new_game() -> void:
    GameState.players            = []
    GameState.board_data         = {}
    GameState.current_player_index = 0
    GameState.turn_count         = 0
    _fade_to(SCENE_SETUP)

func _on_load_game() -> void:
    var save_data = SaveSystem.load_game()
    if save_data.is_empty():
        return
    GameState.players              = save_data.get("players", [])
    GameState.current_player_index = save_data.get("current_player_index", 0)
    GameState.turn_count           = save_data.get("turn_count", 0)
    var board_name = save_data.get("board_name", "")
    var board_path = "res://data/default_board.json"
    if board_name != "" and board_name != "Mundo Mágico Clásico":
        board_path = SaveSystem.BOARDS_DIR + board_name + ".json"
    GameState.board_data = SaveSystem.load_board(board_path)
    _fade_to(SCENE_BOARD)

func _on_open_editor() -> void:
    _fade_to(SCENE_EDITOR)

func _on_show_rules() -> void:
    if rules_panel:
        rules_panel.visible = not rules_panel.visible

func _on_quit() -> void:
    get_tree().quit()

func _fade_to(scene_path: String) -> void:
    var overlay = ColorRect.new()
    overlay.color = Color(0, 0, 0, 0)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(overlay)
    var tween = create_tween()
    tween.tween_property(overlay, "color:a", 1.0, 0.4)
    tween.tween_callback(func(): get_tree().change_scene_to_file(scene_path))
