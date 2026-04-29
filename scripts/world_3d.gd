# scripts/world_3d.gd
# Controla el SubViewportContainer que renderiza los elementos 3D
# (tokens y castillo) sobre el tablero 2D de forma transparente.
extends SubViewportContainer

# Referencias internas
@onready var viewport:      SubViewport        = $Viewport3D
@onready var camera:        Camera3D           = $Viewport3D/Camera3D
@onready var tokens_root:   Node3D             = $Viewport3D/TokensRoot
@onready var castle_root:   Node3D             = $Viewport3D/CastleRoot
@onready var dir_light:     DirectionalLight3D = $Viewport3D/DirectionalLight3D
@onready var fill_light:    OmniLight3D        = $Viewport3D/OmniLight3D

# Posición central del tablero en coordenadas 3D
# Ajusta estos valores según el tamaño de tu tablero
const BOARD_CENTER_3D: Vector3 = Vector3(0, 0, 0)
const BOARD_SIZE_3D:   float   = 10.0   # Tamaño del tablero en unidades 3D

# Cámara — ángulo y distancia
const CAM_HEIGHT:    float = 8.0
const CAM_DISTANCE:  float = 6.0
const CAM_ANGLE_DEG: float = 45.0

# Suavizado de movimiento de cámara
var _cam_target:   Vector3 = Vector3.ZERO
var _cam_angle:    float   = 0.0   # Ángulo de órbita en grados

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
    _setup_viewport()
    _setup_lighting()
    _setup_camera()

func _setup_viewport() -> void:
    # El viewport cubre toda la pantalla y es transparente
    anchor_left   = 0; anchor_top    = 0
    anchor_right  = 1; anchor_bottom = 1
    offset_left   = 0; offset_top    = 0
    offset_right  = 0; offset_bottom = 0
    mouse_filter  = Control.MOUSE_FILTER_IGNORE   # No bloquea clics al tablero

    viewport.transparent_bg       = true
    viewport.size                  = get_viewport().get_visible_rect().size
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _setup_lighting() -> void:
    # Luz principal — blanca, diagonal
    dir_light.light_color      = Color(1.0, 0.95, 0.85)
    dir_light.light_energy     = 1.2
    dir_light.shadow_enabled   = true
    dir_light.rotation_degrees = Vector3(-45, -30, 0)

    # Luz de relleno — dorada suave desde abajo
    fill_light.light_color  = Color("#C9A84C")
    fill_light.light_energy = 0.4
    fill_light.omni_range   = 20.0
    fill_light.position     = Vector3(0, -2, 0)

func _setup_camera() -> void:
    camera.fov  = 45.0
    camera.near = 0.1
    camera.far  = 100.0
    _update_camera_position()

func _update_camera_position() -> void:
    var rad    = deg_to_rad(_cam_angle)
    var offset = Vector3(
        sin(rad) * CAM_DISTANCE,
        CAM_HEIGHT,
        cos(rad) * CAM_DISTANCE
    )
    camera.position = _cam_target + offset
    camera.look_at(_cam_target, Vector3.UP)

# ── API pública ────────────────────────────────────────────────────

# Centra la cámara en un token específico
func focus_on_token(token_3d_pos: Vector3, animate: bool = true) -> void:
    if animate:
        _cam_target = token_3d_pos
    else:
        _cam_target = token_3d_pos
        _update_camera_position()

# Orbita la cámara alrededor del tablero
func orbit_to_angle(angle_deg: float, animate: bool = true) -> void:
    if animate:
        var tween = create_tween()
        tween.tween_method(_set_cam_angle, _cam_angle, angle_deg, 0.8) \
            .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    else:
        _cam_angle = angle_deg
        _update_camera_position()

func _set_cam_angle(angle: float) -> void:
    _cam_angle = angle
    _update_camera_position()

# Resetea la cámara al centro del tablero
func reset_camera() -> void:
    focus_on_token(BOARD_CENTER_3D, true)
    orbit_to_angle(0.0, true)

func _process(_delta: float) -> void:
    # Sincronizar tamaño del viewport con la ventana
    var vp_size = get_viewport().get_visible_rect().size
    if viewport.size != Vector2i(vp_size):
        viewport.size = Vector2i(vp_size)
