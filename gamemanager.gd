# scripts/game_manager.gd
# El árbitro del juego. Coordina turnos, movimientos, pagos y cartas.
# Versión actualizada con flujo completo de compra y subasta.
extends Node

# ── Referencias a nodos ───────────────────────────────────────────
@onready var board:            Node = $"../BoardLogic"
@onready var dice_mgr:         Node = $Dice
@onready var purchase_manager: Node = $PurchaseManager
@onready var auction_manager:  Node = $AuctionManager

var player_nodes: Array = []
var doubles_this_turn: int = 0
var _waiting_for_action: bool = false

# ── Señales ───────────────────────────────────────────────────────
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
	GameState.set_phase("playing")
	_start_turn(0)

func _start_turn(player_index: int) -> void:
	doubles_this_turn   = 0
	_waiting_for_action = false
	GameState.current_player_index = player_index
	var player = player_nodes[player_index]
	turn_started.emit(player_index)
	log_message.emit("Turno de %s (%s)" % [player.player_name, player.house])

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
	log_message.emit("%s sacó %d + %d = %d%s" % [
		current.player_name, die1, die2, total,
		" (¡DOBLE!)" if is_double else ""
	])
	if is_double:
		doubles_this_turn += 1
		if doubles_this_turn >= 3:
			log_message.emit("¡Tres dobles! %s va a Azkaban." % current.player_name)
			current.go_to_jail()
			_end_turn()
			return
	current.move(total)
	_handle_landing(current)
	if is_double and not current.in_jail and not _waiting_for_action:
		log_message.emit("¡Doble! %s tira de nuevo." % current.player_name)
		turn_started.emit(GameState.current_player_index)

# ─────────────────────────────────────────────────────────────────
func _handle_landing(player: Node) -> void:
	var tile_data = _get_tile_data(player.position)
	if tile_data.is_empty():
		return
	log_message.emit("%s cayó en: %s" % [player.player_name, tile_data.get("name", "?")])
	match tile_data.get("type", ""):
		"go":         pass
		"property", "spell": _handle_property_landing(player, tile_data)
		"tax":        _handle_tax(player, tile_data)
		"owl_letters": _draw_card(player)
		"go_to_jail", "punishment":
			player.go_to_jail()
			log_message.emit("%s fue enviado a Azkaban." % player.player_name)
		"jail", "free_parking": pass

func _handle_property_landing(player: Node, tile_data: Dictionary) -> void:
	var owner_node = _find_owner(tile_data.id)
	if owner_node == null:
		_waiting_for_action = true
		purchase_manager.offer_purchase(player, tile_data)
	elif owner_node == player:
		log_message.emit("Esta propiedad ya es tuya.")
	else:
		var rent = _calculate_rent(tile_data, player.to_dict(), owner_node.to_dict())
		if rent == 0:
			log_message.emit("%s no paga renta en la sala de su casa." % player.player_name)
			return
		player.lose_points(rent)
		owner_node.gain_points(rent)
		AudioManager.play_sfx("pay_rent")
		log_message.emit("%s pagó %d puntos de renta a %s." % [
			player.player_name, rent, owner_node.player_name])
		_check_bankruptcy(player)

func _handle_tax(player: Node, tile_data: Dictionary) -> void:
	var mortgage = tile_data.get("mortgage", 0)
	var amount: int = 0
	if typeof(mortgage) == TYPE_INT:
		amount = mortgage
	elif typeof(mortgage) == TYPE_STRING:
		amount = dice_mgr.roll_formula(mortgage)
	player.lose_points(amount)
	log_message.emit("%s pagó %d puntos." % [player.player_name, amount])
	_check_bankruptcy(player)

func _draw_card(player: Node) -> void:
	var deck: Array = GameState.board_data \
		.get("card_decks", {}).get("owl_post", {}).get("cards", [])
	if deck.is_empty():
		return
	deck.shuffle()
	var card = deck[0]
	_waiting_for_action = true
	AudioManager.play_sfx("card_draw")
	log_message.emit("%s robó: %s" % [player.player_name, card.get("text", "")])
	apply_card_effect(card, player)
	if not card.get("keep", false):
		_waiting_for_action = false

# ── Compra y subasta ──────────────────────────────────────────────
func _on_purchase_completed(player: Node, tile_data: Dictionary) -> void:
	_waiting_for_action = false
	log_message.emit("%s compró %s por %d puntos." % [
		player.player_name, tile_data.get("name", ""), tile_data.get("price", 0)])

func _on_purchase_declined(tile_data: Dictionary) -> void:
	log_message.emit("Subasta iniciada para %s." % tile_data.get("name", ""))

func _on_bid_requested(player: Node, current_bid: int, min_next_bid: int) -> void:
	_waiting_for_action = true
	log_message.emit("Turno de %s — puja actual: %d | mínima: %d." % [
		player.player_name, current_bid, min_next_bid])

func _on_auction_won(winner: Node, tile_data: Dictionary, final_price: int) -> void:
	_waiting_for_action = false
	log_message.emit("¡%s ganó la subasta de %s por %d puntos!" % [
		winner.player_name, tile_data.get("name", ""), final_price])

func _on_auction_cancelled(tile_data: Dictionary) -> void:
	_waiting_for_action = false
	log_message.emit("%s queda en el banco sin dueño." % tile_data.get("name", ""))

# ── Efectos de cartas ─────────────────────────────────────────────
func apply_card_effect(card: Dictionary, player: Node) -> void:
	var effect = card.get("effect", {})
	if effect.is_empty():
		return
	if card.get("keep", false):
		player.add_card(card)
	match effect.get("action", ""):
		"gain_points":       _apply_points_with_house_mod(player, effect, true)
		"lose_points":       _apply_points_with_house_mod(player, effect, false)
		"go_to_jail":        _try_substitute_or_apply(player, effect, func(): player.go_to_jail())
		"move_to_tile":
			_try_substitute_or_apply(player, effect, func():
				var bonus = _house_mod_value(player, effect, "pass_go_bonus",
					effect.get("pass_go_bonus", GameState.go_salary))
				player.move_to(effect.tile_id, bonus > 0)
				_handle_landing(player))
		"move_to_nearest":
			var target = board.find_nearest_tile(player.position, effect.tile_type)
			if not target.is_empty():
				player.move_to(target.id, effect.get("pass_go_bonus", 0) > 0)
				_apply_landing_override(player, target, effect)
		"move_to_tile_choice":
			var valid = board.tiles.filter(
				func(t): return t.get_type() not in effect.get("exclude_types", []))
			request_tile_choice.emit(player, valid)
		"move_relative":
			_try_substitute_or_apply(player, effect, func():
				player.move(effect.get("steps", 0))
				_handle_landing(player))
		"get_out_of_jail_free": pass
		"steal_property":
			request_player_choice.emit(player,
				"Elige un jugador para robarle una propiedad", _other_players(player))
		"swap_property":
			request_player_choice.emit(player,
				"Elige un jugador para intercambiar una propiedad", _other_players(player))
		"add_shield":
			request_player_choice.emit(player, "Elige una propiedad en grupo completo", [])
		"collect_rent_from_player":
			request_player_choice.emit(player,
				"Elige un jugador que te pague la renta", _other_players(player))
		"pay_points_to_all":     _pay_to_all(player, effect)
		"collect_points_from_all": _collect_from_all(player, effect)
		"cancel_owl_card":      pass

func _apply_points_with_house_mod(player: Node, effect: Dictionary, is_gain: bool) -> void:
	var base: int = effect.get("amount", 0)
	var mods      = effect.get("house_modifiers", {})
	var amount    = base
	if mods.get("target", "") == "self" and mods.has(player.house):
		amount = mods[player.house].get("amount", base)
	if is_gain: player.gain_points(amount)
	else:        player.lose_points(amount)
	_check_bankruptcy(player)

func _pay_to_all(player: Node, effect: Dictionary) -> void:
	var base: int = effect.get("amount", 0)
	var mods      = effect.get("house_modifiers", {})
	for other in player_nodes:
		if other == player: continue
		var amount = mods[other.house].get("amount", base) if mods.has(other.house) else base
		player.lose_points(amount)
		other.gain_points(amount)
	_check_bankruptcy(player)

func _collect_from_all(player: Node, effect: Dictionary) -> void:
	var base: int = effect.get("amount", 0)
	var mods      = effect.get("house_modifiers", {})
	for other in player_nodes:
		if other == player: continue
		var amount = mods[other.house].get("amount", base) if mods.has(other.house) else base
		other.lose_points(amount)
		player.gain_points(amount)
		_check_bankruptcy(other)

func _apply_landing_override(player: Node, tile_data: Dictionary, effect: Dictionary) -> void:
	var override = effect.get("landing_override", {})
	if override.is_empty():
		_handle_landing(player)
		return
	var owner_node = _find_owner(tile_data.id)
	if owner_node == null:
		if override.get("if_unowned", "") == "can_buy":
			_waiting_for_action = true
			purchase_manager.offer_purchase(player, tile_data)
	elif owner_node != player:
		match override.get("if_owned", ""):
			"pay_double_rent":
				var tile_node = board.get_tile(tile_data.id)
				if tile_node:
					var rent = tile_node.calculate_rent(player.to_dict(), owner_node.to_dict())
					player.lose_points(rent * 2)
					owner_node.gain_points(rent * 2)
					log_message.emit("%s pagó renta doble: %d puntos." % [player.player_name, rent * 2])
					_check_bankruptcy(player)
			"pay_normal_rent": _handle_property_landing(player, tile_data)

func _try_substitute_or_apply(player: Node, effect: Dictionary, action: Callable) -> void:
	var mods = effect.get("house_modifiers", {})
	if mods.get("target", "") == "choose_player" \
	and mods.get("condition", "") == "target_is_house":
		request_player_choice.emit(player,
			"¿Obligas a un jugador de %s?" % mods.get("house", ""),
			_players_of_house(mods.get("house", "")))
	action.call()

func _house_mod_value(player: Node, effect: Dictionary, key: String, default_val: Variant) -> Variant:
	var mods = effect.get("house_modifiers", {})
	if mods.get("target", "") == "self" and mods.has(player.house):
		return mods[player.house].get(key, default_val)
	return default_val

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

# ── Quiebra ───────────────────────────────────────────────────────
func _check_bankruptcy(player: Node) -> void:
	if not player.is_bankrupt():
		return
	log_message.emit("%s está en quiebra." % player.player_name)
	player.properties.clear()
	player_nodes.erase(player)
	if player_nodes.size() == 1:
		game_over.emit(player_nodes[0])
		return
	if GameState.current_player_index >= player_nodes.size():
		GameState.current_player_index = 0
	_end_turn()

# ── Turno ─────────────────────────────────────────────────────────
func _end_turn() -> void:
	if _waiting_for_action:
		return
	var current_index = GameState.current_player_index
	turn_ended.emit(current_index)
	_start_turn((current_index + 1) % player_nodes.size())

func end_turn_requested() -> void:
	if _waiting_for_action:
		return
	_end_turn()

# ── Helpers ───────────────────────────────────────────────────────
func _current_player_node() -> Node:
	var idx = GameState.current_player_index
	return player_nodes[idx] if idx < player_nodes.size() else null

func _get_tile_data(tile_id: int) -> Dictionary:
	for t in GameState.board_data.get("tiles", []):
		if t.get("id", -1) == tile_id:
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
	
func _calculate_rent(tile_data: Dictionary, landing_player: Dictionary, owner: Dictionary) -> int:
	# Exención por casa (salas comunes)
			if tile_data.has("landing_rules"):
				var rules = tile_data.landing_rules
			if rules.has("if_visitor_is_owner_house"):
				var ex = rules.if_visitor_is_owner_house
			if landing_player.get("house", "") == ex.house \
				and ex.get("exempt_from_rent", false):
		return 0

	# Hechizos: renta por dados
	if tile_data.has("rent_rule"):
	return _calculate_spell_rent(tile_data.rent_rule, owner)
# Propiedad normal: renta por escudos
if tile_data.has("rent"):
		var shields = 0
	for prop in owner.get("properties", []):
		if prop.get("id", -1) == tile_data.get("id", -2):
			shields = prop.get("shields", 0)
		var rent_table: Array = tile_data.rent
		shields = clamp(shields, 0, rent_table.size() - 1)
		return rent_table[shields]

	return 0

func _calculate_spell_rent(rule: Dictionary, owner: Dictionary) -> int:
	var spells_owned = 0
	for prop in owner.get("properties", []):
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
		"take_highest": total = results.max()
		"take_both":    total = results.reduce(func(a, b): return a + b)

	return total * variant.get("multiplier", 1)
