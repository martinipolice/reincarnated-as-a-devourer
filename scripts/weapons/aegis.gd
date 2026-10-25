extends Weapon
## Golden blades that orbit you, hitting and shoving away enemies they touch.
## Each blade's hitbox is a capsule matching its sprite, and a blade hits as
## soon as it touches an enemy; HIT_COOLDOWN stops it hitting the same enemy
## every frame while they overlap.
## Evolves into the Bulwark of Dawn at Lv 3 with Guard at Lv 3: five blades
## on a wider orbit whose ring is a shield: a Plaguewing glob that reaches it
## is cut out of the air by a charged blade. Each cut spends that blade for
## BLADE_RECHARGE seconds (it dims meanwhile), so the ring stops a steady
## trickle of shots, not a downpour.

const BLADE_TEXTURE := preload("res://assets/ninja/images/katana.png")
const SHIELDS := [1, 2, 3]
const DAMAGE := [14.0, 20.0, 28.0]
const ORBIT_RADIUS := 60.0
const SPRITE_SCALE := 2.5
## Capsule around the blade art (6x14 px at 2.5x).
const BLADE_HALF_WIDTH := 8.0
const SPIN := 3.0  # radians per second, times the player's haste
const HIT_COOLDOWN := 0.35  # per enemy
const KNOCKBACK := 260.0
const EVOLVED_SHIELDS := 5
const EVOLVED_DAMAGE := 36.0
const EVOLVED_ORBIT := 72.0
const EVOLVED_TINT := Color(1.4, 1.25, 0.8)
## Globs are cut down once they reach the ring, this far outside the orbit.
const BLOCK_MARGIN := 14.0
const BLADE_RECHARGE := 1.2
const SPENT_TINT := Color(0.5, 0.45, 0.4, 0.6)

var _shields: Array[Area2D] = []
## Enemy instance id -> time it can next be hit.
var _next_hit := {}
var _time := 0.0
## Per blade: the time it can block again.
var _charged_at: Array[float] = []


func _ready() -> void:
	_on_level_changed()


func _on_level_changed() -> void:
	for shield in _shields:
		shield.queue_free()
	_shields.clear()
	var count: int = EVOLVED_SHIELDS if evolved else per_level(SHIELDS)
	var orbit := EVOLVED_ORBIT if evolved else ORBIT_RADIUS
	for i in count:
		var angle := TAU * i / count
		var shield := _make_blade()
		shield.position = Vector2.RIGHT.rotated(angle) * orbit
		shield.rotation = angle + PI / 2.0  # the art points up; aim it outward
		_shields.append(shield)
	_charged_at.resize(_shields.size())
	_charged_at.fill(0.0)


func _make_blade() -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var capsule := CapsuleShape2D.new()
	capsule.radius = BLADE_HALF_WIDTH
	capsule.height = BLADE_TEXTURE.get_height() * SPRITE_SCALE
	var shape := CollisionShape2D.new()
	shape.shape = capsule
	area.add_child(shape)
	var blade := Sprite2D.new()
	blade.texture = BLADE_TEXTURE
	blade.scale = Vector2.ONE * SPRITE_SCALE
	if evolved:
		blade.modulate = EVOLVED_TINT
	area.add_child(blade)
	add_child(area)
	return area


func _physics_process(delta: float) -> void:
	rotation += SPIN * player.stat("haste") * delta
	_time += delta
	for shield in _shields:
		for enemy in enemies_in(shield):
			var id := enemy.get_instance_id()
			if _time < _next_hit.get(id, 0.0):
				continue
			_next_hit[id] = _time + HIT_COOLDOWN
			var push := global_position.direction_to(enemy.global_position) * KNOCKBACK
			enemy.take_damage(damage(EVOLVED_DAMAGE if evolved else per_level(DAMAGE)), push, "aegis_hit")
	if evolved:
		_block_shots()
	if _next_hit.size() > 256:
		_forget_expired()


# The Bulwark's ring cuts enemy shots (Plaguewing globs) out of the air.
func _block_shots() -> void:
	for i in _shields.size():
		var blade := _shields[i].get_child(1) as Sprite2D
		blade.modulate = EVOLVED_TINT if _time >= _charged_at[i] else SPENT_TINT
	var reach := EVOLVED_ORBIT + BLOCK_MARGIN
	for shot in get_tree().get_nodes_in_group("enemy_shots"):
		var at: Vector2 = (shot as Node2D).global_position
		if at.distance_squared_to(global_position) >= reach * reach or shot.is_queued_for_deletion():
			continue
		# The nearest charged blade takes the hit.
		var best := -1
		for i in _shields.size():
			if _time >= _charged_at[i] and (best < 0 or _shields[i].global_position.distance_squared_to(at)
					< _shields[best].global_position.distance_squared_to(at)):
				best = i
		if best < 0:
			return  # every blade is spent; the rest get through
		_charged_at[best] = _time + BLADE_RECHARGE
		Game.fx("spark", at, 1.5, Color(1, 0.95, 0.7))
		Game.sfx("aegis_hit", 0.1)
		shot.queue_free()


func _forget_expired() -> void:
	for id in _next_hit.keys():
		if _next_hit[id] < _time:
			_next_hit.erase(id)
