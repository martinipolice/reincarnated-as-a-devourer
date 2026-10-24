extends Weapon
## Strikes every enemy around you on a cooldown. Its levels are the old
## shop's weapon tiers: Dull Blade -> Standard Greatsword -> Mithril Warblade.
## Evolves into Vexclaw Rend after Devouring 3 Vexclaw essences at Lv 3.
## Each swing, a sword sweeps one full circle at the Blade's reach with a
## circular slash trailing it (red once evolved).

const DAMAGE := [34.0, 50.0, 70.0]
const RADIUS := [75.0, 90.0, 110.0]
const COOLDOWN := [0.9, 0.8, 0.65]  # divided by the player's haste
const EVOLVED_DAMAGE := 90.0
const EVOLVED_RADIUS := 120.0
const EVOLVED_COOLDOWN := 0.6
const KNOCKBACK := 140.0
const SWEEP_TIME := 0.22  # one full circle
const SWORD_TEXTURE := preload("res://assets/ninja/images/sword.png")
const SWOOSH_FRAMES := preload("res://assets/ninja/swoosh/sprite_frames.tres")
## Radius of the slash ring inside its 54 px frame, for scaling to reach.
const SWOOSH_ART_RADIUS := 24.0
const EVOLVED_TINT := Color(1.4, 0.45, 0.4)

var _hitbox: Area2D
var _timer := 0.0
var _pivot: Node2D
var _sword: Sprite2D
var _swoosh: AnimatedSprite2D
var _sweep: Tween


func _ready() -> void:
	_hitbox = make_hitbox(_radius())
	_swoosh = AnimatedSprite2D.new()
	_swoosh.sprite_frames = SWOOSH_FRAMES
	_swoosh.visible = false
	_swoosh.animation_finished.connect(_swoosh.hide)
	add_child(_swoosh)
	_pivot = Node2D.new()
	add_child(_pivot)
	_sword = Sprite2D.new()
	_sword.texture = SWORD_TEXTURE
	_sword.scale = Vector2(2.5, 2.5)
	_sword.rotation = PI / 2.0  # the art points up; aim it outward along +x
	_sword.visible = false
	_pivot.add_child(_sword)
	_on_level_changed()


func _on_level_changed() -> void:
	if _hitbox == null:
		return
	set_hitbox_radius(_hitbox, _radius())
	_swoosh.scale = Vector2.ONE * _radius() / SWOOSH_ART_RADIUS
	_sword.position = Vector2(_radius() * 0.78, 0)
	var tint := EVOLVED_TINT if evolved else Color.WHITE
	_swoosh.modulate = Color(tint, 0.85)
	_sword.modulate = tint


func _radius() -> float:
	return EVOLVED_RADIUS if evolved else per_level(RADIUS)


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var cooldown: float = EVOLVED_COOLDOWN if evolved else per_level(COOLDOWN)
		_timer = cooldown / player.stat("haste")
		_swing()


func _swing() -> void:
	var amount: float = EVOLVED_DAMAGE if evolved else per_level(DAMAGE)
	var targets := enemies_in(_hitbox)
	if not targets.is_empty():
		Game.sfx("blade")
	for enemy in targets:
		var push := global_position.direction_to(enemy.global_position) * KNOCKBACK
		enemy.take_damage(damage(amount), push)
	_play_sweep()


func _play_sweep() -> void:
	_swoosh.rotation = randf() * TAU  # vary where the trail starts
	_swoosh.visible = true
	_swoosh.play("play")
	_swoosh.frame = 0
	if _sweep:
		_sweep.kill()
	_pivot.rotation = _swoosh.rotation
	_sword.visible = true
	_sweep = create_tween()
	_sweep.tween_property(_pivot, "rotation", _pivot.rotation + TAU, SWEEP_TIME)
	_sweep.tween_callback(_sword.hide)
