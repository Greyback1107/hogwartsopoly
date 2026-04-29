# scripts/hud.gd
extends CanvasLayer

var top_bar:         HBoxContainer  = null
var lbl_turn:        Label          = null
var lbl_phase:       Label          = null
var players_panel:   PanelContainer = null
var vbox_players:    VBoxContainer  = null
var log_panel:       PanelContainer = null
var log_label:       RichTextLabel  = null
var action_bar:      HBoxContainer  = null
var btn_roll:        Button         = null
var btn_end_turn:    Button         = null
var btn_properties:  Button         = null
var purchase_panel:  PanelContainer = null
var pp_name:         Label          = null
var pp_price:        Label          = null
var pp_rent:         RichTextLabel  = null
var pp_btn_buy:      Button         = null
var pp_btn_decline:  Button         = null
var auction_panel:   PanelContainer = null
var ap_title:        Label          = null
var ap_current_bid:  Label          = null
var ap_bidder:       Label          = null
var ap_input_bid:    SpinBox        = null
var ap_btn_bid:      Button         = null
var ap_btn_pass:     Button         = null
var ap_bidders_list: VBoxContainer  = null
var props_panel:     PanelContainer = null
var props_vbox:      VBoxContainer  = null
var game_over_overlay: ColorRect    = null
var lbl_winner:      Label          = null
var _game_manager:   Node           = null

const HOUSE_COLORS: Dictionary = {
    "Gryffindor": Color("#740001"),
    "Hufflepuff":  Color("#FFD800"),
    "Ravenclaw":   Color("#0E1A40"),
    "Slytherin":   Color("#1A472A"),
}

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    top_bar         = get_node_or_null("TopBar")
    lbl_turn        = get_node_or_null("TopBar/LblTurn")
    lbl_phase       = get_node_or_null("TopBar/LblPhase")
    players_panel   = get_node_or_null("PlayersPanel")
    vbox_players    = get_node_or_null("PlayersPanel/VBox")
    log_panel       = get_node_or_null("LogPanel")
    log_label       = get_node_or_null("LogPanel/RichTextLabel")
    action_bar      = get_node_or_null("ActionBar")
    btn_roll        = get_node_or_null("ActionBar/BtnRoll")
    btn_end_turn    = get_node_or_null("ActionBar/BtnEndTurn")
    btn_properties  = get_node_or_null("ActionBar/BtnProperties")
    purchase_panel  = get_node_or_null("PurchasePanel")
    pp_name         = get_node_or_null("PurchasePanel/VBox/LblName")
    pp_price        = get_node_or_null("PurchasePanel/VBox/LblPrice")
    pp_rent         = get_node_or_null("PurchasePanel/VBox/LblRent")
    pp_btn_buy      = get_node_or_null("PurchasePanel/VBox/Buttons/BtnBuy")
    pp_btn_decline  = get_node_or_null("PurchasePanel/VBox/Buttons/BtnDecline")
    auction_panel   = get_node_or_null("AuctionPanel")
    ap_title        = get_node_or_null("AuctionPanel/VBox/LblTitle")
    ap_current_bid  = get_node_or_null("AuctionPanel/VBox/LblCurrentBid")
    ap_bidder       = get_node_or_null("AuctionPanel/VBox/LblBidder")
    ap_input_bid    = get_node_or_null("AuctionPanel/VBox/HBoxContainer/InputBid")
    ap_btn_bid      = get_node_or_null("AuctionPanel/VBox/HBoxContainer/BtnBid")
    ap_btn_pass     = get_node_or_null("AuctionPanel/VBox/HBoxContainer/BtnPass")
    ap_bidders_list = get_node_or_null("AuctionPanel/VBox/BiddersList")
    props_panel     = get_node_or_null("PropertiesPanel")
    props_vbox      = get_node_or_null("PropertiesPanel/VBox")
    game_over_overlay = get_node_or_null("GameOverOverlay")
    lbl_winner      = get_node_or_null("GameOverOverlay/LblWinner")

    _apply_layout()
    _build_players_panel()
    # Esperamos al siguiente frame para que GameManager esté listo
    call_deferred("_connect_signals")

# ── Layout ────────────────────────────────────────────────────────
func _apply_layout() -> void:
    if top_bar == null:
        push_error("HUD: TopBar no encontrado")
        return

    top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
    top_bar.set_offsets_preset(Control.PRESET_TOP_WIDE)
    top_bar.custom_minimum_size = Vector2(0, 48)
    top_bar.add_theme_constant_override("separation", 16)

    if players_panel:
        players_panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
        players_panel.offset_top   = 48
        players_panel.offset_right = 180

    if log_panel:
        log_panel.set_anchor_and_offset(SIDE_LEFT,   0,  180)
        log_panel.set_anchor_and_offset(SIDE_TOP,    1, -180)
        log_panel.set_anchor_and_offset(SIDE_RIGHT,  0,  580)
        log_panel.set_anchor_and_offset(SIDE_BOTTOM, 1,   -8)
    if log_label:
        log_label.bbcode_enabled = true
        log_label.scroll_active  = true

    if action_bar:
        action_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        action_bar.set_offsets_preset(Control.PRESET_BOTTOM_WIDE)
        action_bar.custom_minimum_size = Vector2(0, 52)
        action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
        action_bar.add_theme_constant_override("separation", 12)

    if purchase_panel:
        purchase_panel.set_anchors_preset(Control.PRESET_CENTER)
        purchase_panel.custom_minimum_size = Vector2(340, 280)
        purchase_panel.offset_left   = -170
        purchase_panel.offset_top    = -140
        purchase_panel.offset_right  =  170
        purchase_panel.offset_bottom =  140
        purchase_panel.visible = false

    if auction_panel:
        auction_panel.set_anchors_preset(Control.PRESET_CENTER)
        auction_panel.custom_minimum_size = Vector2(340, 380)
        auction_panel.offset_left   = -170
        auction_panel.offset_top    = -190
        auction_panel.offset_right  =  170
        auction_panel.offset_bottom =  190
        auction_panel.visible = false
        
        var hbox = get_node_or_null("AuctionPanel/VBox/HBoxContainer")
        if hbox:
            hbox.alignment = BoxContainer.ALIGNMENT_CENTER
            hbox.add_theme_constant_override("separation", 12)
        if ap_btn_bid:  ap_btn_bid.custom_minimum_size  = Vector2(140, 44)
        if ap_btn_pass: ap_btn_pass.custom_minimum_size = Vector2(140, 44)

    # Forzar tamaño mínimo en los botones de subasta
    var btn_bid  = get_node_or_null("AuctionPanel/VBox/Buttons/BtnBid")
    var btn_pass = get_node_or_null("AuctionPanel/VBox/Buttons/BtnPass")
    if btn_bid:  btn_bid.custom_minimum_size  = Vector2(140, 44)
    if btn_pass: btn_pass.custom_minimum_size = Vector2(140, 44)

    var vbox_auction = get_node_or_null("AuctionPanel/VBox")
    if vbox_auction:
        vbox_auction.add_theme_constant_override("separation", 10)

    var buttons_row = get_node_or_null("AuctionPanel/VBox/Buttons")
    if buttons_row:
        buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
        buttons_row.add_theme_constant_override("separation", 12)

    if props_panel:
        props_panel.set_anchor_and_offset(SIDE_LEFT,   0,  180)
        props_panel.set_anchor_and_offset(SIDE_TOP,    0,   48)
        props_panel.set_anchor_and_offset(SIDE_RIGHT,  0,  480)
        props_panel.set_anchor_and_offset(SIDE_BOTTOM, 0,  400)
        props_panel.visible = false
        
        if props_vbox:
            props_vbox.add_theme_constant_override("separation", 4)

    if game_over_overlay:
        game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
        game_over_overlay.color   = Color(0, 0, 0, 0.82)
        game_over_overlay.visible = false
    if lbl_winner:
        lbl_winner.set_anchors_preset(Control.PRESET_CENTER)
        lbl_winner.add_theme_font_size_override("font_size", 36)
        lbl_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ── Señales ───────────────────────────────────────────────────────
func _connect_signals() -> void:
    var parent = get_parent()
    if parent:
        _game_manager = parent.get_node_or_null("GameManager")
    if _game_manager == null:
        # Segundo intento con búsqueda global
        _game_manager = get_tree().root.find_child("GameManager", true, false)
    if _game_manager == null:
        push_error("HUD: GameManager no encontrado")
        return

    _game_manager.turn_started.connect(_on_turn_started)
    _game_manager.turn_ended.connect(_on_turn_ended)
    _game_manager.log_message.connect(_on_log_message)
    _game_manager.request_tile_choice.connect(_on_request_tile_choice)
    _game_manager.request_player_choice.connect(_on_request_player_choice)
    _game_manager.game_over.connect(_on_game_over)

    var pm = _game_manager.get_node_or_null("PurchaseManager")
    if pm:
        pm.show_purchase_ui.connect(_show_purchase_panel)
        pm.hide_purchase_ui.connect(func():
            if purchase_panel: 
                purchase_panel.visible = false)
    if pp_btn_buy:
        # Desconectamos primero para evitar doble conexión
        if pp_btn_buy.pressed.is_connected(pm.on_player_accepts):
            pp_btn_buy.pressed.disconnect(pm.on_player_accepts)
        pp_btn_buy.pressed.connect(pm.on_player_accepts)
    if pp_btn_decline:
        if pp_btn_decline.pressed.is_connected(pm.on_player_declines):
            pp_btn_decline.pressed.disconnect(pm.on_player_declines)
        pp_btn_decline.pressed.connect(pm.on_player_declines)

    var am = _game_manager.get_node_or_null("AuctionManager")
    if am:
        am.bid_requested.connect(_on_bid_requested)
        am.auction_won.connect(_on_auction_ended)
        am.auction_cancelled.connect(func(_t): _on_auction_ended(null, {}, 0))
        am.new_round_started.connect(_on_new_round)
        am.bidder_eliminated.connect(_on_bidder_eliminated)
        
    print("pp_btn_buy es: ", pp_btn_buy)
    print("pp_btn_decline es: ", pp_btn_decline)
    print("pm es: ", _game_manager.get_node_or_null("PurchaseManager"))
    
    print("ap_btn_bid: ", ap_btn_bid)
    print("ap_btn_pass: ", ap_btn_pass)
    print("am: ", _game_manager.get_node_or_null("AuctionManager"))

    if btn_roll:       btn_roll.pressed.connect(_game_manager.player_roll_dice)
    if btn_end_turn:   btn_end_turn.pressed.connect(_game_manager.end_turn_requested)
    if btn_properties: btn_properties.pressed.connect(_toggle_properties_panel)

    if pm:
        if pp_btn_buy:
            if not pp_btn_buy.pressed.is_connected(pm.on_player_accepts):
                pp_btn_buy.pressed.connect(pm.on_player_accepts)
    if pp_btn_decline:
            if not pp_btn_decline.pressed.is_connected(pm.on_player_declines):
                pp_btn_decline.pressed.connect(pm.on_player_declines)
    if am:
        if ap_btn_bid:  ap_btn_bid.pressed.connect(_on_place_bid)
        if ap_btn_pass: ap_btn_pass.pressed.connect(am.on_bid_passed)
        
    var pm2 = _game_manager.get_node_or_null("PurchaseManager")
    if pm2:
            if pp_btn_buy and not pp_btn_buy.pressed.is_connected(pm2.on_player_accepts):    pp_btn_buy.pressed.connect(pm2.on_player_accepts)
            if pp_btn_decline and not pp_btn_decline.pressed.is_connected(pm2.on_player_declines):    pp_btn_decline.pressed.connect(pm2.on_player_declines)
            
    # Conectar actualización de puntos de cada jugador
    for i in range(GameState.players.size()):
        var p_node = get_tree().root.find_child("Player_%d" % i, true, false)
        if p_node and p_node.has_signal("points_changed"):
            var idx = i
            p_node.points_changed.connect(func(new_pts): update_player_points(idx, new_pts))

# ── Panel de jugadores ────────────────────────────────────────────
func _build_players_panel() -> void:
    if vbox_players == null:
        return
    for child in vbox_players.get_children():
        child.queue_free()
    for i in range(GameState.players.size()):
        vbox_players.add_child(_make_player_card(GameState.players[i], i))

func _make_player_card(player_data: Dictionary, index: int) -> Control:
    var card = PanelContainer.new()
    card.name = "Card_%d" % index
    card.custom_minimum_size = Vector2(0, 72)
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 2)
    var stripe = ColorRect.new()
    stripe.color = HOUSE_COLORS.get(player_data.get("house", ""), Color.GRAY)
    stripe.custom_minimum_size = Vector2(0, 5)
    vbox.add_child(stripe)
    var name_lbl = Label.new()
    name_lbl.text = player_data.get("name", "")
    name_lbl.add_theme_font_size_override("font_size", 14)
    vbox.add_child(name_lbl)
    var house_lbl = Label.new()
    house_lbl.text = player_data.get("house", "")
    house_lbl.add_theme_font_size_override("font_size", 11)
    vbox.add_child(house_lbl)
    var pts_lbl = Label.new()
    pts_lbl.name = "PtsLabel"
    pts_lbl.text = "%d pts" % player_data.get("points", 0)
    pts_lbl.add_theme_font_size_override("font_size", 15)
    vbox.add_child(pts_lbl)
    card.add_child(vbox)
    return card

func update_player_points(player_index: int, new_points: int) -> void:
    if vbox_players == null or player_index >= vbox_players.get_child_count():
        return
    var card = vbox_players.get_child(player_index)
    var lbl  = card.find_child("PtsLabel", true, false)
    if lbl:
        lbl.text = "%d pts" % new_points

func _highlight_active_player(player_index: int) -> void:
    if vbox_players == null:
        return
    for i in range(vbox_players.get_child_count()):
        vbox_players.get_child(i).modulate = \
            Color(1.3, 1.3, 0.5) if i == player_index else Color.WHITE

# ── Log ───────────────────────────────────────────────────────────
func _on_log_message(text: String) -> void:
    if log_label == null:
        return
    log_label.append_text("\n" + text)
    await get_tree().process_frame
    log_label.scroll_to_line(log_label.get_line_count() - 1)

# ── Turno ─────────────────────────────────────────────────────────
func _on_turn_started(player_index: int) -> void:
    if player_index >= GameState.players.size():
        return
    var p = GameState.players[player_index]
    if lbl_turn:    lbl_turn.text  = "Turno de %s" % p.get("name", "")
    if lbl_phase:   lbl_phase.text = p.get("house", "")
    if btn_roll:     btn_roll.disabled     = false
    if btn_end_turn: btn_end_turn.disabled = false
    _highlight_active_player(player_index)

func _on_turn_ended(_idx: int) -> void:
    if btn_roll:     btn_roll.disabled     = true
    if btn_end_turn: btn_end_turn.disabled = true

# ── Panel de compra ───────────────────────────────────────────────
func _show_purchase_panel(_player: Node, tile_data: Dictionary) -> void:
    if purchase_panel == null:
        return
    if pp_name:  pp_name.text  = tile_data.get("name", "")
    if pp_price: pp_price.text = "Precio: %d pts" % tile_data.get("price", 0)
    var rent_text = "[b]Renta:[/b]\n"
    if tile_data.has("rent"):
        var labels = ["Sin escudos","1 escudo","2 escudos","3 escudos"]
        for i in range(tile_data.rent.size()):
            var lbl = labels[i] if i < labels.size() else "%d escudos" % i
            rent_text += "  %s: %d pts\n" % [lbl, tile_data.rent[i]]
    elif tile_data.has("rent_rule"):
        rent_text += "  [i]Basada en dados (hechizo)[/i]"
    if pp_rent:
        pp_rent.bbcode_enabled = true
        pp_rent.text = rent_text
    var current = _game_manager._current_player_node()
    if current and pp_btn_buy:
        pp_btn_buy.disabled = current.points < tile_data.get("price", 0)
    purchase_panel.visible = true
    if btn_roll:     btn_roll.disabled     = true
    if btn_end_turn: btn_end_turn.disabled = true

# ── Panel de subasta ──────────────────────────────────────────────
func _on_bid_requested(player: Node, current_bid: int, min_next_bid: int) -> void:
    if auction_panel == null or _game_manager == null:
        return
    var am = _game_manager.get_node_or_null("AuctionManager")
    if am == null:
        return
    var state = am.get_current_state()
    if ap_title:       ap_title.text       = "Subasta: %s" % state.get("tile", {}).get("name", "")
    if ap_current_bid: ap_current_bid.text = "Puja actual: %d pts" % current_bid
    if ap_bidder:      ap_bidder.text      = "Turno de: %s" % player.player_name
    if ap_input_bid:
        ap_input_bid.min_value = min_next_bid
        ap_input_bid.value     = min_next_bid
    _refresh_bidders_list()
    auction_panel.visible = true
    if purchase_panel: purchase_panel.visible = false

func _on_place_bid() -> void:
    if _game_manager == null:
        return
    var am = _game_manager.get_node_or_null("AuctionManager")
    if am and ap_input_bid:
        am.on_bid_placed(int(ap_input_bid.value))

func _on_auction_ended(_winner, _tile, _price) -> void:
    if auction_panel:  auction_panel.visible  = false
    if btn_end_turn:   btn_end_turn.disabled  = false

func _on_new_round(round_number: int, current_bid: int, _active_bidders: Array) -> void:
    if ap_current_bid:
        ap_current_bid.text = "Ronda %d — puja: %d pts" % [round_number, current_bid]
    _refresh_bidders_list()

func _on_bidder_eliminated(player: Node, reason: String) -> void:
    _on_log_message("%s eliminado: %s" % [player.player_name, reason])
    _refresh_bidders_list()

func _refresh_bidders_list() -> void:
    if ap_bidders_list == null or _game_manager == null:
        return
    for child in ap_bidders_list.get_children():
        child.queue_free()
    var am = _game_manager.get_node_or_null("AuctionManager")
    if am == null:
        return
    for name_str in am.get_current_state().get("active_bidders", []):
        var lbl = Label.new()
        lbl.text = name_str
        ap_bidders_list.add_child(lbl)

# ── Panel de propiedades ──────────────────────────────────────────
func _toggle_properties_panel() -> void:
    if props_panel == null:
        return
    props_panel.visible = not props_panel.visible
    if props_panel.visible:
        _build_properties_panel()

func _build_properties_panel() -> void:
    if props_vbox == null or _game_manager == null:
        return
    for child in props_vbox.get_children():
        child.queue_free()
    var current = _game_manager._current_player_node()
    if current == null:
        return
    if current.properties.is_empty():
        var lbl = Label.new()
        lbl.text = "Sin propiedades aún."
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
        props_vbox.add_child(lbl)
        return
    for prop in current.properties:
        var card = PanelContainer.new()
        card.custom_minimum_size = Vector2(0, 50)
        var hbox = HBoxContainer.new()

        # Franja de color del grupo
        var stripe = ColorRect.new()
        stripe.custom_minimum_size = Vector2(8, 50)
        stripe.color = _get_group_color(prop.get("group", ""))
        hbox.add_child(stripe)

        # Texto de la propiedad
        var lbl = Label.new()
        lbl.text = "%s\n%d escudos" % [prop.get("name", ""), prop.get("shields", 0)]
        lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
        lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        lbl.add_theme_font_size_override("font_size", 12)
        hbox.add_child(lbl)

        card.add_child(hbox)
        props_vbox.add_child(card)

func _get_group_color(group: String) -> Color:
    match group:
        "brown":       return Color("#6B3A2A")
        "cyan":        return Color("#87CEEB")
        "magenta":     return Color("#C71585")
        "orange":      return Color("#FF8C00")
        "red":         return Color("#CC0000")
        "yellow":      return Color("#FFD700")
        "green":       return Color("#2E8B57")
        "blue":        return Color("#00008B")
        "common_room": return Color("#4B0082")
        "spell":       return Color("#9400D3")
        _:             return Color("#888888")

# ── Victoria ──────────────────────────────────────────────────────
func _on_game_over(winner: Node) -> void:
    if game_over_overlay: game_over_overlay.visible = true
    if lbl_winner: lbl_winner.text = "¡%s (%s) gana!" % [winner.player_name, winner.house]

# ── Solicitudes interactivas ──────────────────────────────────────
func _on_request_tile_choice(_player: Node, _valid_tiles: Array) -> void:
    _on_log_message("Elige una casilla para moverte.")

func _on_request_player_choice(_player: Node, prompt: String, _targets: Array) -> void:
    _on_log_message(prompt)
