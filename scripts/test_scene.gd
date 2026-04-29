# test_scene.gd
# Escena de prueba para verificar que la lógica base funciona.
# Borra este archivo cuando todo esté confirmado.
extends Node

func _ready() -> void:
    print("=== INICIO DE PRUEBAS ===")
    _test_json()
    _test_gamestate()
    _test_players()
    _test_dice()
    print("=== FIN DE PRUEBAS ===")

func _test_json() -> void:
    print("\n--- Test 1: Carga del JSON ---")
    var board = SaveSystem.load_board("res://data/default_board.json")
    if board.is_empty():
        print("ERROR: No se pudo cargar el JSON")
        return
    print("OK: JSON cargado. Nombre: ", board.get("name", "?"))
    print("OK: Casillas encontradas: ", board.get("tiles", []).size())
    print("OK: Cartas de lechuza: ",
        board.get("card_decks", {}).get("owl_post", {}).get("cards", []).size())

func _test_gamestate() -> void:
    print("\n--- Test 2: GameState ---")
    GameState.board_data = SaveSystem.load_board("res://data/default_board.json")
    print("OK: board_data asignado. Moneda: ", GameState.board_data.get("currency", "?"))
    GameState.set_phase("playing")
    print("OK: fase cambiada a: ", GameState.game_phase)

func _test_players() -> void:
    print("\n--- Test 3: Jugadores ---")
    GameState.players = [
        {"name": "Harry",   "house": "Gryffindor", "token": "varita",
         "points": 0, "position": 0, "in_jail": false,
         "jail_turns": 0, "properties": [], "hand_cards": []},
        {"name": "Hermione","house": "Gryffindor", "token": "hedwig",
         "points": 0, "position": 0, "in_jail": false,
         "jail_turns": 0, "properties": [], "hand_cards": []},
    ]
    print("OK: ", GameState.players.size(), " jugadores creados")
    print("OK: Jugador 1: ", GameState.get_current_player().get("name", "?"))
    GameState.next_turn()
    print("OK: Jugador 2: ", GameState.get_current_player().get("name", "?"))

func _test_dice() -> void:
    print("\n--- Test 4: Dados ---")
    # Probamos la fórmula de dados sin nodo Dice
    var resultados = []
    for i in range(5):
        resultados.append(randi_range(1, 6) + randi_range(1, 6))
    print("OK: 5 lanzamientos de 2d6: ", resultados)
    # Probamos la fórmula con string
    var formula_result = _roll_formula("2d6x10")
    print("OK: fórmula '2d6x10' = ", formula_result, " (debe estar entre 20 y 120)")

func _roll_formula(formula: String) -> int:
    var parts = formula.split("x")
    var dice  = parts[0].split("d")
    var total = 0
    for i in range(int(dice[0])):
        total += randi_range(1, int(dice[1]))
    return total * (int(parts[1]) if parts.size() > 1 else 1)
