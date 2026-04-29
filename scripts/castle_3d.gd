# scripts/castle_3d.gd
extends Node3D

const CASTLE_PATH:  String = "res://assets/models/castle/hogwarts.glb"
const CASTLE_SCALE: float  = 1.4
const ROT_SPEED:    float  = 2.5    # grados/segundo
const BOB_AMP:      float  = 0.03
const BOB_SPEED:    float  = 0.6

var _time: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
    print("CastleRoot position: ", global_position)
    _load_castle()
    _init_base_y.call_deferred()
    
func _init_base_y() -> void:
    _base_y = position.y
    print("Castle _base_y fijado en: ", _base_y)

func _load_castle() -> void:
    if ResourceLoader.exists(CASTLE_PATH):
        var inst = load(CASTLE_PATH).instantiate()
        inst.scale = Vector3.ONE * CASTLE_SCALE
        # Preservar materiales originales del GLB — NO aplicar override
        add_child(inst)
    else:
        _build_fallback()

func _build_fallback() -> void:
    _tower(Vector3(0, 0, 0),    0.30, 1.4)
    _tower(Vector3(0.5, 0, 0.5),  0.16, 0.9)
    _tower(Vector3(-0.5, 0, 0.5), 0.16, 0.9)
    _tower(Vector3(0.5, 0, -0.5), 0.16, 0.9)
    _tower(Vector3(-0.5, 0,-0.5), 0.16, 0.9)
    var mi = MeshInstance3D.new()
    var bm = BoxMesh.new()
    bm.size = Vector3(1.4, 0.10, 1.4)
    mi.mesh = bm
    mi.position = Vector3(0, 0.05, 0)
    mi.material_override = _stone_mat()
    add_child(mi)

func _tower(p: Vector3, r: float, h: float) -> void:
    var mi  = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = r; cyl.bottom_radius = r + 0.02; cyl.height = h
    mi.mesh = cyl
    mi.position = p + Vector3(0, h * 0.5, 0)
    mi.material_override = _stone_mat()
    add_child(mi)

func _stone_mat() -> StandardMaterial3D:
    var m = StandardMaterial3D.new()
    m.albedo_color     = Color("#3A3020")
    m.roughness        = 0.85
    m.emission_enabled = true
    m.emission         = Color("#C9A84C") * 0.08
    m.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m

func _process(delta: float) -> void:
    _time += delta
    rotation_degrees.y += ROT_SPEED * delta
    position.y = _base_y + sin(_time * BOB_SPEED) * BOB_AMP

func set_glow_intensity(intensity: float) -> void:
    _set_emission(self, Color("#C9A84C") * intensity)

func _set_emission(node: Node, color: Color) -> void:
    if node is MeshInstance3D:
        var mat = node.get_active_material(0)
        if mat and mat is StandardMaterial3D:
            mat.emission = color
    for child in node.get_children():
        _set_emission(child, color)
