extends CharacterBody2D

# contra_enemy.gd
# Advanced Side-scrolling US Soldier AI with procedural movement and animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 120.0
const GRAVITY: float = 1400.0
const DETECTION_RANGE: float = 320.0

const INFANTRY_HITS_TO_KILL: int = 2
const OFFICER_HITS_TO_KILL: int = 6

const DEFAULT_SCALE = Vector2(0.30, 0.30) # Increased to match player size
const ANIM_SCALES = {
	"enemy_1_gun": Vector2(0.32, 0.32),   
	"enemy_2_run_and_gun": Vector2(0.35, 0.35)
}

var hp: int = 14
var patrol_direction: int = -1 # Start walking left
var _walk_time: float = 0.0
var _recoil_offset: float = 0.0
var is_officer: bool = false # High rank enemy
var _facing: float = -1.0

@onready var sprite: Node2D = $Sprite
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var gun_point: Marker2D = $AnimatedSprite2D/GunPoint
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	add_to_group("enemy")
	if anim == null:
		if sprite: sprite.show()
	else:
		if sprite: sprite.hide()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	call_deferred("_apply_scaled_hp")

func _apply_scaled_hp() -> void:
	var hits := OFFICER_HITS_TO_KILL if is_officer else INFANTRY_HITS_TO_KILL
	var player_dmg: int = 1
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		var p = players[0]
		var v = p.get("current_damage")
		if v != null:
			player_dmg = maxi(1, int(v))
	hp = maxi(1, hits * player_dmg)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player = _find_player()
	if player:
		var dist_vec = player.global_position - global_position
		var abs_dist_x = abs(dist_vec.x)
		
		if abs_dist_x > 500:
			patrol_direction = sign(dist_vec.x)
			if _has_ground_ahead():
				_patrol(delta)
			else:
				velocity.x = 0
				_aim_and_fire(player, delta)
				
		elif abs_dist_x < 200:
			patrol_direction = -sign(dist_vec.x)
			if _has_ground_ahead():
				_patrol(delta, 0.6)
			else:
				velocity.x = 0
			_aim_and_fire(player, delta)
			
		else:
			velocity.x = 0
			_aim_and_fire(player, delta)
			
	else:
		if not _has_ground_ahead() or is_on_wall():
			patrol_direction *= -1
		_patrol(delta)

	move_and_slide()
	_recoil_offset = lerp(_recoil_offset, 0.0, 0.1)

func _has_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var test_pos = global_position + Vector2(patrol_direction * 25, 10)
	var query = PhysicsRayQueryParameters2D.create(test_pos, test_pos + Vector2(0, 50))
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _patrol(delta: float, speed_mult: float = 1.0) -> void:
	velocity.x = patrol_direction * (SPEED * (1.5 if is_officer else 1.0)) * speed_mult
	_facing = patrol_direction
	
	if is_instance_valid(anim):
		var prefix = "enemy_2_" if is_officer else "enemy_1_"
		var target_anim = prefix + "run"
		if anim.animation != target_anim:
			anim.play(target_anim)
	
	_update_sprite_scale()
	
	if int(_walk_time) % 4 == 0: 
		_walk_time += delta * 12
		_spawn_dust()

func _aim_and_fire(player: Node2D, _delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	if dir.x != 0:
		_facing = sign(dir.x)
	
	if is_instance_valid(anim):
		var anim_name = "enemy_2_run_and_gun" if is_officer else "enemy_1_gun"
		if anim.animation != anim_name:
			anim.play(anim_name)
	
	_update_sprite_scale()

	if shoot_timer.is_stopped(): 
		_shoot(player)
		var wait = (0.5 if is_officer else 1.1) + randf() * 0.4
		shoot_timer.start(wait)

func _update_sprite_scale() -> void:
	if not is_instance_valid(anim): return
	var base_scale = ANIM_SCALES.get(anim.animation, DEFAULT_SCALE)
	anim.scale.x = base_scale.x * _facing
	anim.scale.y = base_scale.y

func _on_shoot_timer_timeout() -> void:
	var p = _find_player()
	if p and global_position.distance_to(p.global_position) < 420:
		_shoot(p)

func _shoot(player: Node2D) -> void:
	var b = BULLET_SCENE.instantiate()
	var main = _get_main_scene()
	if main:
		main.bullet_container.add_child(b)
	else:
		get_parent().add_child(b)
		
	b.global_position = gun_point.global_position
	var dir = (player.global_position - b.global_position).normalized()
	b.direction = dir
	b.is_enemy_bullet = true
	b.damage = 8
	b.add_to_group("enemy_bullet")
	Audio.play("m4_fire")
	
	var shell = ColorRect.new()
	shell.size = Vector2(2, 1)
	shell.color = Color.GOLD
	shell.global_position = global_position + Vector2(0, -10)
	get_parent().add_child(shell)
	var stw = create_tween()
	stw.tween_property(shell, "position", shell.position + Vector2(-_facing * 20, -10 + randf()*5), 0.3)
	stw.tween_property(shell, "modulate:a", 0.0, 0.1)
	stw.finished.connect(shell.queue_free)
	_recoil_offset = 5.0

func _spawn_dust() -> void:
	var d = ColorRect.new()
	d.size = Vector2(4, 4)
	d.color = Color(0.6, 0.5, 0.4, 0.5)
	d.global_position = global_position + Vector2(0, 15)
	get_parent().add_child(d)
	var dtw = create_tween()
	dtw.set_parallel(true)
	dtw.tween_property(d, "position:y", d.position.y - 10, 0.4)
	dtw.tween_property(d, "modulate:a", 0.0, 0.4)
	dtw.finished.connect(d.queue_free)

func _get_main_scene() -> Node:
	var curr = get_parent()
	while curr != null:
		if curr.name == "ContraMain": return curr
		curr = curr.get_parent()
	return null

func take_damage(amount: int) -> void:
	hp -= amount
	if is_instance_valid(anim):
		var tw = create_tween()
		tw.tween_property(anim, "modulate", Color.ORANGE_RED, 0.08)
		tw.tween_property(anim, "modulate", Color.WHITE, 0.08)
	if hp <= 0: _die()

func _die() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0

	if is_instance_valid(anim):
		var prefix = "enemy_2_" if is_officer else "enemy_1_"
		var target_anim = prefix + "die"
		# Force no loop on death anim
		if anim.sprite_frames and anim.sprite_frames.has_animation(target_anim):
			anim.sprite_frames.set_animation_loop(target_anim, false)
		anim.play(target_anim)
		_update_sprite_scale()
		# Connect signal to stop on last frame
		if not anim.animation_finished.is_connected(_on_death_anim_finished):
			anim.animation_finished.connect(_on_death_anim_finished)
		# Hardcoded fallback timer in case signal doesn't fire
		get_tree().create_timer(1.2).timeout.connect(func():
			if is_instance_valid(self):
				_start_fade_and_free()
		)
	else:
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("add_kill"):
			main_node.add_kill(100, 6)
		queue_free()

func _on_death_anim_finished() -> void:
	if not is_instance_valid(anim): return
	if "die" not in anim.animation: return
	anim.pause()
	anim.frame = anim.sprite_frames.get_frame_count(anim.animation) - 1
	_start_fade_and_free()

func _start_fade_and_free() -> void:
	# Guard against double-calling
	if has_meta("_fading"): return
	set_meta("_fading", true)
	
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("add_kill"):
		main_node.add_kill(100, 6)
	
	if is_instance_valid(anim):
		var tw = create_tween()
		tw.tween_property(anim, "modulate:a", 0.0, 0.5).set_delay(0.5)
		tw.finished.connect(queue_free)
	else:
		queue_free()
