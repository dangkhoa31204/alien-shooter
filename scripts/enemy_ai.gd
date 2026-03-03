extends Node
# enemy_ai.gd — Perception → Decision → Action (State Machine)
# Tách hoàn toàn khỏi movement để dễ nâng cấp AI độc lập.

enum State { IDLE, ATTACK, ESCAPE, KAMIKAZE }

# Ngưỡng quyết định
const HP_ESCAPE_RATIO: float      = 0.35   # < 35% máu → ESCAPE
const ATTACK_DIST: float          = 220.0  # < 220px với player → ATTACK
const BULLET_DETECT_RADIUS: float = 150.0  # detect đạn trong vùng này
const KAMIKAZE_HP_RATIO: float    = 0.20   # ≤ 20% máu + gần → kamikaze
const KAMIKAZE_DIST: float        = 350.0  # khoảng cách trigger kamikaze
const KAMIKAZE_IDLE_TIME: float   = 5.5    # giây IDLE trước khi roll ngẫu nhiên

var state: State = State.IDLE
var enemy: CharacterBody2D       # node enemy cha
var player: CharacterBody2D      # reference đến player
var time_in_state: float = 0.0

# ── SETUP ─────────────────────────────────────────────────────────────────────
func setup(enemy_node: CharacterBody2D) -> void:
	enemy = enemy_node
	call_deferred("_find_player")

func _find_player() -> void:
	player = get_tree().current_scene.get_node_or_null("Player")

# ── MAIN LOOP (gọi mỗi frame bởi enemy._physics_process) ─────────────────────
func update(delta: float) -> void:
	time_in_state += delta
	if player == null or not is_instance_valid(player):
		_find_player()
		# Vẫn di chuyển dù chưa tìm được player
		if is_instance_valid(enemy):
			enemy.move_by_pattern(delta)
		return

	# 1. PERCEPTION — thu thập thông tin môi trường
	var hp_ratio       := float(enemy.hp) / float(enemy.max_hp)
	var dist_to_player := enemy.global_position.distance_to(player.global_position)

	# 2. DECISION — chọn state dựa trên perception
	_decide(hp_ratio, dist_to_player)

	# 3. ACTION — thực thi movement theo state
	_execute(delta)

# ── DECISION ──────────────────────────────────────────────────────────────────
func _decide(hp_ratio: float, dist: float) -> void:
	# Kamikaze là trạng thái không thể đảo ngược — lock cho đến khi chết
	if state == State.KAMIKAZE:
		return

	var new_state: State

	# Trigger kamikaze: máu rất thấp + đủ gần
	if hp_ratio <= KAMIKAZE_HP_RATIO and dist < KAMIKAZE_DIST:
		new_state = State.KAMIKAZE
	# Ngẫu nhiên kamikaze nếu đã IDLE lâu (enemy chán → liều mạng)
	elif state == State.IDLE and time_in_state > KAMIKAZE_IDLE_TIME \
			and randf() < 0.0003:
		new_state = State.KAMIKAZE
	elif hp_ratio <= HP_ESCAPE_RATIO:
		new_state = State.ESCAPE          # máu thấp → chạy
	elif dist < ATTACK_DIST:
		new_state = State.ATTACK          # gần player → tấn công
	else:
		new_state = State.IDLE            # mặc định: bay zigzag

	if new_state != state:
		state = new_state
		time_in_state = 0.0
		# Cảnh báo người chơi khi enemy kamikaze
		if new_state == State.KAMIKAZE and is_instance_valid(enemy):
			enemy.set_kamikaze_color()

# ── ACTION ────────────────────────────────────────────────────────────────────
func _execute(delta: float) -> void:
	match state:
		State.IDLE:
			enemy.move_by_pattern(delta)   # dùng pattern được gán từ wave_manager
		State.ATTACK:
			# Theo player trên trục X + áp sát
			enemy.move_toward_player_x(player.global_position, delta)
		State.ESCAPE:
			# Bay ngược lên để thoát
			enemy.move_escape(delta)
		State.KAMIKAZE:
			# Lao thẳng vào player — sẽ tự huỷ khi chạm hoặc ra ngoài màn hình
			enemy.move_kamikaze(delta)
