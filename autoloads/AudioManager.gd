# autoloads/AudioManager.gd
# Singleton global para controlar música y efectos de sonido.
# En Fase 4 se completarán las rutas de audio y los buses.
extends Node

# Nodos de audio — se crearán como hijos en la escena del Autoload
var music_player: AudioStreamPlayer
var sfx_player:   AudioStreamPlayer

# Volumen actual (0.0 a 1.0)
var music_volume: float = 0.8
var sfx_volume: float   = 1.0

# ── Rutas de audio (se rellenarán en Fase 4) ──────────────────────
const TRACKS: Dictionary = {
    "menu":    "res://assets/audio/music_menu.ogg",
    "game":    "res://assets/audio/music_hogwarts_ambient.ogg",
    "editor":  "res://assets/audio/music_editor.ogg",
}

const SFX: Dictionary = {
    "dice_roll":      "res://assets/audio/sfx_dice.ogg",
    "buy_property":   "res://assets/audio/sfx_buy.ogg",
    "pay_rent":       "res://assets/audio/sfx_coins.ogg",
    "go_to_jail":     "res://assets/audio/sfx_azkaban.ogg",
    "card_draw":      "res://assets/audio/sfx_owl.ogg",
    "piece_move":     "res://assets/audio/sfx_move.ogg",
}

# ─────────────────────────────────────────────────────────────────
func play_music(track_key: String) -> void:
    if not TRACKS.has(track_key):
        return
    if not ResourceLoader.exists(TRACKS[track_key]):
        return  # Silencioso
    var stream = load(TRACKS[track_key])
    if stream == null:
        return
    music_player.stream = stream
    music_player.volume_db = linear_to_db(music_volume)
    music_player.play()

func stop_music() -> void:
    music_player.stop()

func play_sfx(sfx_key: String) -> void:
    if not SFX.has(sfx_key):
        return
    if not ResourceLoader.exists(SFX[sfx_key]):
        return  # Silencioso — el archivo aún no existe
    var stream = load(SFX[sfx_key])
    if stream == null:
        return
    sfx_player.stream = stream
    sfx_player.volume_db = linear_to_db(sfx_volume)
    sfx_player.play()

func set_music_volume(value: float) -> void:
    music_volume = clamp(value, 0.0, 1.0)
    music_player.volume_db = linear_to_db(music_volume)

func set_sfx_volume(value: float) -> void:
    sfx_volume = clamp(value, 0.0, 1.0)
