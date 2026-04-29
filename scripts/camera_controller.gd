# scripts/camera_controller.gd
# Cámara isométrica que orbita alrededor del tablero.
# Se posiciona automáticamente para encuadrar al jugador activo.
extends Node3D

@onready var camera: Camera3D = $Camera3D

# ── Configuración isométrica ──────────────────────────────────────
const CAM_HEIGHT:      float = 9.0    # Altura de la cámara
const CAM_DISTANCE:    float = 9.0    # Distancia horizontal al centro
const CAM_ANGLE_ELEV:  float = 45.0   # Ángulo de elevación (45° = isométrico)
const CAM_ORBIT_SPEED: float = 0.6    # Velocidad de transición al orbitar

# Ángulos de órbita por zona del tablero (grados)
# El jugador siempre queda en el lado "inferior" de la vista
const ZONE_ANGLES: Dictionary = {
	"bottom": 0.0,    # Casillas 0-10  — cámara mira desde el sur
	"left":   90.0,   # Casillas 11-19 — cámara mira desde el oeste
	"top":    180.0,  # Casillas 20-30 — cámara mira desde el norte
	"right":  270.0,  # Casillas 31-39 — cámara mira desde el este
}

var _current_angle:  float   = 0.0
var _target_angle:   float   = 0.0
var _target_focus:   Vector3 = Vector3.ZERO
var _current_focus:  Vector3 = Vector3.ZERO
var _orbiting:       bool    = false
var _dragging_pan:   bool    = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _pan_sensitivity: float  = 0.012

# ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_camera()
	_update_camera_transform()

func _setup_camera() -> void:
	camera.projection        = Camera3D.PROJECTION_ORTHOGONAL
	camera.size              = 12.0   # Ancho del encuadre en unidades
	camera.near              = 0.1
	camera.far               = 100.0

func _update_camera_transform() -> void:
	var rad = deg_to_rad(_current_angle)
	var elev = deg_to_rad(CAM_ANGLE_ELEV)

	# Posición orbitando alrededor del foco
	var horizontal = CAM_DISTANCE * cos(elev)
	var vertical   = CAM_DISTANCE * sin(elev)

	position = _current_focus + Vector3(
		sin(rad) * horizontal,
		vertical,
		cos(rad) * horizontal
	)
	# Siempre mira al foco
	look_at(_current_focus, Vector3.UP)

# ── Mover cámara al jugador activo ────────────────────────────────
func focus_on_tile(tile_id: int, animate: bool = true) -> void:
	var zone   = _tile_id_to_zone(tile_id)
	var angle  = ZONE_ANGLES.get(zone, 0.0)
	_orbit_to(angle, animate)

func _tile_id_to_zone(tile_id: int) -> String:
	if tile_id <= 10:
		return "bottom"
	elif tile_id <= 20:
		return "left"
	elif tile_id <= 30:
		return "top"
	else:
		return "right"

func _orbit_to(target_angle: float, animate: bool) -> void:
	_target_angle = target_angle
	if not animate:
		_current_angle = target_angle
		_update_camera_transform()
		return
	_orbiting = true
	var tween  = create_tween()
	tween.tween_method(_set_angle, _current_angle, target_angle, CAM_ORBIT_SPEED) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): _orbiting = false)

func _set_angle(angle: float) -> void:
	_current_angle = angle
	_update_camera_transform()

# ── Zoom con rueda del ratón ──────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = clamp(camera.size - 0.8, 5.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = clamp(camera.size + 0.8, 5.0, 20.0)
		elif event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging_pan = event.pressed
			_last_mouse_pos = event.position
	elif event is InputEventMouseMotion and _dragging_pan:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		_pan_camera(delta)

func _pan_camera(mouse_delta: Vector2) -> void:
	# Paneo en el plano XZ relativo al ángulo actual de cámara
	var right = Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(_current_angle))
	var forward = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(_current_angle))
	var factor = camera.size * _pan_sensitivity
	_current_focus -= right * mouse_delta.x * factor
	_current_focus += forward * mouse_delta.y * factor
	_update_camera_transform()

# ── Vista general (muestra todo el tablero) ───────────────────────
func show_full_board(animate: bool = true) -> void:
	_target_focus = Vector3.ZERO
	if animate:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_method(_set_angle, _current_angle, 0.0, 0.8)
		tween.tween_property(camera, "size", 14.0, 0.8)
	else:
		_current_angle = 0.0
		camera.size    = 14.0
		_update_camera_transform()
