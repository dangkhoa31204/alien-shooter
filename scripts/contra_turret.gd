extends CharacterBody2D

# contra_turret.gd
# Stationary armored turret that tracks and shoots at the player.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

var hp: int = 4
var detection_range: float = 500.0
var shoot_cooldown: float = 2.0
var _timer: float = 0.0

var barrel: Node2D
var muzzle: Marker2D

func _ready() -> void:
	add_to_group("enemy")
	_setup_visuals()

func _setup_visuals() -> void:
	# Base
	var base = Polygon2D.new()
	base.polygon = PackedVector2Array([Vector2(-20, 0), Vector2(-15, -15), Vector2(15, -15), Vector2(20, 0)])
	base.color = Color(0.2, 0.22, 0.25)
	$Sprite.add_child(base)
	
	# Swivel
	var swivel = ColorRect.new()
	swivel.size = Vector2(16, 8); swivel.position = Vector2(-8, -20); swivel.color = Color(0.15, 0.15, 0.18)
	$Sprite.add_child(swivel)
	
	# Barrel
	barrel = Node2D.new()
	barrel.position = Vector2(0, -16)
	$Sprite.add_child(barrel)
	
	var b_rect = ColorRect.new()
	b_rect.size = Vector2(24, 4); b_rect.position = Vector2(0, -2); b_rect.color = Color(0.1, 0.1, 0.1)
	barrel.add_child(b_rect)
	
	muzzle = Marker2D.new()
	muzzle.position = Vector2(24, 0)
	barrel.add_child(muzzle)

func _physics_process(delta: float) -> void:
	var player = _find_player()
	if player:
		var dist = global_position.distance_to(player.global_position)
		if dist < detection_range:
			_track_player(player, delta)
			_timer -= delta
			if _timer <= 0:
				_shoot(player)
				_timer = shoot_cooldown

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _track_player(p: Node2D, delta: float) -> void:
	var dir = (p.global_position - barrel.global_position).normalized()
	barrel.rotation = lerp_angle(barrel.rotation, dir.angle(), 5.0 * delta)

func _shoot(p: Node2D) -> void:
	var b = BULLET_SCENE.instantiate()
	var main = _get_main_scene()
	if main: main.bullet_container.add_child(b)
	else: get_parent().add_child(b)
	
	b.global_position = muzzle.global_position
	b.direction = (p.global_position - b.global_position).normalized()
	b.is_enemy_bullet = true
	b.add_to_group("enemy_bullet")
	Audio.play("enemy_shoot")

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null

func take_damage(amount: int) -> void:
	hp -= amount
	var tw = create_tween()
	tw.tween_property($Sprite, "modulate", Color.WHITE, 0.05).from(Color.RED)
	if hp <= 0:
		Audio.play("explosion")
		queue_free()
