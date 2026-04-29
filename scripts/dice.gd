# scripts/dice.gd
# Maneja el lanzamiento de dados y la interpretación de fórmulas.
# También detecta dobles (ambos dados iguales).
extends Node

# ── Señales ───────────────────────────────────────────────────────
signal rolled(die1: int, die2: int, total: int, is_double: bool)

# ── Último resultado ──────────────────────────────────────────────
var last_die1: int = 0
var last_die2: int = 0
var last_total: int = 0
var last_is_double: bool = false

# ─────────────────────────────────────────────────────────────────
# Lanzamiento estándar de dos dados de 6 caras
func roll() -> Dictionary:
    last_die1     = randi_range(1, 6)
    last_die2     = randi_range(1, 6)
    last_total    = last_die1 + last_die2
    last_is_double = last_die1 == last_die2
    AudioManager.play_sfx("dice_roll")
    rolled.emit(last_die1, last_die2, last_total, last_is_double)
    return {
        "die1":      last_die1,
        "die2":      last_die2,
        "total":     last_total,
        "is_double": last_is_double,
    }

# Interpreta una fórmula de dados estilo "2d6" o "2d6x10"
func roll_formula(formula: String) -> int:
    var parts      = formula.split("x")
    var dice_part  = parts[0]                              # "2d6"
    var multiplier = int(parts[1]) if parts.size() > 1 else 1

    var dice       = dice_part.split("d")
    var num_dice   = int(dice[0])
    var faces      = int(dice[1])

    var total: int = 0
    for i in range(num_dice):
        total += randi_range(1, faces)
    return total * multiplier
