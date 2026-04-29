# scripts/game_manager.gd
extends Node

@onready var board:            Node = $"../BoardLogic"
@onready var dice_mgr:         Node = $Dice
@onready var purchase_manager: Node = $PurchaseManager
@onready var auction_manager:  Node = $AuctionManager

var player_nodes: Array = []
var doubles_this_turn: int  = 0
var _last_roll_was_double: bool = false
var _waiting_for_action: bool   = false
var _turn_ended_pending: bool   = false   # true = terminar turno cuando se libere la acción

signal turn_started(player_index: int)
signal turn_ended(player_index: int)
signal request_tile_choice(player: Node, valid_tiles: Array)
signal request_player_choice(player: Node, prompt: String, targets: Array)
signal game_over(winner: Node)
signal log_message(text: String)

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    dice_mgr.rolled.connect(_on_dice_rolled)
    purchase_manager.purchase_completed.connect(_on_purchase_completed)
    purchase_manager.purchase_declined.connect(_on_purchase_declined)
    auction_manager.auction_won.connect(_on_auction_won)
    auction_manager.auction_cancelled.connect(_on_auction_cancelled)
    auction_manager.bid_requested.connect(_on_bid_requested)

func start_game() -> void:
    print("=== start_game ejecutado ===")
    GameState.set_phase("playing")
    _start_turn(0)

func _start_turn(player_index: int) -> void:
    doubles_this_turn    = 0
    _last_roll_was_double = false
    _waiting_for_action  = false
    _turn_ended_pending  = false
    GameState.current_player_index = player_index
    var player = player_nodes[player_index]
    turn_started.emit(player_index)
    log_message.emit("Turno de %s (%s)" % [player.player_name, player.house])

# ── Tirar dados ───────────────────────────────────────────────────
func player_roll_dice() -> void:
    if _waiting_for_action:
        return
    var current = _current_player_node()
    if current == null:
        return
    if current.in_jail:
        _handle_jail_roll(current)
        return
    dice_mgr.roll()

func _on_dice_rolled(die1: int, die2: int, total: int, is_double: bool) -> void:
    var current = _current_player_node()
    if current == null:
        return

    _last_roll_was_double = is_double

    log_message.emit("%s sacó %d + %d = %d%s" % [
        current.player_name, die1, die2, total,
        " (¡DOBLE!)" if is_double else ""
    ])

    if is_double:
        doubles_this_turn += 1
        if doubles_this_turn >= 3:
            log_message.emit("¡Tres dobles seguidos! %s va directo a Azkaban." % current.player_name)
            current.go_to_jail()
            _do_end_turn()
            return

    current.move(total)
    _handle_landing(current)

    # Si hay acción pendiente (compra, subasta, carta), marcamos
    # que al resolverse debemos terminar turno (o volver a tirar si fue doble)
    if _waiting_for_action:
        _turn_ended_pending = true
    else:
        _resolve_after_landing()

func _resolve_after_landing() -> void:
    # Llamado cuando el aterrizaje se resuelve (inmediatamente o tras acción)
    if _last_roll_was_double and not _current_player_node().in_jail:
        log_message.emit("¡Doble! %s tira de nuevo." % _current_player_node().player_name)
        turn_started.emit(GameState.current_player_index)
    else:
        _do_end_turn()

# ── Aterrizaje ────────────────────────────────────────────────────
func _handle_landing(player: Node) -> void:
    var tile_data = _get_tile_data(player.tile_position)
    if tile_data.is_empty():
        return
    log_message.emit("%s cayó en: %s" % [player.player_name, tile_data.get("name", "?")])
    match tile_data.get("type", ""):
        "go":
            pass
        "property", "spell":
            _handle_property_landing(player, tile_data)
        "tax":
            _handle_tax(player, tile_data)
        "owl_letters":
            _draw_card(player)
        "go_to_jail", "punishment":
            player.go_to_jail()
            log_message.emit("%s fue enviado a Azkaban." % player.player_name)
        "jail", "free_parking":
            pass

func _handle_property_landing(player: Node, tile_data: Dictionary) -> void:
    var prop_owner_node = _find_owner(tile_data.id)
    if prop_owner_node == null:
        _waiting_for_action = true
        purchase_manager.offer_purchase(player, tile_data)
    elif prop_owner_node == player:
        log_message.emit("Esta propiedad ya es tuya.")
    else:
        var rent = _calculate_rent(tile_data, player.to_dict(), prop_owner_node.to_dict())
        if rent == 0:
            log_message.emit("%s no paga renta (exención de casa)." % player.player_name)
            return
        player.lose_points(rent)
        prop_owner_node.gain_points(rent)
        AudioManager.play_sfx("pay_rent")
        log_message.emit("%s pagó %d pts de renta a %s." % [
            player.player_name, rent, prop_owner_node.player_name])
        _check_bankruptcy(player)

func _handle_tax(player: Node, tile_data: Dictionary) -> void:
    var mortgage = tile_data.get("mortgage", 0)
    var amount: int = 0
    if typeof(mortgage) == TYPE_FLOAT or typeof(mortgage) == TYPE_INT:
        amount = int(mortgage)
    elif typeof(mortgage) == TYPE_STRING:
        amount = dice_mgr.roll_formula(mortgage)
    player.lose_points(amount)
    log_message.emit("%s pagó %d pts." % [player.player_name, amount])
    _check_bankruptcy(player)

func _draw_card(player: Node) -> void:
    var deck: Array = GameState.board_data \
        .get("card_decks", {}).get("owl_post", {}).get("cards", [])
    if deck.is_empty():
        return
    deck.shuffle()
    var card = deck[0]
    AudioManager.play_sfx("card_draw")
    apply_card_effect(card, player)

# ── Compra ────────────────────────────────────────────────────────
func _on_purchase_completed(player: Node, tile_data: Dictionary) -> void:
    _waiting_for_action = false
    log_message.emit("%s compró %s por %d pts." % [
        player.player_name, tile_data.get("name", ""), int(tile_data.get("price", 0))])
    if _turn_ended_pending:
        _turn_ended_pending = false
        _resolve_after_landing()

func _on_purchase_declined(_tile_data: Dictionary) -> void:
    # La subasta se inicia desde purchase_manager
    pass

# ── Subasta ───────────────────────────────────────────────────────
func _on_bid_requested(_player: Node, _current_bid: int, _min_next_bid: int) -> void:
    _waiting_for_action = true

func _on_auction_won(winner: Node, tile_data: Dictionary, final_price: int) -> void:
    _waiting_for_action = false
    log_message.emit("¡%s ganó la subasta de %s por %d pts!" % [
        winner.player_name, tile_data.get("name", ""), final_price])
    if _turn_ended_pending:
        _turn_ended_pending = false
        _resolve_after_landing()

func _on_auction_cancelled(tile_data: Dictionary) -> void:
    _waiting_for_action = false
    log_message.emit("%s queda en el banco." % tile_data.get("name", ""))
    if _turn_ended_pending:
        _turn_ended_pending = false
        _resolve_after_landing()

# ── Cartas ────────────────────────────────────────────────────────
func apply_card_effect(card: Dictionary, player: Node) -> void:
    var effect = card.get("effect", {})
    if effect.is_empty():
        return

    if card.get("keep", false):
        player.add_card(card)
        log_message.emit("%s guardó una carta para usar después." % player.player_name)
        return

    match effect.get("action", ""):
        "gain_points":
            _apply_points_with_house_mod(player, effect, true)
        "lose_points":
            _apply_points_with_house_mod(player, effect, false)
        "go_to_jail":
            player.go_to_jail()
            log_message.emit("%s va a Azkaban por carta." % player.player_name)
        "move_to_tile":
            var bonus = int(effect.get("pass_go_bonus", GameState.go_salary))
            player.move_to(int(effect.get("tile_id", 0)), bonus > 0)
            _handle_landing(player)
        "move_to_nearest":
            var target = board.find_nearest_tile(player.tile_position, effect.get("tile_type", ""))
            if not target.is_empty():
                player.move_to(int(target.get("id", 0)), effect.get("pass_go_bonus", 0) > 0)
                _handle_landing(player)
        "move_relative":
            player.move(int(effect.get("steps", 0)))
            _handle_landing(player)
        "move_to_tile_choice":
            log_message.emit("%s puede moverse a cualquier casilla (función avanzada)." % player.player_name)
        "get_out_of_jail_free":
            pass
        "pay_points_to_all":
            _pay_to_all(player, effect)
        "collect_points_from_all":
            _collect_from_all(player, effect)
        "cancel_owl_card":
            log_message.emit("%s cancela una carta de lechuza." % player.player_name)
        _:
            log_message.emit("Efecto de carta procesado.")

func _apply_points_with_house_mod(player: Node, effect: Dictionary, is_gain: bool) -> void:
    var base: int = int(effect.get("amount", 0))
    var mods      = effect.get("house_modifiers", {})
    var amount    = base
    if mods.get("target", "") == "self" and mods.has(player.house):
        amount = int(mods[player.house].get("amount", base))
    if is_gain:
        player.gain_points(amount)
        log_message.emit("%s ganó %d pts." % [player.player_name, amount])
    else:
        player.lose_points(amount)
        log_message.emit("%s perdió %d pts." % [player.player_name, amount])
    _check_bankruptcy(player)

func _pay_to_all(player: Node, effect: Dictionary) -> void:
    var base: int = int(effect.get("amount", 0))
    var mods      = effect.get("house_modifiers", {})
    for other in player_nodes:
        if other == player:
            continue
        var amount = int(mods[other.house].get("amount", base)) if mods.has(other.house) else base
        player.lose_points(amount)
        other.gain_points(amount)
    _check_bankruptcy(player)

func _collect_from_all(player: Node, effect: Dictionary) -> void:
    var base: int = int(effect.get("amount", 0))
    var mods      = effect.get("house_modifiers", {})
    for other in player_nodes:
        if other == player:
            continue
        var amount = int(mods[other.house].get("amount", base)) if mods.has(other.house) else base
        other.lose_points(amount)
        player.gain_points(amount)
        _check_bankruptcy(other)

func _apply_landing_override(player: Node, tile_data: Dictionary, effect: Dictionary) -> void:
    var override = effect.get("landing_override", {})
    if override.is_empty():
        _handle_landing(player)
        return
    var prop_owner_node = _find_owner(int(tile_data.get("id", -1)))
    if prop_owner_node == null:
        if override.get("if_unowned", "") == "can_buy":
            _waiting_for_action = true
            purchase_manager.offer_purchase(player, tile_data)
    elif prop_owner_node != player:
        match override.get("if_owned", ""):
            "pay_double_rent":
                var rent = _calculate_rent(tile_data, player.to_dict(), prop_owner_node.to_dict())
                player.lose_points(rent * 2)
                prop_owner_node.gain_points(rent * 2)
                log_message.emit("%s pagó renta doble: %d pts." % [player.player_name, rent * 2])
                _check_bankruptcy(player)
            "pay_normal_rent":
                _handle_property_landing(player, tile_data)

# ── Azkaban ───────────────────────────────────────────────────────
func _handle_jail_roll(player: Node) -> void:
    player.jail_turns += 1
    var result = dice_mgr.roll()
    if result.is_double:
        player.release_from_jail()
        player.move(result.total)
        _handle_landing(player)
    elif player.jail_turns >= 3:
        player.lose_points(5)
        player.release_from_jail()
        player.move(result.total)
        _handle_landing(player)
    if not _waiting_for_action:
        _do_end_turn()

# ── Quiebra ───────────────────────────────────────────────────────
func _check_bankruptcy(player: Node) -> void:
    if not player.is_bankrupt():
        return
    log_message.emit("%s está en quiebra. Sus propiedades vuelven al banco." % player.player_name)
    player.properties.clear()
    player_nodes.erase(player)
    if player_nodes.size() == 1:
        game_over.emit(player_nodes[0])
        return
    if GameState.current_player_index >= player_nodes.size():
        GameState.current_player_index = 0
    _do_end_turn()

# ── Turno ─────────────────────────────────────────────────────────
func _do_end_turn() -> void:
    if player_nodes.is_empty():
        return
    var current_index = GameState.current_player_index
    turn_ended.emit(current_index)
    _start_turn((current_index + 1) % player_nodes.size())

func end_turn_requested() -> void:
    if _waiting_for_action:
        return
    _do_end_turn()

# ── Helpers ───────────────────────────────────────────────────────
func _current_player_node() -> Node:
    var idx = GameState.current_player_index
    return player_nodes[idx] if idx < player_nodes.size() else null

func _get_tile_data(tile_id: int) -> Dictionary:
    for t in GameState.board_data.get("tiles", []):
        if int(t.get("id", -1)) == tile_id:
            return t
    return {}

func _find_owner(tile_id: int) -> Node:
    for p in player_nodes:
        if p.owns_tile(tile_id):
            return p
    return null

func _other_players(player: Node) -> Array:
    return player_nodes.filter(func(p): return p != player)

func _players_of_house(house: String) -> Array:
    return player_nodes.filter(func(p): return p.house == house)

func get_player_node_by_name(pname: String) -> Node:
    for p in player_nodes:
        if p.player_name == pname:
            return p
    return null

func register_players(player_data_array: Array, player_node_array: Array) -> void:
    GameState.players = player_data_array
    player_nodes      = player_node_array

# ── Cálculo de renta ──────────────────────────────────────────────
func _calculate_rent(tile_data: Dictionary, landing_player: Dictionary, prop_owner: Dictionary) -> int:
    if tile_data.has("landing_rules"):
        var rules = tile_data.landing_rules
        if rules.has("if_visitor_is_owner_house"):
            var ex = rules.if_visitor_is_owner_house
            if landing_player.get("house", "") == ex.house \
            and ex.get("exempt_from_rent", false):
                return 0
    if tile_data.has("rent_rule"):
        return _calculate_spell_rent(tile_data.rent_rule, prop_owner)
    if tile_data.has("rent"):
        var shields = 0
        for prop in prop_owner.get("properties", []):
            if int(prop.get("id", -1)) == int(tile_data.get("id", -2)):
                shields = int(prop.get("shields", 0))
        var rent_table: Array = tile_data.rent
        shields = clamp(shields, 0, rent_table.size() - 1)
        return int(rent_table[shields])
    return 0

func _calculate_spell_rent(rule: Dictionary, prop_owner: Dictionary) -> int:
    var spells_owned = 0
    for prop in prop_owner.get("properties", []):
        if prop.get("type", "") == "spell":
            spells_owned += 1
    var variant = rule.condition_variants.both \
        if spells_owned >= 2 \
        else rule.condition_variants.one
    var dice_parts = variant.formula.split("d")
    var num_dice   = int(dice_parts[0])
    var faces      = int(dice_parts[1])
    var results: Array = []
    for i in range(num_dice):
        results.append(randi_range(1, faces))
    var total = 0
    match variant.rule:
        "take_highest":
            total = results.max()
        "take_both":
            total = results.reduce(func(a, b): return a + b)
    return total * int(variant.get("multiplier", 1))
