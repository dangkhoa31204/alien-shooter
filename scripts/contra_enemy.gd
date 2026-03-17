extends CharacterBody2D

# contra_enemy.gd
# Advanced Side-scrolling US Soldier AI with procedural movement and animations.

const BULLET_SCENE = preload("res://scenes/bullet.tscn")

const SPEED: float = 120.0
const GRAVITY: float = 1400.0
const DETECTION_RANGE: float = 320.0

const INFANTRY_HITS_TO_KILL: int = 2
const OFFICER_HITS_TO_KILL: int = 6

var hp: int = 14
var patrol_direction: int = -1 # Start walking left
var _walk_time: float = 0.0
var _recoil_offset: float = 0.0
var is_officer: bool = false # High rank enemy

@onready var sprite: Node2D = $Sprite
@onready var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var gun_point: Marker2D = $AnimatedSprite2D/GunPoint
@onready var shoot_timer: Timer = $ShootTimer

func _ready() -> void:
	add_to_group("enemy")
	if anim == null:
		if sprite: sprite.show() # Hiện lại hình cũ nếu không tìm thấy hoạt ảnh mới
	else:
		if sprite: sprite.hide()
	shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	# Ensure intended TTK stays consistent across different player weapon damages.
	call_deferred("_apply_scaled_hp")


func _apply_scaled_hp() -> void:
	var hits := OFFICER_HITS_TO_KILL if is_officer else INFANTRY_HITS_TO_KILL
	var player_dmg: int = 1
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0 and is_instance_valid(players[0]):
		var p = players[0]
		# contra_player.gd exposes current_damage; fall back to 1 if missing.
		var v = p.get("current_damage")
		if v != null:
			player_dmg = maxi(1, int(v))
	hp = maxi(1, hits * player_dmg)

	# call_deferred("_setup_complex_visuals") # Removed procedural visuals setup

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var player = _find_player()
	if player:
		var dist_vec = player.global_position - global_position
		var abs_dist_x = abs(dist_vec.x)
		
		# --- Tầm nhìn và Phản xạ chiến thuật ---
		# 1. Nếu quá xa (> 500px): Tiến lại gần để bắn
		if abs_dist_x > 500:
			patrol_direction = sign(dist_vec.x)
			if _has_ground_ahead():
				_patrol(delta)
			else:
				velocity.x = 0
				_aim_and_fire(player, delta) # Đứng lại bắn nếu hết đường
				
		# 2. Nếu quá gần (< 200px): Lùi lại để giữ khoảng cách an toàn
		elif abs_dist_x < 200:
			patrol_direction = -sign(dist_vec.x) # Đi ngược hướng player
			if _has_ground_ahead():
				_patrol(delta, 0.6) # Lùi chậm hơn
			else:
				velocity.x = 0
			_aim_and_fire(player, delta)
			
		# 3. Khoảng cách bắn lý tưởng (200px - 500px): Đứng lại nã đạn
		else:
			velocity.x = 0
			_aim_and_fire(player, delta)
			
	else:
		# Không thấy player thì đi tuần bình thường
		if not _has_ground_ahead() or is_on_wall():
			patrol_direction *= -1
		
		_patrol(delta)

	move_and_slide()

	
	# Recoil/Animation handled via Sprite frames now
	_recoil_offset = lerp(_recoil_offset, 0.0, 0.1)

# Kiểm tra xem phía trước có đất không (tránh lao xuống vực)
func _has_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	# Chiếu một tia xuống đất phía trước hướng đang đi
	var test_pos = global_position + Vector2(patrol_direction * 25, 10)
	var query = PhysicsRayQueryParameters2D.create(test_pos, test_pos + Vector2(0, 50))
	# Loại bỏ bản thân khỏi danh sách va chạm
	query.exclude = [get_rid()]
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	return players[0] if players.size() > 0 else null

func _patrol(delta: float, speed_mult: float = 1.0) -> void:
	velocity.x = patrol_direction * (SPEED * (1.5 if is_officer else 1.0)) * speed_mult
	if is_instance_valid(anim):
		anim.scale.x = abs(anim.scale.x) * patrol_direction
		var prefix = "enemy_2_" if is_officer else "enemy_1_"
		if anim.animation != prefix + "run":
			anim.play(prefix + "run")
	
	if int(_walk_time) % 4 == 0: 
		_walk_time += delta * 12 # Keep track for dust
		_spawn_dust()

func _aim_and_fire(player: Node2D, _delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	if is_instance_valid(anim):
		anim.scale.x = abs(anim.scale.x) * (sign(dir.x) if dir.x != 0 else 1.0)
		var anim_name = "enemy_2_run_and_gun" if is_officer else "enemy_1_gun"
		if anim.animation != anim_name:
			anim.play(anim_name)
	
	# Rotate GunPoint if needed (bullets use direction from muzzle flash pos)
	# GunPoint in anim is usually fixed, but we keep the script logic flexible

	if shoot_timer.is_stopped(): 
		# Fire the first shot almost immediately (0.1s reflex) then start normal cooldown
		_shoot(player)
		var wait = (0.5 if is_officer else 1.1) + randf() * 0.4
		shoot_timer.start(wait)

func _on_shoot_timer_timeout() -> void:
	var p = _find_player()
	# FIX: was using DETECTION_RANGE (320) but engagement is 420 → enemy aimed but never shot
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
	
	# Shell ejection effect
	var shell = ColorRect.new(); shell.size = Vector2(2, 1); shell.color = Color.GOLD; shell.global_position = global_position + Vector2(0, -10); get_parent().add_child(shell)
	var stw = create_tween(); stw.tween_property(shell, "position", shell.position + Vector2(-sprite.scale.x * 20, -10 + randf()*5), 0.3)
	stw.tween_property(shell, "modulate:a", 0.0, 0.1); stw.finished.connect(shell.queue_free)
	
	_recoil_offset = 5.0

func _spawn_dust() -> void:
	var d = ColorRect.new(); d.size = Vector2(4, 4); d.color = Color(0.6, 0.5, 0.4, 0.5); d.global_position = global_position + Vector2(0, 15); get_parent().add_child(d)
	var dtw = create_tween(); dtw.set_parallel(true); dtw.tween_property(d, "position:y", d.position.y - 10, 0.4); dtw.tween_property(d, "modulate:a", 0.0, 0.4); dtw.finished.connect(d.queue_free)

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
	collision_layer = 0; collision_mask = 0

	if is_instance_valid(anim):
		var prefix = "enemy_2_" if is_officer else "enemy_1_"
		anim.play(prefix + "die")

	# Báo điểm và kill cho main
	var main_node = get_tree().current_scene
	if main_node and main_node.has_method("add_kill"):
		main_node.add_kill(100, 6)

	if is_instance_valid(anim):
		var tw = create_tween()
		tw.tween_property(anim, "modulate:a", 0.0, 1.0).set_delay(1.5)
		tw.finished.connect(queue_free)
	else:
		queue_free()
