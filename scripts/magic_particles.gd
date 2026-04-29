# scripts/magic_particles.gd
# Partículas mágicas creadas por código — no requiere assets externos.
extends Node2D

const GOLD   = Color("#C9A84C")
const SILVER = Color("#E8E8F0")
const RED    = Color("#CC2200")

func burst_gold(pos: Vector2, count: int = 20) -> void:
	_spawn(pos, count, GOLD, 80.0, 1.2)

func burst_move(pos: Vector2) -> void:
	_spawn(pos, 8, SILVER, 40.0, 0.6)

func burst_loss(pos: Vector2) -> void:
	_spawn(pos, 12, RED, 60.0, 0.8)

func burst_victory(pos: Vector2) -> void:
	_spawn(pos, 50, GOLD, 150.0, 2.5)
	await get_tree().create_timer(0.3).timeout
	_spawn(pos, 30, SILVER, 120.0, 2.0)

func _spawn(pos: Vector2, count: int, color: Color, speed: float, duration: float) -> void:
	for i in range(count):
		var p = ColorRect.new()
		var sz = randf_range(2.0, 5.0)
		p.color = color
		p.size  = Vector2(sz, sz)
		p.pivot_offset = Vector2(sz * 0.5, sz * 0.5)
		add_child(p)
		p.global_position = pos

		var angle = randf() * TAU
		var vel   = Vector2(cos(angle), sin(angle)) * speed * randf_range(0.4, 1.0)
		var life  = duration * randf_range(0.5, 1.0)

		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "global_position", pos + vel * life, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, life)
		tw.chain().tween_callback(p.queue_free)

static func spawn_at(tree: SceneTree, pos: Vector2, effect: String) -> void:
	var mp = load("res://scripts/magic_particles.gd").new()
	tree.current_scene.add_child(mp)
	match effect:
		"buy":     mp.burst_gold(pos)
		"move":    mp.burst_move(pos)
		"loss":    mp.burst_loss(pos)
		"victory": mp.burst_victory(pos)
	tree.create_timer(3.0).timeout.connect(mp.queue_free)
