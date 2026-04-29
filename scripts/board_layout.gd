# scripts/board_layout.gd
# Calcula las posiciones visuales de las 40 casillas alrededor
# del perímetro del tablero, visto desde arriba como un Monopoly físico.
#
# Distribución (sentido horario desde esquina inferior derecha):
#   Casilla  0    = esquina inferior derecha  (Salida)
#   Casillas 1-9  = fila inferior, de derecha a izquierda
#   Casilla  10   = esquina inferior izquierda (Azkaban)
#   Casillas 11-19= columna izquierda, de abajo a arriba
#   Casilla  20   = esquina superior izquierda (Parada Libre)
#   Casillas 21-29= fila superior, de izquierda a derecha
#   Casilla  30   = esquina superior derecha   (Ve a la Cárcel)
#   Casillas 31-39= columna derecha, de arriba a abajo
extends Node

# ── Medidas ───────────────────────────────────────────────────────
const BOARD_SIZE:   float = 810.0
const CORNER_SIZE:  float = 100.0
const NORMAL_W:     float = 67.7
const NORMAL_H:     float = 100.0
const BOARD_ORIGIN: Vector2 = Vector2(60.0, 90.0)

var tile_transforms: Array = []

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    calculate_layout()

func calculate_layout() -> void:
    tile_transforms.clear()
    tile_transforms.resize(40)

    var o  = BOARD_ORIGIN
    var bs = BOARD_SIZE
    var cs = CORNER_SIZE
    var nw = NORMAL_W
    var nh = NORMAL_H

    # ── Fila inferior (casillas 0-10) ─────────────────────────────
    # Casilla 0: esquina inferior derecha
    tile_transforms[0] = {
        "position": o + Vector2(bs - cs, bs - cs),
        "rotation": 0.0,
        "size":     Vector2(cs, cs)
    }
    # Casillas 1-9: avanzan hacia la izquierda desde la esquina derecha
    for i in range(1, 10):
        tile_transforms[i] = {
            "position": o + Vector2(bs - cs - i * nw, bs - nh),
            "rotation": 0.0,
            "size":     Vector2(nw, nh)
        }
    # Casilla 10: esquina inferior izquierda (Azkaban)
    tile_transforms[10] = {
        "position": o + Vector2(0.0, bs - cs),
        "rotation": 0.0,
        "size":     Vector2(cs, cs)
    }

    # ── Columna izquierda (casillas 11-19) ────────────────────────
    # Suben desde la esquina inferior izquierda hacia arriba
    for i in range(1, 10):
        tile_transforms[10 + i] = {
            "position": o + Vector2(cs, bs - cs - i * nw),
            "rotation": 90.0,
            "size":     Vector2(nw, nh)
        }
    # Casilla 20: esquina superior izquierda (Parada Libre)
    tile_transforms[20] = {
        "position": o + Vector2(0.0, 0.0),
        "rotation": 0.0,
        "size":     Vector2(cs, cs)
    }

    # ── Fila superior (casillas 21-29) ────────────────────────────
    # Avanzan hacia la derecha desde la esquina superior izquierda
    for i in range(1, 10):
        tile_transforms[20 + i] = {
            "position": o + Vector2(cs + i * nw, cs),
            "rotation": 180.0,
            "size":     Vector2(nw, nh)
        }
    # Casilla 30: esquina superior derecha (Ve a la Cárcel)
    tile_transforms[30] = {
        "position": o + Vector2(bs - cs, 0.0),
        "rotation": 0.0,
        "size":     Vector2(cs, cs)
    }

    # ── Columna derecha (casillas 31-39) ──────────────────────────
    # Bajan desde la esquina superior derecha hacia abajo
    for i in range(1, 10):
        tile_transforms[30 + i] = {
            "position": o + Vector2(bs - nh, cs + i * nw),
            "rotation": 270.0,
            "size":     Vector2(nw, nh)
        }

# ── API pública ────────────────────────────────────────────────────
func get_tile_center(tile_id: int) -> Vector2:
    if tile_id < 0 or tile_id >= tile_transforms.size():
        return Vector2.ZERO
    var t = tile_transforms[tile_id]
    return t.position + t.size * 0.5

func get_tile_transform(tile_id: int) -> Dictionary:
    if tile_id < 0 or tile_id >= tile_transforms.size():
        return {}
    return tile_transforms[tile_id]
