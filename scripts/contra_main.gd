extends Node2D

# contra_main.gd - v2.0 (Modularized Stages)
# Premium Side-scrolling controller with Bombers and Progress Tracking.

const PLAYER_SCENE = preload("res://scenes/contra_player.tscn")
const ENEMY_SCENE  = preload("res://scenes/contra_enemy.tscn")
const BOMBER_SCENE = preload("res://scenes/contra_bomber.tscn")
const TURRET_SCENE = preload("res://scenes/contra_turret.tscn")
const TANK_SCENE   = preload("res://scripts/contra_tank.gd")

const STAGE_SCRIPTS = {
	1: preload("res://scripts/stages/contra_jungle.gd"),
	2: preload("res://scripts/stages/contra_tunnels.gd"),
	3: preload("res://scripts/stages/contra_highlands.gd"),
	4: preload("res://scripts/stages/contra_base.gd"),
	5: preload("res://scripts/stages/contra_final.gd")
}

var STAGE_LENGTH: float = 12000.0 # Increased for longer gameplay
const RPG_MAX_COOLDOWN: float = 10.0

var current_stage: int = 1
var score: int = 0
var kill_count: int = 0
var is_game_over: bool = false

@onready var ui_label: Label = $UI/Label
@onready var stage_label: Label = $UI/StageLabel
@onready var camera: Camera2D = $Camera2D
@onready var bullet_container: Node2D = $BulletContainer

var progress_bar: ProgressBar
var hp_bar: ProgressBar
var player: CharacterBody2D = null
var _world: Node2D = null
var _parallax_bg: Node2D = null
var _cheat_menu: Control = null
var _is_cheat_visible: bool = false
var _pause_menu: Control = null
var _is_paused: bool = false

# Screen shake state
var _shake_power: float = 0.0
var _shake_time: float = 0.0
var _bomber_timer: float = 5.0
var _army_spawn_timer: float = 1.0 
var _allied_tank_timer: float = 5.0 
var _enemy_spawn_timer: float = 2.0 # Dynamic enemy spawn
var _stage_terrain: PackedVector2Array = PackedVector2Array()
var last_checkpoint_x: float = 100.0
var _checkpoint_positions: Array[float] = []
var _rpg_cooldown_timer: float = 0.0 # Added for RPG cooldown tracking
var _perf_frame: int = 0
var _flash_rect: ColorRect = null # Persistent flash for explosions
var _level_node: Node2D = null # Container for all stage-specific objects (for fast cleanup)
var _history_panel: Control = null # Historical info panel
var _showing_stage_history: bool = false # True when history popup shown at stage start
var _damage_vignette: ColorRect = null # Red flash on damage
var _alert_panel: Panel = null          # Animated alert panel

func _add_to_level(node: Node) -> void:
	if is_instance_valid(_level_node):
		_level_node.add_child(node)
	else:
		_world.add_child(node)

# ── SCORE / KILL TRACKING ───────────────────────────────────────────────────
func add_score(pts: int) -> void:
	score += pts
	var lbl = get_node_or_null("UI/HUDPanel/ScoreLabel")
	if lbl: lbl.text = str(score)

# ── kill-feed state ────────────────────────────────────────────────────────
var _kill_feed_items: Array = []          # Array[Label]
const KILL_FEED_MAX: int = 4

func add_kill(pts: int = 100) -> void:
	kill_count += 1
	add_score(pts)
	var kl = get_node_or_null("UI/HUDPanel/KillLabel")
	if kl: kl.text = "⚔ %d tiêu diệt" % kill_count
	_spawn_kill_feed_popup(pts)

func _spawn_kill_feed_popup(pts: int) -> void:
	var ui = get_node_or_null("UI")
	if not ui: return
	# Shift existing entries up
	for lbl: Label in _kill_feed_items:
		if is_instance_valid(lbl):
			lbl.position.y -= 22
	# Remove overflow
	if _kill_feed_items.size() >= KILL_FEED_MAX:
		var old: Label = _kill_feed_items.pop_front()
		if is_instance_valid(old): old.queue_free()
	var entry := Label.new()
	entry.text = "💀 +%d" % pts
	entry.add_theme_font_size_override("font_size", 13)
	entry.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	entry.position = Vector2(900, 100)
	entry.modulate.a = 1.0
	ui.add_child(entry)
	_kill_feed_items.append(entry)
	var tw: Tween = entry.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(entry, "modulate:a", 0.0, 0.5)
	tw.finished.connect(func():
		_kill_feed_items.erase(entry)
		if is_instance_valid(entry): entry.queue_free()
	)

func _get_ground_y(x_pos: float) -> float:
	if current_stage >= 4: return 600.0 # Map 4 & 5 are flat
	if _stage_terrain.is_empty(): return 600.0
	
	var terrain_size = _stage_terrain.size()
	# Fast Binary Search for large terrain sets
	var low_idx = 0
	var high_idx = terrain_size - 2
	var res_idx = -1
	
	while low_idx <= high_idx:
		var mid_idx = floori((float(low_idx) + float(high_idx)) / 2.0)
		if x_pos >= _stage_terrain[mid_idx].x and x_pos <= _stage_terrain[mid_idx+1].x:
			res_idx = mid_idx
			break
		elif x_pos < _stage_terrain[mid_idx].x:
			high_idx = mid_idx - 1
		else:
			low_idx = mid_idx + 1
			
	if res_idx != -1:
		var p_node1 = _stage_terrain[res_idx]
		var p_node2 = _stage_terrain[res_idx+1]
		if p_node1.x == p_node2.x: return p_node1.y
		var t_lerp = (x_pos - p_node1.x) / (p_node2.x - p_node1.x)
		return lerp(p_node1.y, p_node2.y, t_lerp)
	
	# Out of bounds fallback: use the nearest edge point
	if x_pos < _stage_terrain[0].x: return _stage_terrain[0].y
	return _stage_terrain[terrain_size - 1].y

func _ready() -> void:
	Audio.stop_menu_music()
	_world = Node2D.new(); _world.name = "World"; add_child(_world)
	move_child(_world, 0)
	
	_parallax_bg = Node2D.new(); _parallax_bg.name = "Parallax"; _world.add_child(_parallax_bg)
	
	_setup_background_sky()
	_setup_progress_ui()
	
	if not has_node("Camera2D"):
		camera = Camera2D.new()
		add_child(camera)
		camera.make_current()
	
	_setup_cheat_menu()
	_setup_pause_menu()
	_setup_pause_button()
	_start_stage(PlayerData.current_selected_stage)
	
	# Đảm bảo các đối tượng con của root (world, objects) sẽ pause khi tree paused
	# Self must be ALWAYS so _input() receives ESC/F1 while paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	if camera: camera.process_mode = Node.PROCESS_MODE_PAUSABLE
	if bullet_container: bullet_container.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	_level_node = Node2D.new(); _level_node.name = "LevelNode"; _world.add_child(_level_node)
	
	# Persistent Full-screen Flash Rect
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 0.9, 0.7, 0.0)
	_flash_rect.size = Vector2(2500, 2000); _flash_rect.position = Vector2(-500, -500)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_flash_rect)
	# Damage vignette (red edge flash)
	_damage_vignette = ColorRect.new()
	_damage_vignette.color = Color(0.8, 0.0, 0.0, 0.0)
	_damage_vignette.size = Vector2(1152, 720)
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_vignette.z_index = 90
	$UI.add_child(_damage_vignette)

func _setup_progress_ui() -> void:
	# ── Màu chuẩn military ────────────────────────────────────────────────────
	var C_OLIVE    := Color(0.08, 0.14, 0.06, 0.92)   # màu nền bảng HUD
	var C_GOLD     := Color(0.82, 0.70, 0.18)          # viền vàng
	var C_RED_DARK := Color(0.55, 0.06, 0.06)          # đỏ tối cho nền HP
	var C_RED_LIT  := Color(0.92, 0.12, 0.12)          # đỏ tươi cho thanh HP
	var C_TEXT     := Color(0.95, 0.92, 0.72)          # vàng kem chữ HUD

	# ── Helper tạo StyleBoxFlat ─────────────────────────────────────────────
	var _make_sbox := func(bg: Color, bdr: Color, bw: int = 1, cr: int = 4) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = bg; s.border_color = bdr
		s.border_width_left = bw; s.border_width_right = bw
		s.border_width_top = bw; s.border_width_bottom = bw
		s.set_corner_radius_all(cr)
		return s

	# ══════════════════════════════════════════════════════════════════════════
	# 1. THANH TIẾN TRÌNH ở giữa trên (rộng hơn, dày hơn, nhãn rõ hơn)
	# ══════════════════════════════════════════════════════════════════════════
	var prog_panel := Panel.new()
	prog_panel.name = "ProgressPanel"
	prog_panel.position = Vector2(326, 8)
	prog_panel.size = Vector2(500, 34)
	prog_panel.add_theme_stylebox_override("panel", _make_sbox.call(
		Color(0.05, 0.08, 0.04, 0.88), C_GOLD, 1, 5))
	$UI.add_child(prog_panel)

	var prog_lbl := Label.new()
	prog_lbl.name = "ProgLabel"
	prog_lbl.text = "⚔  TIẾN TRÌNH CHIẾN DỊCH"
	prog_lbl.add_theme_font_size_override("font_size", 11)
	prog_lbl.add_theme_color_override("font_color", C_GOLD)
	prog_lbl.position = Vector2(8, 2)
	prog_panel.add_child(prog_lbl)

	progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.size = Vector2(480, 10)
	progress_bar.position = Vector2(10, 20)
	progress_bar.max_value = STAGE_LENGTH
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _make_sbox.call(Color(0,0,0,0.5), C_GOLD, 1, 2))
	var fg_style := StyleBoxFlat.new(); fg_style.bg_color = Color(0.88, 0.76, 0.14); fg_style.set_corner_radius_all(2)
	progress_bar.add_theme_stylebox_override("fill", fg_style)
	prog_panel.add_child(progress_bar)

	# ══════════════════════════════════════════════════════════════════════════
	# 2. HUD PANEL trái — nền mờ chứa toàn bộ chỉ số chiến đấu
	# ══════════════════════════════════════════════════════════════════════════
	var hud_panel := Panel.new()
	hud_panel.name = "HUDPanel"
	hud_panel.position = Vector2(8, 8)
	hud_panel.size = Vector2(310, 148)
	hud_panel.add_theme_stylebox_override("panel", _make_sbox.call(C_OLIVE, C_GOLD, 2, 6))
	$UI.add_child(hud_panel)

	# Dải viền vàng nhỏ ở trên cùng bảng (tai trang trí)
	var hud_header := ColorRect.new()
	hud_header.size = Vector2(310, 4)
	hud_header.color = C_GOLD
	hud_panel.add_child(hud_header)

	# ── 2a. HP ───────────────────────────────────────────────────────────────
	var hp_lbl_icon := Label.new()
	hp_lbl_icon.text = "HP"
	hp_lbl_icon.add_theme_font_size_override("font_size", 12)
	hp_lbl_icon.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	hp_lbl_icon.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	hp_lbl_icon.add_theme_constant_override("shadow_offset_x", 1)
	hp_lbl_icon.add_theme_constant_override("shadow_offset_y", 1)
	hp_lbl_icon.position = Vector2(10, 8)
	hud_panel.add_child(hp_lbl_icon)

	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.size = Vector2(205, 14)
	hp_bar.position = Vector2(40, 10)
	hp_bar.max_value = 3
	hp_bar.value = 3
	hp_bar.show_percentage = false
	hp_bar.add_theme_stylebox_override("background", _make_sbox.call(C_RED_DARK, Color(0.8,0.2,0.2,0.6), 1, 3))
	var hp_fg := StyleBoxFlat.new(); hp_fg.bg_color = C_RED_LIT; hp_fg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", hp_fg)
	hud_panel.add_child(hp_bar)

	var hp_num_lbl := Label.new()
	hp_num_lbl.name = "HPNumLabel"
	hp_num_lbl.text = "3 / 3"
	hp_num_lbl.add_theme_font_size_override("font_size", 12)
	hp_num_lbl.add_theme_color_override("font_color", C_TEXT)
	hp_num_lbl.position = Vector2(252, 8)
	hud_panel.add_child(hp_num_lbl)

	# ── 2b. ĐẠN ──────────────────────────────────────────────────────────────
	var ammo_icon_lbl := Label.new()
	ammo_icon_lbl.text = "ĐẠN"
	ammo_icon_lbl.add_theme_font_size_override("font_size", 12)
	ammo_icon_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	ammo_icon_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	ammo_icon_lbl.add_theme_constant_override("shadow_offset_x", 1)
	ammo_icon_lbl.add_theme_constant_override("shadow_offset_y", 1)
	ammo_icon_lbl.position = Vector2(10, 30)
	hud_panel.add_child(ammo_icon_lbl)

	var ammo_lbl := Label.new()
	ammo_lbl.name = "AmmoLabel"
	ammo_lbl.text = "30 / 30"
	ammo_lbl.add_theme_font_size_override("font_size", 14)
	ammo_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35))
	ammo_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	ammo_lbl.add_theme_constant_override("shadow_offset_x", 1)
	ammo_lbl.add_theme_constant_override("shadow_offset_y", 1)
	ammo_lbl.position = Vector2(48, 28)
	hud_panel.add_child(ammo_lbl)

	# ── Separator ─────────────────────────────────────────────────────────────
	var b40_sep := ColorRect.new()
	b40_sep.size = Vector2(290, 1); b40_sep.position = Vector2(10, 52)
	b40_sep.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.35)
	hud_panel.add_child(b40_sep)

	# ── 2c. B40 ───────────────────────────────────────────────────────────────
	var b40_icon := Label.new()
	b40_icon.text = "💥 B40"
	b40_icon.add_theme_font_size_override("font_size", 12)
	b40_icon.add_theme_color_override("font_color", Color(1.0, 0.5, 0.1))
	b40_icon.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	b40_icon.add_theme_constant_override("shadow_offset_x", 1)
	b40_icon.add_theme_constant_override("shadow_offset_y", 1)
	b40_icon.position = Vector2(10, 58)
	hud_panel.add_child(b40_icon)

	var b40_cd_bar := ProgressBar.new()
	b40_cd_bar.name = "B40CoolBar"
	b40_cd_bar.size = Vector2(125, 10)
	b40_cd_bar.position = Vector2(72, 61)
	b40_cd_bar.max_value = RPG_MAX_COOLDOWN
	b40_cd_bar.value = RPG_MAX_COOLDOWN
	b40_cd_bar.show_percentage = false
	b40_cd_bar.add_theme_stylebox_override("background", _make_sbox.call(Color(0.12,0.06,0.0,0.7), Color(0.6,0.3,0.0,0.5), 1, 2))
	var b40_fg := StyleBoxFlat.new(); b40_fg.bg_color = Color(1.0, 0.45, 0.0); b40_fg.set_corner_radius_all(2)
	b40_cd_bar.add_theme_stylebox_override("fill", b40_fg)
	hud_panel.add_child(b40_cd_bar)

	var b40_cd_lbl := Label.new()
	b40_cd_lbl.name = "B40CDLabel"
	b40_cd_lbl.text = "SẴN SÀNG"
	b40_cd_lbl.add_theme_font_size_override("font_size", 11)
	b40_cd_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	b40_cd_lbl.position = Vector2(203, 57)
	hud_panel.add_child(b40_cd_lbl)

	# ── 2d. AA MISSILE [X] ───────────────────────────────────────────────────
	var aa_icon := Label.new()
	aa_icon.text = "🚀 AA [X]"
	aa_icon.add_theme_font_size_override("font_size", 12)
	aa_icon.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	aa_icon.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	aa_icon.add_theme_constant_override("shadow_offset_x", 1)
	aa_icon.add_theme_constant_override("shadow_offset_y", 1)
	aa_icon.position = Vector2(10, 82)
	hud_panel.add_child(aa_icon)

	var aa_cd_bar := ProgressBar.new()
	aa_cd_bar.name = "AACoolBar"
	aa_cd_bar.size = Vector2(100, 10)
	aa_cd_bar.position = Vector2(105, 85)
	aa_cd_bar.max_value = 10.0
	aa_cd_bar.value = 10.0
	aa_cd_bar.show_percentage = false
	aa_cd_bar.add_theme_stylebox_override("background", _make_sbox.call(Color(0.04,0.06,0.15,0.8), Color(0.2,0.3,0.6,0.5), 1, 2))
	var aa_fg := StyleBoxFlat.new(); aa_fg.bg_color = Color(0.3, 0.8, 1.0); aa_fg.set_corner_radius_all(2)
	aa_cd_bar.add_theme_stylebox_override("fill", aa_fg)
	hud_panel.add_child(aa_cd_bar)

	var aa_cd_lbl := Label.new()
	aa_cd_lbl.name = "AACDLabel"
	aa_cd_lbl.text = "SẴN SÀNG"
	aa_cd_lbl.add_theme_font_size_override("font_size", 11)
	aa_cd_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	aa_cd_lbl.position = Vector2(211, 81)
	hud_panel.add_child(aa_cd_lbl)

	# ── Separator ─────────────────────────────────────────────────────────────
	var score_sep := ColorRect.new()
	score_sep.size = Vector2(290, 1); score_sep.position = Vector2(10, 104)
	score_sep.color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.35)
	hud_panel.add_child(score_sep)

	# ── 2e. SỐ ĐIỂM ──────────────────────────────────────────────────────────
	var score_icon := Label.new()
	score_icon.text = "★ ĐIỂM"
	score_icon.add_theme_font_size_override("font_size", 12)
	score_icon.add_theme_color_override("font_color", C_GOLD)
	score_icon.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	score_icon.add_theme_constant_override("shadow_offset_x", 1)
	score_icon.add_theme_constant_override("shadow_offset_y", 1)
	score_icon.position = Vector2(10, 109)
	hud_panel.add_child(score_icon)

	var score_val_lbl := Label.new()
	score_val_lbl.name = "ScoreLabel"
	score_val_lbl.text = "0"
	score_val_lbl.add_theme_font_size_override("font_size", 14)
	score_val_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.5))
	score_val_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	score_val_lbl.add_theme_constant_override("shadow_offset_x", 1)
	score_val_lbl.add_theme_constant_override("shadow_offset_y", 1)
	score_val_lbl.position = Vector2(70, 107)
	hud_panel.add_child(score_val_lbl)

	var kill_lbl := Label.new()
	kill_lbl.name = "KillLabel"
	kill_lbl.text = "⚔ 0 tiêu diệt"
	kill_lbl.add_theme_font_size_override("font_size", 11)
	kill_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.55))
	kill_lbl.position = Vector2(10, 129)
	hud_panel.add_child(kill_lbl)

func refresh_hp(val: int, max_val: int) -> void:
	if hp_bar:
		hp_bar.max_value = max_val
		hp_bar.value = val
	var num_lbl = get_node_or_null("UI/HUDPanel/HPNumLabel")
	if num_lbl:
		num_lbl.text = "%d / %d" % [val, max_val]
	# Persistent low-HP vignette pulse when 1 HP left
	if is_instance_valid(_damage_vignette):
		if val == 1:
			if not _damage_vignette.has_meta("low_hp_looping"):
				_damage_vignette.set_meta("low_hp_looping", true)
				var lhtw: Tween = _damage_vignette.create_tween().set_loops()
				lhtw.tween_property(_damage_vignette, "modulate:a", 0.35, 0.6)
				lhtw.tween_property(_damage_vignette, "modulate:a", 0.0, 0.6)
		else:
			if _damage_vignette.has_meta("low_hp_looping"):
				_damage_vignette.remove_meta("low_hp_looping")
				_damage_vignette.modulate.a = 0.0

func refresh_ammo(val: int, max_val: int, is_rel: bool) -> void:
	var al = get_node_or_null("UI/HUDPanel/AmmoLabel")
	if not al:  # fallback lazy-create if HUD panel missing
		if not has_node("UI/AmmoLabel"):
			var lbl = Label.new(); lbl.name = "AmmoLabel"; lbl.position = Vector2(20, 85)
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", Color.YELLOW)
			$UI.add_child(lbl)
		al = $UI/AmmoLabel
	if is_rel:
		al.text = "  NẠP ĐẠN..."
		al.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		var color := Color(0.3, 1.0, 0.3) if val > max_val / 4 else Color(1.0, 0.6, 0.1)
		al.text = "%d / %d" % [val, max_val]
		al.add_theme_color_override("font_color", color)

func _process(delta: float) -> void:
	if is_game_over: return
	var tree = get_tree()
	if not tree: return
	if tree.paused: return
	
	if _rpg_cooldown_timer > 0:
		_rpg_cooldown_timer -= delta
		if _rpg_cooldown_timer < 0:
			_rpg_cooldown_timer = 0
		refresh_heavy_weapon(_rpg_cooldown_timer, RPG_MAX_COOLDOWN)
	
	if is_instance_valid(player):
		var look_ahead: float = clamp(player.velocity.x * 0.12, -120.0, 120.0)
		var target_x: float = player.position.x + look_ahead
		camera.position.x = lerp(camera.position.x, target_x, 6.0 * delta)
		# FIX: always clamp min to 576 (half screen) so left edge never shows negative world x
		camera.position.x = clamp(camera.position.x, 576.0, STAGE_LENGTH - 500)
		
		# Sync B40 HUD from actual player cooldown
		if player.get("rpg_cooldown") != null:
			refresh_heavy_weapon(player.rpg_cooldown, RPG_MAX_COOLDOWN)
		
		# Vertical Camera Follow (Follow player into tunnels)
		var target_y = 360.0
		if player.position.y > 650:
			target_y = 550.0 # Shift down to see the tunnel path clearly
		camera.position.y = lerp(camera.position.y, target_y, 4.0 * delta)
		
		# Background is static in world space — no parallax movement applied
		
		# Update Progress Bar
		progress_bar.value = player.position.x
		
		if player.position.x > STAGE_LENGTH - 100: on_stage_complete()
		
		# Staggered background army processing (update subset of units per frame)
		_perf_frame += 1
		if _perf_frame % 2 == 0:
			_process_background_army(delta)
		
		# Army spawn: soldiers enter from the LEFT edge, march right alongside player
		_army_spawn_timer -= delta
		if _army_spawn_timer <= 0:
			var army_cap = 20 if current_stage == 5 else 14
			var current_army_count = tree.get_nodes_in_group("ally_army").size()
			if current_army_count < army_cap:
				var spawn_count = 2
				for _si in spawn_count:
					# Spawn just past the left edge of screen so they walk in immediately
					var sx = camera.position.x - 576 - randf_range(10, 80)
					var use_tunnel = (current_stage == 2 and randf() < 0.35)
					var sy = 650.0 if use_tunnel else _get_ground_y(sx)
					_add_individual_background_soldier(sx, sy, use_tunnel)
		
		# Map 5: Continuous tank column spawn from the LEFT edge
		if current_stage == 5:
			_allied_tank_timer -= delta
			if _allied_tank_timer <= 0:
				var tax = camera.position.x - 650 # Spawn just off left screen
				_spawn_heavy_enemy(tax, 580, "tank", true, false)
				_allied_tank_timer = randf_range(12.0, 18.0)
			# Always reset timer
			_army_spawn_timer = 3.0
		
		# Dynamic Enemy Spawning (To keep the action going)
		_enemy_spawn_timer -= delta
		if _enemy_spawn_timer <= 0:
			var enemies = tree.get_nodes_in_group("enemy").size()
			var base_max = 8
			if current_stage == 2: base_max = 12
			elif current_stage == 3: base_max = 8 # Less crowded for Map 3
			elif current_stage == 5: base_max = 4
			
			if enemies < base_max:
				var spawn_x = camera.position.x + 900 + randf_range(100, 400)
				if spawn_x < STAGE_LENGTH - 400:
					var ey = _get_ground_y(spawn_x) - 20
					if current_stage == 2: ey = 550
					_spawn_enemy(spawn_x, ey, randf() < 0.25)
			
			var st_timer = randf_range(1.5, 3.5) if current_stage == 3 else randf_range(2.0, 4.0)
			if current_stage == 2: st_timer = randf_range(1.5, 3.0)
			if current_stage == 3: st_timer = randf_range(5.0, 9.0) # Thưa ra hơn nữa
			if current_stage == 5: st_timer = randf_range(4.5, 8.0) # Rất thưa
			_enemy_spawn_timer = st_timer

		# Random Bomber Spawns (Scales with difficulty/stage)
		_bomber_timer -= delta
		if _bomber_timer <= 0:
			_spawn_bomber()
			var base_timer = lerp(12.0, 4.0, float(current_stage - 1) / 4.0)
			# Stage 3 Special: Much higher bomber frequency
			if current_stage == 3: base_timer *= 0.4 
			_bomber_timer = randf_range(base_timer * 0.7, base_timer * 1.3)

		# Check for bombs hitting the ground
		_process_bombs(delta)

	if _shake_time > 0:
		_shake_time -= delta
		camera.offset = Vector2(randf_range(-_shake_power, _shake_power), randf_range(-_shake_power, _shake_power))
	else:
		camera.offset = Vector2.ZERO

func _process_bombs(_delta: float) -> void:
	var tree = get_tree()
	if not tree: return
	
	var bullets = tree.get_nodes_in_group("enemy_bullet")
	var count = bullets.size()
	if count == 0: return

	var space_state = get_world_2d().direct_space_state
	var cam_x = camera.global_position.x
	
	# Skip some bullets per frame if many exist
	var step = 1 if count < 10 else 2
	
	for idx_b in range(0, count, step):
		var b = bullets[idx_b]
		if (idx_b + _perf_frame) % step != 0: continue
		if not is_instance_valid(b): continue
		
		# Proximity early exit (Performance)
		if b.global_position.x < cam_x - 700 or b.global_position.x > cam_x + 900:
			if b.global_position.x < cam_x - 1200 or b.global_position.x > cam_x + 1500:
				b.queue_free()
			continue

		if not b.has_meta("is_bomb") and not b.has_meta("is_tank_shell"): continue
		
		var contact_offset = 20.0
		var ground_y = _get_ground_y(b.global_position.x)
		
		if b.global_position.y >= ground_y - contact_offset:
			var query = PhysicsRayQueryParameters2D.create(b.global_position, b.global_position + Vector2(0, 30))
			var result = space_state.intersect_ray(query)
			
			if result or b.global_position.y >= ground_y - 5.0:
				_explode_bomb(b.global_position)
				b.queue_free()
		elif b.global_position.y > 1000: 
			b.queue_free()

func _explode_bomb(pos: Vector2) -> void:
	screen_shake(12.0, 0.4)
	Audio.play("b40", 12.0)

	# Layer 1 — white hot core
	var core := Polygon2D.new()
	var core_pts: Array = []
	for i in 10:
		var a := i * TAU / 10.0
		core_pts.append(Vector2(cos(a) * 30.0, sin(a) * 30.0))
	core.polygon = PackedVector2Array(core_pts)
	core.color = Color(1.0, 1.0, 0.9, 1.0)
	core.global_position = pos; core.z_index = 8
	_add_to_level(core)
	var core_tw: Tween = core.create_tween().set_parallel(true)
	core_tw.tween_property(core, "scale", Vector2(0.4, 0.4), 0.0)
	core_tw.chain().tween_property(core, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD)
	core_tw.tween_property(core, "modulate:a", 0.0, 0.2).set_delay(0.08)
	core_tw.finished.connect(core.queue_free)

	# Layer 2 — orange fireball ring
	var blast := Polygon2D.new()
	var blast_pts: Array = []
	for i in 14:
		var a := i * TAU / 14.0
		var r := 70.0 * (0.85 + randf() * 0.3)
		blast_pts.append(Vector2(cos(a) * r, sin(a) * r))
	blast.polygon = PackedVector2Array(blast_pts)
	blast.color = Color(1.0, 0.45, 0.1, 0.9)
	blast.global_position = pos; blast.z_index = 7
	_add_to_level(blast)
	var blast_tw: Tween = blast.create_tween().set_parallel(true)
	blast_tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	blast_tw.tween_property(blast, "scale", Vector2(1.6, 1.6), 0.3)
	blast_tw.tween_property(blast, "modulate:a", 0.0, 0.35).set_delay(0.1)
	blast_tw.finished.connect(blast.queue_free)

	# Layer 3 — dark rolling smoke cloud
	var smoke := Polygon2D.new()
	var smoke_pts: Array = []
	for i in 12:
		var a := i * TAU / 12.0
		var r := 55.0 * (0.7 + randf() * 0.6)
		smoke_pts.append(Vector2(cos(a) * r, sin(a) * r))
	smoke.polygon = PackedVector2Array(smoke_pts)
	smoke.color = Color(0.18, 0.14, 0.12, 0.75)
	smoke.global_position = pos; smoke.z_index = 6
	_add_to_level(smoke)
	var smoke_tw: Tween = smoke.create_tween().set_parallel(true)
	smoke_tw.set_ease(Tween.EASE_OUT)
	smoke_tw.tween_property(smoke, "scale", Vector2(2.2, 2.2), 0.6)
	smoke_tw.tween_property(smoke, "position:y", pos.y - 30, 0.6)
	smoke_tw.tween_property(smoke, "modulate:a", 0.0, 0.6).set_delay(0.1)
	smoke_tw.finished.connect(smoke.queue_free)

	# Debris triangles fly outward with gravity
	for _di in 7:
		var deg := Polygon2D.new()
		deg.polygon = PackedVector2Array([Vector2(-4, -6), Vector2(4, -6), Vector2(0, 6)])
		deg.color = Color(0.25, 0.18, 0.1)
		deg.global_position = pos; deg.z_index = 9
		_add_to_level(deg)
		var vel_x := randf_range(-180.0, 180.0)
		var vel_y := randf_range(-280.0, -80.0)
		var d_tw: Tween = create_tween()
		d_tw.tween_property(deg, "position", deg.position + Vector2(vel_x * 0.5, 120.0), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		d_tw.parallel().tween_property(deg, "rotation", randf_range(-PI * 3, PI * 3), 0.6)
		d_tw.parallel().tween_property(deg, "modulate:a", 0.0, 0.6).set_delay(0.3)
		d_tw.finished.connect(deg.queue_free)

	# Screen flash
	if is_instance_valid(_flash_rect):
		_flash_rect.modulate.a = 0.4
		var f_tw: Tween = create_tween()
		f_tw.tween_property(_flash_rect, "modulate:a", 0.0, 0.15)

	_create_crater(pos)

	if is_instance_valid(player) and player.global_position.distance_to(pos) < 110.0:
		player.take_damage(1)

func _create_crater(pos: Vector2) -> void:
	var floor_y := _get_ground_y(pos.x)
	# Scorched earth ring
	var scorch := Polygon2D.new()
	var scorch_pts: Array = []
	var radius := randf_range(32.0, 52.0)
	for i in 14:
		var a := i * TAU / 14.0
		var r := (radius + 8.0) * (0.8 + randf() * 0.4)
		scorch_pts.append(Vector2(cos(a) * r, sin(a) * r * 0.35))
	scorch.polygon = PackedVector2Array(scorch_pts)
	scorch.color = Color(0.3, 0.1, 0.0, 0.6)
	scorch.position = Vector2(pos.x, floor_y)
	_add_to_level(scorch)
	# Pit (dark inner)
	var crater := Polygon2D.new()
	var crater_pts: Array = []
	for i in 12:
		var a := i * TAU / 12.0
		var r := radius * (0.8 + randf() * 0.4)
		crater_pts.append(Vector2(cos(a) * r, sin(a) * r * 0.4))
	crater.polygon = PackedVector2Array(crater_pts)
	crater.color = Color(0.08, 0.04, 0.0, 0.85)
	crater.position = Vector2(pos.x, floor_y)
	_add_to_level(crater)
	# Rising smoke puffs — 8-sided circles
	for i in 8:
		var puff := Polygon2D.new()
		var puff_pts: Array = []
		var pr := randf_range(10.0, 20.0)
		for pi in 8:
			var pa := pi * TAU / 8.0
			puff_pts.append(Vector2(cos(pa) * pr, sin(pa) * pr))
		puff.polygon = PackedVector2Array(puff_pts)
		puff.color = Color(0.5, 0.45, 0.4, 0.55)
		puff.position = pos + Vector2(randf_range(-28.0, 28.0), randf_range(-10.0, 5.0))
		puff.z_index = 5
		_add_to_level(puff)
		var ptw: Tween = create_tween()
		ptw.tween_property(puff, "position:y", puff.position.y - randf_range(50.0, 90.0), 1.4)
		ptw.parallel().tween_property(puff, "scale", Vector2(1.8, 1.8), 1.4)
		ptw.parallel().tween_property(puff, "modulate:a", 0.0, 1.4)
		ptw.finished.connect(puff.queue_free)

# ── Hit sparks on bullet impact ─────────────────────────────────────────────
func create_hit_sparks(hit_pos: Vector2, normal: Vector2) -> void:
	for i in 5:
		var spark_angle := normal.angle() + randf_range(-0.8, 0.8)
		var spd := randf_range(80.0, 200.0)
		var spark := Line2D.new()
		var dir := Vector2(cos(spark_angle), sin(spark_angle))
		spark.add_point(Vector2.ZERO)
		spark.add_point(dir * randf_range(6.0, 14.0))
		spark.default_color = Color(1.0, 0.9, 0.3, 1.0)
		spark.width = 1.5
		spark.global_position = hit_pos; spark.z_index = 6
		_add_to_level(spark)
		var stw: Tween = create_tween()
		stw.tween_property(spark, "position", spark.position + dir * spd * 0.15, 0.15)
		stw.parallel().tween_property(spark, "modulate:a", 0.0, 0.18)
		stw.finished.connect(spark.queue_free)
	# Small flash
	var flash := ColorRect.new()
	flash.size = Vector2(6, 6)
	flash.color = Color(1.0, 1.0, 0.6, 0.8)
	flash.global_position = hit_pos - Vector2(3, 3); flash.z_index = 7
	_add_to_level(flash)
	var ftw: Tween = create_tween()
	ftw.tween_property(flash, "modulate:a", 0.0, 0.1)
	ftw.finished.connect(flash.queue_free)

# ── Landing dust (called by player) ─────────────────────────────────────────
func spawn_landing_dust(lpos: Vector2) -> void:
	for i in 6:
		var d := ColorRect.new()
		d.size = Vector2(5, 5)
		d.color = Color(0.75, 0.65, 0.5, 0.7)
		var off_x := randf_range(-30.0, 30.0)
		d.position = lpos + Vector2(off_x, 0.0)
		d.z_index = 4
		_add_to_level(d)
		var dtw: Tween = create_tween()
		dtw.tween_property(d, "position:y", d.position.y - randf_range(15.0, 35.0), 0.4)
		dtw.parallel().tween_property(d, "position:x", d.position.x + off_x * 0.5, 0.4)
		dtw.parallel().tween_property(d, "modulate:a", 0.0, 0.45)
		dtw.finished.connect(d.queue_free)

func _spawn_bomber() -> void:
	var b = BOMBER_SCENE.instantiate()
	# Spawn ahead of camera
	var spawn_x = camera.position.x + 800
	var spawn_y = randf_range(50, 150)
	b.position = Vector2(spawn_x, spawn_y)
	b.direction = -1
	# Ensure they are added to world so they scroll correctly
	_add_to_level(b)
	# Thunder flash (stage 3 highlands)
	if current_stage == 3 and is_instance_valid(_flash_rect):
		var th_tw: Tween = create_tween()
		th_tw.tween_property(_flash_rect, "modulate:a", 0.25, 0.05)
		th_tw.tween_property(_flash_rect, "modulate:a", 0.0, 0.12)
		th_tw.tween_interval(0.08)
		th_tw.tween_property(_flash_rect, "modulate:a", 0.15, 0.03)
		th_tw.tween_property(_flash_rect, "modulate:a", 0.0, 0.1)

func spawn_shell(pos: Vector2, dir: float) -> void:
	# Polygon2D 6-point brass cylinder casing
	var shell := Polygon2D.new()
	shell.polygon = PackedVector2Array([
		Vector2(-1.5, -3.5), Vector2(1.5, -3.5),
		Vector2(2.0, -1.0), Vector2(2.0, 3.0),
		Vector2(-2.0, 3.0), Vector2(-2.0, -1.0)
	])
	shell.color = Color(0.85, 0.68, 0.18)
	shell.global_position = pos; shell.z_index = 3
	_add_to_level(shell)
	var jump_x := randf_range(8.0, 25.0) * -dir
	var jump_y := -randf_range(15.0, 30.0)
	var ground_y := pos.y + randf_range(20.0, 40.0)
	var stw: Tween = create_tween()
	stw.tween_property(shell, "position", pos + Vector2(jump_x, jump_y), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	stw.parallel().tween_property(shell, "rotation", randf_range(-PI, PI), 0.15)
	stw.tween_property(shell, "position:y", ground_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	stw.tween_property(shell, "modulate:a", 0.0, 1.0)
	stw.finished.connect(shell.queue_free)

func _setup_background_sky(sky_color: Color = Color(0.1, 0.3, 0.6)) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# ── Multi-stop sky gradient (zenith → horizon) ─────────────────────────────
	# Each strip is a thin ColorRect; together they form a smooth gradient banding.
	var zenith  := sky_color.darkened(0.35)
	var midsky  := sky_color
	var haze    := Color(sky_color.r * 1.35 + 0.08, sky_color.g * 1.15 + 0.05, sky_color.b * 0.78 + 0.04)
	var horizon := Color(haze.r + 0.18, haze.g + 0.12, haze.b * 0.55)  # warm orange band
	var ground_haze := Color(horizon.r * 0.8, horizon.g * 0.75, horizon.b * 0.45, 0.60)

	var grad_stops: Array = [zenith, zenith, midsky, midsky, haze, horizon, ground_haze]
	var strip_h := 100.0
	for gi in grad_stops.size():
		var band := ColorRect.new()
		band.name    = "BackgroundSkyStrip_" + str(gi)
		band.size    = Vector2(40000, strip_h + 4)   # +4 to avoid 1px gaps
		band.position = Vector2(-10000, -200.0 + gi * strip_h)
		band.z_index  = -120
		band.color    = grad_stops[gi]
		_add_to_level(band)

	# ── Sun disk + 3 concentric glow rings ────────────────────────────────────
	var sun_x := 3800.0
	var sun_y := 80.0
	var sun_data: Array = [
		[110.0, Color(1.00, 0.96, 0.72, 0.08)],
		[70.0,  Color(1.00, 0.95, 0.60, 0.16)],
		[40.0,  Color(1.00, 0.97, 0.80, 0.50)],
		[24.0,  Color(1.00, 1.00, 0.92, 0.95)],
	]
	for sd: Array in sun_data:
		var sr: float = sd[0]
		var sc: Color = sd[1]
		var sun_poly := Polygon2D.new()
		var sun_pts: Array = []
		for si in 24:
			var sa := si * TAU / 24.0
			sun_pts.append(Vector2(sun_x + cos(sa) * sr * 1.25, sun_y + sin(sa) * sr * 0.7))
		sun_poly.polygon = PackedVector2Array(sun_pts)
		sun_poly.color   = sc
		sun_poly.z_index = -117
		_add_to_level(sun_poly)

	# ── God rays / light shafts from sun ──────────────────────────────────────
	for ri in 7:
		var ray_a := -PI * 0.5 + (ri - 3) * 0.18
		var ray_len := rng.randf_range(380.0, 600.0)
		var ray_w   := rng.randf_range(25.0, 55.0)
		var ray := Polygon2D.new()
		var rbase_l := Vector2(sun_x - ray_w * 0.3, sun_y)
		var rbase_r := Vector2(sun_x + ray_w * 0.3, sun_y)
		var rtip    := Vector2(sun_x + cos(ray_a) * ray_len, sun_y + sin(ray_a) * ray_len)
		ray.polygon  = PackedVector2Array([rbase_l, rbase_r, rtip])
		ray.color    = Color(1.0, 0.92, 0.60, 0.035)
		ray.z_index  = -116
		_add_to_level(ray)

	# ── Clouds — each cloud is 4–6 overlapping ellipse polygons ──────────────
	var cloud_data: Array = []
	for ci in 18:
		var cx: float = rng.randf_range(-800.0, 13000.0)
		var cy: float = rng.randf_range(40.0, 320.0)
		var cs: float = rng.randf_range(0.7, 1.5)
		cloud_data.append([cx, cy, cs])

	for cd: Array in cloud_data:
		var cx: float = cd[0]
		var cy: float = cd[1]
		var cs: float = cd[2]
		var cloud_root := Node2D.new()
		cloud_root.position = Vector2(cx, cy)
		cloud_root.z_index  = -112
		_parallax_bg.add_child(cloud_root)

		# Each cloud: shadow mass first, then lit blobs
		var blob_offsets: Array = [
			[0.0,  0.0,  cs * 55.0, cs * 30.0],
			[-cs*50, cs*10, cs*42.0, cs*24.0],
			[cs*48,  cs*8,  cs*44.0, cs*26.0],
			[-cs*22, -cs*18, cs*36.0, cs*22.0],
			[cs*22,  -cs*14, cs*38.0, cs*20.0],
		]
		# Shadow blob
		for bo: Array in blob_offsets:
			var bx: float = bo[0]
			var by: float = bo[1]
			var brx: float = bo[2]
			var bry: float = bo[3]
			var shadow_b := Polygon2D.new()
			var s_pts: Array = []
			for bi2 in 16:
				var ba := bi2 * TAU / 16.0
				s_pts.append(Vector2(bx + cos(ba) * brx + 6, by + sin(ba) * bry * 0.6 + 8))
			shadow_b.polygon = PackedVector2Array(s_pts)
			shadow_b.color   = Color(0.55, 0.62, 0.70, 0.18)
			cloud_root.add_child(shadow_b)
		# Lit blobs
		for bo: Array in blob_offsets:
			var bx: float = bo[0]
			var by: float = bo[1]
			var brx: float = bo[2]
			var bry: float = bo[3]
			var blob := Polygon2D.new()
			var b_pts: Array = []
			for bi2 in 20:
				var ba := bi2 * TAU / 20.0
				b_pts.append(Vector2(bx + cos(ba) * brx, by + sin(ba) * bry * 0.62))
			blob.polygon = PackedVector2Array(b_pts)
			blob.color   = Color(0.96, 0.97, 0.99, 0.82)
			cloud_root.add_child(blob)
		# Top highlight
		var highlight := Polygon2D.new()
		var h_pts: Array = []
		for hi3 in 14:
			var ha := hi3 * TAU / 14.0
			h_pts.append(Vector2(cos(ha) * cs * 45.0, sin(ha) * cs * 14.0 - cs * 14.0))
		highlight.polygon = PackedVector2Array(h_pts)
		highlight.color   = Color(1.0, 1.0, 1.0, 0.55)
		cloud_root.add_child(highlight)

	# ── 4-layer mountain ranges ────────────────────────────────────────────────
	# Colors: very far = blue-grey haze → near = rich dark green treeline
	var mt_layers: Array = [
		[Color(0.46, 0.56, 0.58, 0.45), 660.0, 0.50, -115, 8],   # ultra distant, blue haze
		[Color(0.18, 0.30, 0.22, 0.70), 675.0, 0.68, -113, 10],  # mid-far, grey-green
		[Color(0.10, 0.22, 0.10, 0.88), 688.0, 0.84, -111, 12],  # mid-near, dark green
		[Color(0.07, 0.16, 0.06, 1.00), 702.0, 1.00, -109, 14],  # nearest, deep forest
	]

	for layer_idx in mt_layers.size():
		var ld: Array = mt_layers[layer_idx]
		var base_col: Color = ld[0]
		var y_base: float   = ld[1]
		var scale_h: float  = ld[2]
		var zidx: int       = ld[3]
		var count: int      = ld[4]

		for i in count:
			# Use a ridgeline polygon (multiple points) instead of a plain triangle
			var mx := float(i) * rng.randf_range(880.0, 1260.0) - 1400.0
			var mw := rng.randf_range(360.0, 620.0) * (0.75 + layer_idx * 0.18)
			var mh := rng.randf_range(190.0, 440.0) * scale_h

			# Build a jagged ridgeline with 5-7 control points
			var n_pts := rng.randi_range(4, 7)
			var ridge: Array = []
			ridge.append(Vector2(-mw * 0.52, 0.0))
			for rpi in n_pts:
				var rx := -mw * 0.42 + float(rpi + 1) * mw * 0.84 / float(n_pts + 1)
				var ry := -mh * rng.randf_range(0.55, 1.0)
				ridge.append(Vector2(rx, ry))
			ridge.append(Vector2(mw * 0.52, 0.0))

			var mt_root := Node2D.new()
			mt_root.position = Vector2(mx, y_base)
			mt_root.z_index  = zidx
			_parallax_bg.add_child(mt_root)

			# Main mountain fill
			var fill_pts: Array = ridge.duplicate()
			fill_pts.append(Vector2(mw * 0.52, 60.0))
			fill_pts.append(Vector2(-mw * 0.52, 60.0))
			var mt_fill := Polygon2D.new()
			mt_fill.polygon = PackedVector2Array(fill_pts)
			mt_fill.color   = base_col
			mt_root.add_child(mt_fill)

			# Left-lit face overlay (lighter left/top slope)
			if ridge.size() >= 3:
				var peak_v: Vector2 = ridge[int(ridge.size() / 2)]
				var light_pts := PackedVector2Array([ridge[0], peak_v, Vector2(peak_v.x * 0.3, 0.0)])
				var lit := Polygon2D.new()
				lit.polygon = light_pts
				lit.color   = Color(1.0, 1.0, 1.0, 0.06 + 0.04 * scale_h)
				mt_root.add_child(lit)

				# Right shadow face
				var dark_pts := PackedVector2Array([Vector2(peak_v.x * 0.3, 0.0), peak_v, ridge[ridge.size() - 1]])
				var dark := Polygon2D.new()
				dark.polygon = dark_pts
				dark.color   = Color(0.0, 0.0, 0.0, 0.18 + 0.10 * scale_h)
				mt_root.add_child(dark)

			# Atmospheric haze overlay for far layers
			if layer_idx <= 1:
				var haze_ov := Polygon2D.new()
				haze_ov.polygon = PackedVector2Array(fill_pts)
				haze_ov.color   = Color(sky_color.r * 0.5 + 0.3, sky_color.g * 0.4 + 0.25, sky_color.b * 0.5 + 0.25, 0.22)
				mt_root.add_child(haze_ov)

			# Dark-green treeline silhouette on top of each mountain ridge
			for ti in range(0, ridge.size() - 1):
				var tp1: Vector2 = ridge[ti]
				var tp2: Vector2 = ridge[ti + 1]
				var t_count := int((tp2.x - tp1.x) / rng.randf_range(28, 50))
				for tj in t_count:
					var tt := float(tj) / float(max(t_count, 1))
					var tx: float = lerp(tp1.x, tp2.x, tt)
					var ty_base: float = lerp(tp1.y, tp2.y, tt)
					var th_tree := rng.randf_range(12.0, 32.0) * scale_h
					var tw_tree := rng.randf_range(8.0,  20.0) * scale_h
					var tree_sil := Polygon2D.new()
					var t_pts: Array = []
					for ti2 in 8:
						var ta := ti2 * TAU / 8.0
						t_pts.append(Vector2(tx + cos(ta) * tw_tree, ty_base + sin(ta) * th_tree - th_tree))
					tree_sil.polygon = PackedVector2Array(t_pts)
					tree_sil.color   = Color(base_col.r * 0.55, base_col.g * 0.80, base_col.b * 0.50, 0.90)
					mt_root.add_child(tree_sil)

	# ── Ground-level mist / valley fog strips ─────────────────────────────────
	for i in 8:
		var mist := ColorRect.new()
		mist.size     = Vector2(rng.randf_range(2400.0, 4000.0), rng.randf_range(28.0, 60.0))
		mist.position = Vector2(rng.randf_range(-600.0, 10000.0), 500.0 + i * 14.0)
		mist.color    = Color(0.85, 0.90, 0.88, 0.09 - i * 0.007)
		mist.z_index  = -50
		_parallax_bg.add_child(mist)

	# ── Ambient ground shadow (darkens the very bottom of the sky near terrain) ─
	for di in 3:
		var amb := ColorRect.new()
		amb.size     = Vector2(40000, 55)
		amb.position = Vector2(-10000, 590.0 + di * 38.0)
		amb.z_index  = -10
		amb.color    = Color(0.0, 0.0, 0.0, 0.10 + di * 0.04)
		_add_to_level(amb)

func _start_stage(stage_num: int, is_respawn: bool = false) -> void:
	current_stage = stage_num
	STAGE_LENGTH = 12000.0 # Reset to default
	if not is_respawn: last_checkpoint_x = 100.0
	if progress_bar: progress_bar.max_value = STAGE_LENGTH
	is_game_over = false # FIX: must be false before cleanup so _process works from frame 1
	_cleanup_level()
	# FIX: call_deferred to ensure old physic objects are gone before new ones are added
	call_deferred("_load_stage_data", stage_num)
	call_deferred("_spawn_player_at_start")

func _spawn_player_at_start() -> void:
	_spawn_player()
	# FIX: spawn army AFTER _spawn_player so camera is correctly positioned
	for idx_army in 6:
		var sx_army = camera.position.x + 100 + idx_army * 140
		_add_individual_background_soldier(sx_army, _get_ground_y(sx_army))
	
	_show_stage_intro(current_stage)
	_show_stage_history_on_start()

func _spawn_player() -> void:
	if is_instance_valid(player): player.queue_free()
	player = PLAYER_SCENE.instantiate()
	_level_node.add_child(player)
	
	# FIX: spawn at minimum x=576 (= half screen) so player is never behind camera left edge
	var spawn_x_pos = max(last_checkpoint_x, 576.0)
	player.position = Vector2(spawn_x_pos, 500)
	# Snap to ground
	player.position.y = _get_ground_y(player.position.x) - 40
	# Sync camera immediately
	camera.position.x = player.position.x
	camera.position.y = 360.0

func _show_stage_intro(num: int) -> void:
	if stage_label:
		var titles = ["RỪNG GIÀ TÂY NGUYÊN", "ĐỊA ĐẠO CỦ CHI", "ĐƯỜNG MÒN HỒ CHÍ MINH", "CĂN CỨ ĐỊCH", "TIẾN VỀ SÀI GÒN"]
		stage_label.text = "CHIẾN DỊCH %d: %s" % [num, titles[num-1] if num <= titles.size() else "TIẾP TỤC"]
		stage_label.modulate.a = 1.0
		var tw = create_tween()
		tw.tween_interval(3.0)
		tw.tween_property(stage_label, "modulate:a", 0.0, 1.0)

func _show_stage_history_on_start() -> void:
	if _history_panel == null: return
	_showing_stage_history = true
	_show_history_info()
	get_tree().paused = true

func _cleanup_level() -> void:
	# Aggressively clear EVERYTHING in world and parallax to prevent leaks between stages
	if is_instance_valid(_parallax_bg):
		_parallax_bg.queue_free()
	
	if is_instance_valid(_level_node):
		_level_node.name = "DELETING"
		_level_node.queue_free()

	# Clear any direct children (leaked bamboo, mountains, etc.)
	if is_instance_valid(_world):
		for n in _world.get_children():
			if n != _level_node and n != _parallax_bg:
				n.queue_free()
	
	# Re-setup the clean containers
	_parallax_bg = Node2D.new(); _parallax_bg.name = "Parallax"; _world.add_child(_parallax_bg)
	_level_node = Node2D.new(); _level_node.name = "LevelNode"; _world.add_child(_level_node)
	
	_stage_terrain.clear()
	# Reset all timers
	_bomber_timer = 5.0
	_enemy_spawn_timer = 2.0
	_army_spawn_timer = 1.0
	_allied_tank_timer = 5.0
	_checkpoint_positions.clear()
	# Remove old checkpoint markers
	if progress_bar:
		for c in progress_bar.get_children(): c.queue_free()
	_rpg_cooldown_timer = 0.0
	kill_count = 0
	var kl = get_node_or_null("UI/HUDPanel/KillLabel")
	if kl: kl.text = "⚔ 0 tiêu diệt"
	var sl = get_node_or_null("UI/HUDPanel/ScoreLabel")
	if sl: sl.text = "0"

func _load_stage_data(num: int) -> void:
	if STAGE_SCRIPTS.has(num):
		var stage_script = STAGE_SCRIPTS[num]
		var stage_instance = stage_script.new(self)
		stage_instance.setup()
		_update_checkpoint_ui()
	else:
		# Fallback to Stage 1 script
		var stage_script = STAGE_SCRIPTS[1]
		var stage_instance = stage_script.new(self)
		stage_instance.setup()

# Stage setups moved to separate scripts in res://scripts/stages/

func _create_giant_ancient_tree(pos: Vector2) -> void:
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = int(pos.x * 7.0 + pos.y * 13.0)

	var tree_scale := rng_t.randf_range(0.82, 1.22)
	var tilt       := rng_t.randf_range(-0.07, 0.07)

	var tree := Node2D.new()
	tree.position = pos
	tree.scale    = Vector2(tree_scale, tree_scale)
	tree.rotation = tilt
	tree.z_index  = -50
	_add_to_level(tree)

	var tw := rng_t.randf_range(48.0, 76.0)
	var trunk_h := 300.0

	# ── Ground AO / contact shadow ────────────────────────────────────────────
	var ao := Polygon2D.new()
	var ao_pts: Array = []
	for ai in 12:
		var aa := ai * TAU / 12.0
		ao_pts.append(Vector2(cos(aa) * tw * 1.8, sin(aa) * tw * 0.5 + 6))
	ao.polygon = PackedVector2Array(ao_pts)
	ao.color   = Color(0.0, 0.0, 0.0, 0.30)
	tree.add_child(ao)

	# ── Buttress roots (3-5 angled fins radiating from base) ─────────────────
	var n_roots := rng_t.randi_range(3, 5)
	for ri in n_roots:
		var ra := (float(ri) / float(n_roots)) * PI + rng_t.randf_range(-0.18, 0.18)
		var rlen := rng_t.randf_range(tw * 0.9, tw * 1.6)
		var root_poly := Polygon2D.new()
		root_poly.polygon = PackedVector2Array([
			Vector2(0.0, -30.0),
			Vector2(cos(ra) * rlen, sin(ra) * rlen * 0.45),
			Vector2(cos(ra) * rlen * 0.85 + cos(ra + 0.4) * 10, sin(ra) * rlen * 0.45 + 8),
		])
		root_poly.color = Color(0.17, 0.10, 0.05)
		tree.add_child(root_poly)

	# ── Trunk ─────────────────────────────────────────────────────────────────
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array([
		Vector2(-tw * 1.22,  0),
		Vector2(-tw * 0.90, -trunk_h * 0.28),
		Vector2(-tw * 0.52, -trunk_h * 0.68),
		Vector2(-tw * 0.40, -trunk_h),
		Vector2( tw * 0.38, -trunk_h),
		Vector2( tw * 0.50, -trunk_h * 0.68),
		Vector2( tw * 0.88, -trunk_h * 0.28),
		Vector2( tw * 1.22,  0),
	])
	trunk.color = Color(0.22, 0.14, 0.07)
	tree.add_child(trunk)

	# Bark highlight (left edge catches light)
	var bark_hi := Polygon2D.new()
	bark_hi.polygon = PackedVector2Array([
		Vector2(-tw * 1.18, 0),
		Vector2(-tw * 0.86, -trunk_h * 0.28),
		Vector2(-tw * 0.50, -trunk_h * 0.62),
		Vector2(-tw * 0.28, -trunk_h * 0.62),
		Vector2(-tw * 0.44, -trunk_h * 0.28),
		Vector2(-tw * 0.80, 0),
	])
	bark_hi.color = Color(0.38, 0.25, 0.12, 0.42)
	tree.add_child(bark_hi)

	# Bark shadow stripe (right side)
	var bark_sh := Polygon2D.new()
	bark_sh.polygon = PackedVector2Array([
		Vector2(tw * 0.50, -trunk_h * 0.68),
		Vector2(tw * 0.88, -trunk_h * 0.28),
		Vector2(tw * 1.22,  0),
		Vector2(tw * 0.85,  0),
	])
	bark_sh.color = Color(0.0, 0.0, 0.0, 0.28)
	tree.add_child(bark_sh)

	# Bark vertical fissure lines
	for fi in 3:
		var fx := rng_t.randf_range(-tw * 0.6, tw * 0.6)
		var fissure := ColorRect.new()
		fissure.size     = Vector2(3, rng_t.randf_range(80.0, 180.0))
		fissure.position = Vector2(fx, -trunk_h * 0.8)
		fissure.color    = Color(0.10, 0.06, 0.02, 0.55)
		fissure.rotation = rng_t.randf_range(-0.06, 0.06)
		tree.add_child(fissure)

	# ── Wrapping vines ─────────────────────────────────────────────────────────
	for v in 5:
		var vy   := float(v) * -58.0
		var voff := sin(v * 1.3) * tw * 0.2
		var vine := Polygon2D.new()
		vine.polygon = PackedVector2Array([
			Vector2(-tw * 0.80 + voff,  vy),
			Vector2( tw * 0.76 + voff,  vy - 16.0),
			Vector2( tw * 0.76 + voff,  vy -  7.0),
			Vector2(-tw * 0.80 + voff,  vy +  9.0),
		])
		vine.color = Color(0.07, 0.24, 0.03, 0.80)
		tree.add_child(vine)

	# ── Canopy — 4 height levels, each with 3–5 overlapping rounded blobs ────
	# Each blob is a ~16-point polygon approximating an ellipse.
	var canopy_colors: Array = [
		Color(0.06, 0.22, 0.04),   # deep layer — very dark
		Color(0.08, 0.30, 0.05),
		Color(0.10, 0.38, 0.06),
		Color(0.14, 0.45, 0.07),   # top layer — brightest
	]
	for layer in 4:
		var layer_y := -trunk_h - float(layer) * 82.0
		var spread  := tw * (2.2 - layer * 0.22)
		var n_blobs := rng_t.randi_range(3, 5)

		# Large ambient shadow under this canopy level
		var can_shadow := Polygon2D.new()
		var csh_pts: Array = []
		for csi in 18:
			var csa := csi * TAU / 18.0
			csh_pts.append(Vector2(cos(csa) * spread * 0.90 + 10, sin(csa) * spread * 0.38 + 22))
		can_shadow.polygon = PackedVector2Array(csh_pts)
		can_shadow.color   = Color(0.0, 0.0, 0.0, 0.22)
		tree.add_child(can_shadow)

		for bi2 in n_blobs:
			var bx := rng_t.randf_range(-spread * 0.55, spread * 0.55)
			var by := rng_t.randf_range(-20.0, 20.0)
			var brx := rng_t.randf_range(spread * 0.42, spread * 0.68)
			var bry := rng_t.randf_range(brx * 0.42, brx * 0.62)

			var blob := Polygon2D.new()
			var b_pts: Array = []
			for bpi in 18:
				var ba := bpi * TAU / 18.0
				# Slightly jitter radius for natural edge
				var jitter := rng_t.randf_range(0.88, 1.12)
				b_pts.append(Vector2(bx + cos(ba) * brx * jitter, layer_y + by + sin(ba) * bry * jitter))
			blob.polygon = PackedVector2Array(b_pts)
			blob.color   = canopy_colors[layer].lightened(rng_t.randf() * 0.18)
			tree.add_child(blob)

		# Dappled highlight cluster at top of canvas (simulates sun catching leaves)
		if layer == 3:
			for hi4 in rng_t.randi_range(4, 7):
				var hx := rng_t.randf_range(-spread * 0.4, spread * 0.4)
				var hl := Polygon2D.new()
				var h_pts: Array = []
				var hr := rng_t.randf_range(12.0, 28.0)
				for hpi in 10:
					var ha := hpi * TAU / 10.0
					h_pts.append(Vector2(hx + cos(ha) * hr, layer_y - 15.0 + sin(ha) * hr * 0.5))
				hl.polygon = PackedVector2Array(h_pts)
				hl.color   = Color(0.55, 0.85, 0.22, 0.28)
				tree.add_child(hl)

	# ── Hanging lianas / moss strands ─────────────────────────────────────────
	for li in rng_t.randi_range(3, 6):
		var lx   := rng_t.randf_range(-tw * 1.2, tw * 1.2)
		var llen := rng_t.randf_range(60.0, 160.0)
		var lsway := sin(lx * 0.1) * 14.0
		var liana := Polygon2D.new()
		liana.polygon = PackedVector2Array([
			Vector2(lx - 2.5, -trunk_h * 0.85),
			Vector2(lx + lsway - 2.5, -trunk_h * 0.85 + llen),
			Vector2(lx + lsway + 2.5, -trunk_h * 0.85 + llen),
			Vector2(lx + 2.5, -trunk_h * 0.85),
		])
		liana.color = Color(0.10, 0.28, 0.05, 0.75)
		tree.add_child(liana)

func _create_jungle_fern(pos: Vector2) -> void:
	var fern  := Node2D.new()
	fern.position = pos
	_add_to_level(fern)
	fern.z_index = -5

	# Base ambient shadow
	var fs := Polygon2D.new()
	var fs_pts: Array = []
	for fsi in 10:
		var fsa := fsi * TAU / 10.0
		fs_pts.append(Vector2(cos(fsa) * 22.0, sin(fsa) * 7.0 + 4))
	fs.polygon = PackedVector2Array(fs_pts)
	fs.color   = Color(0.0, 0.0, 0.0, 0.22)
	fern.add_child(fs)

	# Pinnate fronds — each frond has a midrib + paired leaflets
	for i in 7:
		var frond_a := -PI * 0.9 - float(i) * PI / 5.5 + randf_range(-0.12, 0.12)
		var flen    := randf_range(28.0, 52.0)
		var frond_col := Color(0.06, 0.32 + randf() * 0.14, 0.04)
		# Midrib
		var midrib := Polygon2D.new()
		var tip    := Vector2(cos(frond_a) * flen, sin(frond_a) * flen)
		midrib.polygon = PackedVector2Array([
			Vector2(-1.5, 0.0), tip + Vector2(-1.0, 0.0),
			tip + Vector2(1.0, 0.0), Vector2(1.5, 0.0)
		])
		midrib.color = frond_col.darkened(0.20)
		fern.add_child(midrib)
		# Leaflets along midrib
		var n_leaflet := int(flen / 8.0)
		for leti in n_leaflet:
			var lt := float(leti + 1) / float(n_leaflet + 1)
			var lbase := Vector2(cos(frond_a) * flen * lt, sin(frond_a) * flen * lt)
			for side in [-1, 1]:
				var leaflet := Polygon2D.new()
				var ls := randf_range(5.0, 12.0) * (1.0 - lt * 0.5)
				var la: float = frond_a + float(side) * PI * 0.45
				leaflet.polygon = PackedVector2Array([
					lbase,
					lbase + Vector2(cos(la) * ls, sin(la) * ls),
					lbase + Vector2(cos(la + 0.5) * ls * 0.6, sin(la + 0.5) * ls * 0.6),
				])
				leaflet.color = frond_col.lightened(randf() * 0.20)
				fern.add_child(leaflet)

func _create_dense_shrub(pos: Vector2) -> void:
	var shrub := Node2D.new()
	shrub.position = pos
	_add_to_level(shrub)
	shrub.z_index = -5

	# Ground shadow
	var ss := Polygon2D.new()
	var ss_pts: Array = []
	for ssi in 10:
		var ssa := ssi * TAU / 10.0
		ss_pts.append(Vector2(cos(ssa) * 28.0, sin(ssa) * 9.0 + 6))
	ss.polygon = PackedVector2Array(ss_pts)
	ss.color   = Color(0.0, 0.0, 0.0, 0.20)
	shrub.add_child(ss)

	# Multi-blob shrub crown: 3 rounded polygon blobs
	var blob_data: Array = [
		[Vector2(-14.0,  -8.0), 20.0, 12.0, Color(0.05, 0.25, 0.03)],
		[Vector2( 12.0, -10.0), 22.0, 14.0, Color(0.06, 0.28, 0.04)],
		[Vector2(  2.0, -22.0), 24.0, 15.0, Color(0.07, 0.32, 0.04)],
	]
	for bd: Array in blob_data:
		var bcenter: Vector2 = bd[0]
		var brx: float       = bd[1]
		var bry: float       = bd[2]
		var bcol: Color      = bd[3]

		# Shadow behind
		var bshadow := Polygon2D.new()
		var bsh_pts: Array = []
		for bsi in 14:
			var bsa := bsi * TAU / 14.0
			bsh_pts.append(Vector2(bcenter.x + cos(bsa) * brx + 5, bcenter.y + sin(bsa) * bry + 5))
		bshadow.polygon = PackedVector2Array(bsh_pts)
		bshadow.color   = Color(0.0, 0.0, 0.0, 0.20)
		shrub.add_child(bshadow)

		var blob := Polygon2D.new()
		var b_pts: Array = []
		for bpi3 in 14:
			var ba3 := bpi3 * TAU / 14.0
			var jitter := randf_range(0.87, 1.13)
			b_pts.append(Vector2(bcenter.x + cos(ba3) * brx * jitter, bcenter.y + sin(ba3) * bry * jitter))
		blob.polygon = PackedVector2Array(b_pts)
		blob.color   = bcol.lightened(randf() * 0.22)
		shrub.add_child(blob)

	# Top specular dapple
	var dapple := Polygon2D.new()
	var d_pts: Array = []
	for di2 in 10:
		var da := di2 * TAU / 10.0
		d_pts.append(Vector2(cos(da) * 10.0, sin(da) * 6.0 - 22.0))
	dapple.polygon = PackedVector2Array(d_pts)
	dapple.color   = Color(0.45, 0.80, 0.18, 0.25)
	shrub.add_child(dapple)

func _create_hanging_vine_detailed(x: float) -> void:
	var v_len = randf_range(300, 500)
	var vine = Line2D.new(); _add_to_level(vine)
	vine.width = 2.0; vine.default_color = Color(0.1, 0.3, 0.05)
	var pts = []
	for i in 10: pts.append(Vector2(x + sin(i)*10, i * v_len/10 - 100))
	vine.points = PackedVector2Array(pts)
	
	# Add small leaves along the vine
	for i in 6:
		var lp = pts[i+2]
		var leaf = ColorRect.new(); leaf.size = Vector2(6, 4); leaf.position = lp; leaf.color = Color(0.2, 0.5, 0.1); leaf.rotation = randf()
		_add_to_level(leaf); leaf.z_index = -10 # Pushed back behind soldiers


func _create_ground_segment(x1: float, x2: float, y: float) -> void:
	if x2 <= x1: return
	var w: float = x2 - x1

	# Physics body
	var body := StaticBody2D.new()
	var col  := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(w, 400)
	col.shape  = shape
	body.add_child(col)
	body.position = Vector2(x1 + w / 2.0, y + 200)
	_add_to_level(body)

	# ── 1. Deep bedrock fill ──────────────────────────────────────────────────
	var bedrock := ColorRect.new()
	bedrock.size     = Vector2(w, 400)
	bedrock.position = Vector2(-w / 2.0, -200)
	bedrock.color    = Color(0.14, 0.07, 0.03)   # near-black clay
	body.add_child(bedrock)

	# ── 2. Vietnam laterite mid-layer (reddish-orange leached soil) ───────────
	var laterite := ColorRect.new()
	laterite.size     = Vector2(w, 90)
	laterite.position = Vector2(-w / 2.0, -200)
	laterite.color    = Color(0.42, 0.22, 0.09)   # classic laterite red-orange
	body.add_child(laterite)

	# Subtle streak noise in laterite
	var rng_g := RandomNumberGenerator.new()
	rng_g.seed = int(x1 * 3 + y * 7)
	for si in int(w / 60.0):
		var streak := ColorRect.new()
		streak.size     = Vector2(rng_g.randf_range(30.0, 80.0), rng_g.randf_range(4.0, 12.0))
		streak.position = Vector2(-w / 2.0 + float(si) * 60.0 + rng_g.randf_range(0, 40), -200 + rng_g.randf_range(10.0, 70.0))
		streak.color    = Color(0.50, 0.28, 0.11, 0.35)
		body.add_child(streak)

	# ── 3. Dark humus top-soil ────────────────────────────────────────────────
	var humus := ColorRect.new()
	humus.size     = Vector2(w, 22)
	humus.position = Vector2(-w / 2.0, -200)
	humus.color    = Color(0.20, 0.12, 0.05)   # dark moist organic layer
	body.add_child(humus)

	# Exposed roots/debris in humus
	for ri2 in int(w / 120.0):
		var rot_dec := Polygon2D.new()
		var rx2: float = -w / 2.0 + float(ri2) * 120.0 + rng_g.randf_range(10, 90)
		rot_dec.polygon = PackedVector2Array([
			Vector2(rx2,      -200),
			Vector2(rx2 + rng_g.randf_range(18, 45), -200 - rng_g.randf_range(4, 10)),
			Vector2(rx2 + rng_g.randf_range(14, 40), -200),
		])
		rot_dec.color = Color(0.28, 0.14, 0.06, 0.60)
		body.add_child(rot_dec)

	# ── 4. Contact shadow below grass line ────────────────────────────────────
	var con_shadow := ColorRect.new()
	con_shadow.size     = Vector2(w, 6)
	con_shadow.position = Vector2(-w / 2.0, -222)
	con_shadow.color    = Color(0.0, 0.0, 0.0, 0.32)
	body.add_child(con_shadow)

	# ── 5. Grass base band (dark rich green) ──────────────────────────────────
	var grass_base := ColorRect.new()
	grass_base.size     = Vector2(w, 16)
	grass_base.position = Vector2(-w / 2.0, -216)
	grass_base.color    = Color(0.18, 0.40, 0.07)
	body.add_child(grass_base)

	# ── 6. Mid-grass brightness band ──────────────────────────────────────────
	var grass_mid := ColorRect.new()
	grass_mid.size     = Vector2(w, 8)
	grass_mid.position = Vector2(-w / 2.0, -224)
	grass_mid.color    = Color(0.25, 0.52, 0.09)
	body.add_child(grass_mid)

	# ── 7. Grass blades row ────────────────────────────────────────────────────
	var blades_nd := Node2D.new()
	blades_nd.position = Vector2(-w / 2.0, -224)
	body.add_child(blades_nd)
	var n_bl := int(w / 9.0)
	for bii in n_bl:
		var bx2 := float(bii) * 9.0 + rng_g.randf_range(-3.0, 3.0)
		var bh2 := rng_g.randf_range(8.0, 22.0)
		var lean := rng_g.randf_range(-0.18, 0.18)  # natural sway
		var blade := Polygon2D.new()
		blade.polygon = PackedVector2Array([
			Vector2(bx2 - 2.5,          0.0),
			Vector2(bx2 + lean * bh2,  -bh2),
			Vector2(bx2 + 2.5,          0.0),
		])
		# Slight yellowing on some blades for realism
		var yellow := rng_g.randf_range(0.0, 0.12)
		blade.color = Color(0.22 + yellow, 0.52, 0.08).lightened(rng_g.randf() * 0.15)
		blades_nd.add_child(blade)

	# ── 8. Sunlit edge highlight at very top ──────────────────────────────────
	var edge_hl := ColorRect.new()
	edge_hl.size     = Vector2(w, 2)
	edge_hl.position = Vector2(-w / 2.0, -232)
	edge_hl.color    = Color(0.60, 0.88, 0.25, 0.45)
	body.add_child(edge_hl)

	# ── 9. Pebble/rock scatter ────────────────────────────────────────────────
	var n_pebbles := int(w / 75.0)
	for pb in n_pebbles:
		var peb := Polygon2D.new()
		var px: float = -w / 2.0 + float(pb) * 75.0 + rng_g.randf_range(0, 55)
		var pr  := rng_g.randf_range(3.0, 7.0)
		var ppts: Array = []
		for pk in 8:
			var pa := pk * TAU / 8.0
			var pr_jit := pr * rng_g.randf_range(0.75, 1.25)
			ppts.append(Vector2(px + cos(pa) * pr_jit, -200 + sin(pa) * pr_jit * 0.55))
		peb.polygon = PackedVector2Array(ppts)
		peb.color   = Color(0.48, 0.30, 0.18, 0.75)
		body.add_child(peb)

	# ── 10. Moss patches on some rocks ───────────────────────────────────────
	if n_pebbles > 2:
		for mi2 in int(n_pebbles / 3):
			var moss := Polygon2D.new()
			var mpx: float = -w / 2.0 + float(mi2) * 220.0 + rng_g.randf_range(0, 140)
			var mr           := rng_g.randf_range(5.0, 9.0)
			var m_pts: Array = []
			for mpi in 8:
				var ma := mpi * TAU / 8.0
				m_pts.append(Vector2(mpx + cos(ma) * mr * 1.6, -200 + sin(ma) * mr * 0.6))
			moss.polygon = PackedVector2Array(m_pts)
			moss.color   = Color(0.18, 0.38, 0.08, 0.55)
			body.add_child(moss)

	# Foreground Pillars
	for i in 12:
		var px: float = i * 650
		var p  := ColorRect.new()
		p.size     = Vector2(40, 800)
		p.position = Vector2(px, -100)
		p.color    = Color(0.05, 0.02, 0.01, 0.85)
		p.z_index  = 10
		_level_node.add_child(p)


func _create_burning_wreckage(pos: Vector2) -> void:
	var wreckage = Node2D.new(); wreckage.position = pos; _add_to_level(wreckage); wreckage.z_index = -5
	var base = ColorRect.new(); base.size = Vector2(40, 15); base.position = Vector2(-20, -15); base.color = Color(0.1, 0.1, 0.1); wreckage.add_child(base)
	
	for i in 3: # Smoke plumes
		var s = ColorRect.new(); s.size = Vector2(10, 10); s.color = Color(0.2, 0.2, 0.2, 0.6); s.position = Vector2(randf_range(-15, 15), -20)
		wreckage.add_child(s)
		var tw = create_tween().set_loops()
		tw.tween_property(s, "position:y", s.position.y - 60, 2.0).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 2.0)
		tw.tween_property(s, "position:y", -20, 0.01); tw.tween_property(s, "modulate:a", 0.6, 0.01)

func _create_aa_gun_bg(pos: Vector2) -> void:
	var aa = Node2D.new(); aa.position = pos; _add_to_level(aa); aa.z_index = -8
	var base = ColorRect.new(); base.size = Vector2(30, 10); base.position = Vector2(-15, -10); base.color = Color(0.15, 0.2, 0.12); aa.add_child(base)
	var gun = ColorRect.new(); gun.size = Vector2(4, 35); gun.position = Vector2(-2, -45); gun.color = Color(0.1, 0.1, 0.1); aa.add_child(gun); gun.rotation = -0.4
	
	# Muzzle flash timer
	var timer = Timer.new(); aa.add_child(timer); timer.wait_time = randf_range(0.8, 2.0); timer.autostart = true; timer.start()
	timer.timeout.connect(func():
		var flash = Polygon2D.new(); flash.polygon = [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -30)]
		flash.color = Color(1, 0.8, 0.4, 0.9); flash.position = Vector2(0, -45).rotated(gun.rotation); aa.add_child(flash)
		var tw = create_tween(); tw.tween_property(flash, "modulate:a", 0.0, 0.15); tw.finished.connect(flash.queue_free)
		# Add a tracer line shooting up
		var tracer = ColorRect.new(); tracer.size = Vector2(2, 600); tracer.color = Color(1, 0.9, 0.2, 0.4); tracer.position = flash.position
		tracer.rotation = gun.rotation; aa.add_child(tracer); var t_tw = create_tween(); t_tw.tween_property(tracer, "position:y", -800, 0.15); t_tw.finished.connect(tracer.queue_free)
	)

func _create_wooden_log_bridge(pos: Vector2) -> void:
	var bridge = Node2D.new(); bridge.position = pos; _add_to_level(bridge); bridge.z_index = -10
	for idx_log in 6:
		var w_log_obj = ColorRect.new(); w_log_obj.size = Vector2(25, 10); w_log_obj.position = Vector2(idx_log*26 - 75, -10)
		w_log_obj.color = Color(0.4, 0.25, 0.15).darkened(randf()*0.2); bridge.add_child(w_log_obj)
		var moss = ColorRect.new(); moss.size = Vector2(25, 3); moss.position = Vector2(idx_log*26 - 75, -12); moss.color = Color(0.2, 0.4, 0.1); bridge.add_child(moss)

func _create_gaz_truck_bg(pos: Vector2) -> void:
	var truck = Node2D.new(); truck.position = pos; _add_to_level(truck); truck.z_index = -15
	truck.modulate = Color(0.6, 0.7, 0.6, 0.8) # Blended into background
	var body = ColorRect.new(); body.size = Vector2(60, 25); body.position = Vector2(-30, -35); body.color = Color(0.15, 0.25, 0.15)
	var cabin = ColorRect.new(); cabin.size = Vector2(25, 18); cabin.position = Vector2(5, -45); cabin.color = Color(0.12, 0.22, 0.12)
	var wheels = [ColorRect.new(), ColorRect.new()]
	wheels[0].size = Vector2(12, 12); wheels[0].position = Vector2(-20, -15); wheels[1].size = Vector2(12, 12); wheels[1].position = Vector2(15, -15)
	truck.add_child(body); truck.add_child(cabin); for w in wheels: w.color = Color.BLACK; truck.add_child(w)

func _create_bicycle_convoy_bg(pos: Vector2) -> void:
	for i in 3:
		var b = Node2D.new(); b.position = pos + Vector2(i*60, 0); _add_to_level(b); b.z_index = -15
		var frame = ColorRect.new(); frame.size = Vector2(25, 2); frame.position = Vector2(-12, -18); frame.color = Color(0.1, 0.1, 0.1); b.add_child(frame)
		var goods = ColorRect.new(); goods.size = Vector2(30, 20); goods.position = Vector2(-15, -35); goods.color = Color(0.4, 0.3, 0.2); b.add_child(goods)
		var wheels = [ColorRect.new(), ColorRect.new()]
		wheels[0].size = Vector2(10, 10); wheels[0].position = Vector2(-12, -10); wheels[1].size = Vector2(10, 10); wheels[1].position = Vector2(5, -10)
		for w in wheels: w.color = Color(0.2, 0.2, 0.2); b.add_child(w)

func _generate_hilly_terrain(soil_color: Color, grass_color: Color, has_gaps: bool = false) -> void:
	_stage_terrain.clear()
	# FIX: start terrain at -700 so camera at min x=576 (screen left=0) always has ground
	var cur_x = -700.0
	var cur_y = 560.0
	var total_len = STAGE_LENGTH + 1000.0
	
	# Flat safe zone: no height change in first 800px past spawn point (x=576+200=776)
	var flat_zone_end = 900.0
	
	while cur_x < total_len:
		var chunk_len = min(2000.0, total_len - cur_x)
		if has_gaps:
			chunk_len = randf_range(800, 1500)
			
		var end_x = cur_x + chunk_len
		if end_x > total_len: end_x = total_len
		
		var surface_pts = PackedVector2Array()
		var cx = cur_x
		surface_pts.append(Vector2(cx, cur_y))
		while cx < end_x:
			var step_x = randf_range(200, 500)
			if cx + step_x >= end_x: step_x = end_x - cx
			
			cx += step_x
			surface_pts.append(Vector2(cx, cur_y))
			
			if cx < end_x:
				var prev_y = cur_y
				var dy_max = 200.0
				if current_stage == 1: dy_max = 110.0 # Lower hills for Map 1
				var dy = randf_range(80, dy_max) * (1 if randf() < 0.5 else -1)
				if current_stage == 2:
					dy = 0
				# FIX: no height change in the startup flat zone
				if cx < flat_zone_end:
					dy = 0
				cur_y = clamp(cur_y + dy, 320.0, 640.0)
				
				# Sloped transition for smoother mountains (Map 3 fix)
				var slope_w = randf_range(150, 300) # Increased for smoother climb
				slope_w = max(slope_w, abs(dy) * 1.8) # Ensure slope is walkable (below 45 degrees)
				if cx + slope_w < end_x and current_stage != 2:
					# Add multiple points for a curved slope
					surface_pts.append(Vector2(cx + slope_w * 0.3, lerp(prev_y, cur_y, 0.2)))
					surface_pts.append(Vector2(cx + slope_w * 0.7, lerp(prev_y, cur_y, 0.8)))
					cx += slope_w
					surface_pts.append(Vector2(cx, cur_y))
				else:
					surface_pts.append(Vector2(cx, cur_y))
				
		var poly_pts = PackedVector2Array()
		for p in surface_pts: poly_pts.append(p)
		
		if has_gaps:
			for i in range(surface_pts.size()-1, -1, -1):
				poly_pts.append(Vector2(surface_pts[i].x, surface_pts[i].y + randf_range(100, 150)))
		else:
			poly_pts.append(Vector2(end_x, 1200)) # Bottom right
			poly_pts.append(Vector2(cur_x, 1200)) # Bottom left
			
		var ground = StaticBody2D.new()
		ground.z_index = -25 # Ensure background units (z=-5) are above the soil
		var coll = CollisionPolygon2D.new()
		coll.polygon = poly_pts
		if has_gaps: coll.one_way_collision = true
		ground.add_child(coll)
		_add_to_level(ground)
		
		# ── Base soil fill (full polygon shape) ───────────────────────────────
		var soil := Polygon2D.new()
		soil.polygon = poly_pts
		soil.color   = soil_color
		ground.add_child(soil)

		# ── Mid soil brightening layer ─────────────────────────────────────────
		var top_pts := PackedVector2Array()
		var deep_off := 60.0
		for p in surface_pts: top_pts.append(p)
		for i in range(surface_pts.size() - 1, -1, -1):
			top_pts.append(surface_pts[i] + Vector2(0, deep_off))
		var mid_soil := Polygon2D.new()
		mid_soil.polygon = top_pts
		# Laterite reddish-orange brightening on the surface
		mid_soil.color   = Color(soil_color.r * 1.35 + 0.06, soil_color.g * 1.20, soil_color.b * 1.10)
		ground.add_child(mid_soil)

		# Humus darkening right below surface (organic top layer)
		var humus_pts := PackedVector2Array()
		for p in surface_pts: humus_pts.append(p)
		for i in range(surface_pts.size() - 1, -1, -1):
			humus_pts.append(surface_pts[i] + Vector2(0, 14.0))
		var humus_lay := Polygon2D.new()
		humus_lay.polygon = humus_pts
		humus_lay.color   = Color(soil_color.r * 0.85, soil_color.g * 0.80, soil_color.b * 0.75)
		ground.add_child(humus_lay)

		# ── Shadow strip directly under the surface ────────────────────────────
		var shadow_strip_pts := PackedVector2Array()
		var sth := 5.0
		for p in surface_pts: shadow_strip_pts.append(p)
		for i in range(surface_pts.size() - 1, -1, -1):
			shadow_strip_pts.append(surface_pts[i] + Vector2(0, sth))
		var shadow_strip := Polygon2D.new()
		shadow_strip.polygon = shadow_strip_pts
		shadow_strip.color   = Color(0.0, 0.0, 0.0, 0.32)
		ground.add_child(shadow_strip)

		# ── Grass band ─────────────────────────────────────────────────────────
		var grass_pts := PackedVector2Array()
		var th := 15.0
		for p in surface_pts: grass_pts.append(p)
		for i in range(surface_pts.size() - 1, -1, -1):
			grass_pts.append(surface_pts[i] + Vector2(0, th))
		var grass := Polygon2D.new()
		grass.polygon = grass_pts
		grass.color   = grass_color
		ground.add_child(grass)

		# Upper highlight edge
		var hi_pts := PackedVector2Array()
		for p in surface_pts: hi_pts.append(p)
		for i in range(surface_pts.size() - 1, -1, -1):
			hi_pts.append(surface_pts[i] + Vector2(0, 3.0))
		var grass_hi := Polygon2D.new()
		grass_hi.polygon = hi_pts
		grass_hi.color   = Color(
			min(grass_color.r * 1.50, 1.0),
			min(grass_color.g * 1.32, 1.0),
			min(grass_color.b * 1.10, 1.0),
			0.65
		)
		ground.add_child(grass_hi)

		# ── Grass blades along surface ─────────────────────────────────────────
		var blades_node := Node2D.new()
		blades_node.z_index = -24
		_add_to_level(blades_node)
		var seg_count := surface_pts.size()
		for bi in range(seg_count - 1):
			var bp1: Vector2 = surface_pts[bi]
			var bp2: Vector2 = surface_pts[bi + 1]
			var seg_len: float = bp2.x - bp1.x
			var n_blades := int(seg_len / 70.0) # optimized density from 25.0 to 70.0
			for bj in n_blades:
				var t   := float(bj) / float(max(n_blades, 1))
				var bx  := bp1.x + t * seg_len + randf_range(-3.0, 3.0)
				var by: float = lerp(bp1.y, bp2.y, t) - 1.0
				var bh  := randf_range(10.0, 26.0)
				var lean := randf_range(-0.22, 0.22)   # natural blade lean
				var blade := Polygon2D.new()
				blade.polygon = PackedVector2Array([
					Vector2(bx - 2.5,              by),
					Vector2(bx + lean * bh,         by - bh),
					Vector2(bx + 2.5,              by),
				])
				# Mix in yellowed blades, dark green bases, bright tips
				var yellow_mix := randf_range(0.0, 0.10)
				blade.color = Color(
					grass_color.r * 0.85 + yellow_mix * 1.6,
					grass_color.g * 0.95 + 0.06,
					grass_color.b * 0.80
				).lightened(randf_range(-0.05, 0.22))
				blades_node.add_child(blade)

			# Small wildflowers every ~2000px
			if randf() < 0.005: 
				var t   := randf()
				var fbx := bp1.x + t * seg_len
				var fby: float = lerp(bp1.y, bp2.y, t) - 18.0
				var flower := Polygon2D.new()
				var f_pts2: Array = []
				for fpi2 in 6:
					var fa2 := fpi2 * TAU / 6.0
					f_pts2.append(Vector2(fbx + cos(fa2) * 5.0, fby + sin(fa2) * 5.0))
				flower.polygon = PackedVector2Array(f_pts2)
				flower.color   = [Color(0.9, 0.9, 0.3, 0.85), Color(1.0, 0.5, 0.2, 0.85), Color(0.9, 0.9, 0.95, 0.85)][randi() % 3]
				flower.z_index = -23
				_add_to_level(flower)

		# ── Pebble scatter along surface ───────────────────────────────────────
		for pi in range(surface_pts.size() - 1):
			var pp1: Vector2 = surface_pts[pi]
			var pp2: Vector2 = surface_pts[pi + 1]
			var peb_count := int((pp2.x - pp1.x) / 80.0)
			for pj in peb_count:
				if randf() > 0.20: continue # Reduced density from 0.40 to 0.20
				var t   := randf()
				var px: float = lerp(pp1.x, pp2.x, t)
				var py: float = lerp(pp1.y, pp2.y, t) + randf_range(3.0, 12.0)
				var pr  := randf_range(2.5, 6.5)
				var peb := Polygon2D.new()
				var ppts: Array = []
				for pk in 8:
					var pa := pk * TAU / 8.0
					var pjit := randf_range(0.78, 1.22)
					ppts.append(Vector2(px + cos(pa) * pr * pjit, py + sin(pa) * pr * 0.50 * pjit))
				peb.polygon = PackedVector2Array(ppts)
				peb.color   = Color(soil_color.r * 1.6 + 0.05, soil_color.g * 1.3, soil_color.b * 1.1, 0.68)
				peb.z_index = -24
				_add_to_level(peb)
				# Moss cap on some pebbles
				if randf() < 0.35:
					var moss2 := Polygon2D.new()
					var m_pts2: Array = []
					for mpi2 in 8:
						var ma2 := mpi2 * TAU / 8.0
						m_pts2.append(Vector2(px + cos(ma2) * pr * 1.3, py - pr * 0.3 + sin(ma2) * pr * 0.4))
					moss2.polygon = PackedVector2Array(m_pts2)
					moss2.color   = Color(0.16, 0.36, 0.07, 0.50)
					moss2.z_index = -23
					_add_to_level(moss2)
		
		for p in surface_pts:
			if p.x <= total_len: _stage_terrain.append(p)
			
		# Decoration
		for i in range(surface_pts.size()-1):
			var p1 = surface_pts[i]
			var p2 = surface_pts[i+1]
			var count = int((p2.x - p1.x) / 50.0)
			for j in count:
				var t = randf()
				var vx = lerp(p1.x, p2.x, t)
				var vy = lerp(p1.y, p2.y, t)
				
				if randf() < 0.38:
					_create_jungle_fern(Vector2(vx, vy))
				elif randf() < 0.32:
					_create_dense_shrub(Vector2(vx, vy))

				if randf() < 0.18: _create_palm_tree(Vector2(vx, vy))
				if randf() < 0.12: _create_giant_ancient_tree(Vector2(vx, vy))
				if randf() < 0.18: _create_rock(Vector2(vx, vy))
				if randf() < 0.10: _create_rocky_outcrop(Vector2(vx, vy))

				if randf() < 0.15:
					# Realistic segmented bamboo cluster
					var rng_bam := RandomNumberGenerator.new()
					rng_bam.seed = int(vx * 7.0 + vy * 13.0)
					var n_stalks := rng_bam.randi_range(2, 4)
					var bam_root := Node2D.new()
					bam_root.position = Vector2(vx, vy)
					bam_root.z_index  = -19
					_world.add_child(bam_root)
					for bsi in n_stalks:
						var bx := rng_bam.randf_range(-12.0, 12.0)
						var btotal := rng_bam.randf_range(90.0, 200.0)
						var n_seg := int(btotal / 22.0) + 1
						var bw := rng_bam.randf_range(3.5, 6.0)
						var blean := rng_bam.randf_range(-0.12, 0.12)
						for bseg in n_seg:
							var seg_y0: float = float(bseg) * 22.0
							var seg_y1: float = min(seg_y0 + 22.0, btotal)
							var seg_col: Color = Color(0.10, 0.38, 0.05) if bseg % 2 == 0 else Color(0.14, 0.42, 0.06)
							var bpts := Polygon2D.new()
							var sx := blean * seg_y0
							bpts.polygon = PackedVector2Array([
								Vector2(bx + sx - bw * 0.5, -(btotal - seg_y0)),
								Vector2(bx + sx + bw * 0.5, -(btotal - seg_y0)),
								Vector2(bx + blean * seg_y1 + bw * 0.45, -(btotal - seg_y1)),
								Vector2(bx + blean * seg_y1 - bw * 0.45, -(btotal - seg_y1)),
							])
							bpts.color = seg_col
							bam_root.add_child(bpts)
							# Node ring
							var bnode := ColorRect.new()
							bnode.size     = Vector2(bw * 1.4, 2.5)
							bnode.position = Vector2(bx + sx - bw * 0.7, -(btotal - seg_y0) - 1.0)
							bnode.color    = Color(0.06, 0.28, 0.03)
							bam_root.add_child(bnode)
						# Top leaf frond
						var lf_pts := Polygon2D.new()
						var ltx := bx + blean * btotal
						lf_pts.polygon = PackedVector2Array([
							Vector2(ltx, -btotal),
							Vector2(ltx + rng_bam.randf_range(-18.0, -8.0), -btotal - rng_bam.randf_range(12.0, 22.0)),
							Vector2(ltx + rng_bam.randf_range( 8.0, 18.0), -btotal - rng_bam.randf_range(12.0, 22.0)),
						])
						lf_pts.color = Color(0.12, 0.44, 0.04)
						bam_root.add_child(lf_pts)
				
				if randf() < 0.05:
					var wreck = ColorRect.new()
					wreck.size = Vector2(80, 40)
					wreck.color = Color(0.2, 0.1, 0.05) if current_stage == 3 else Color(0.2, 0.25, 0.1)
					wreck.position = Vector2(vx, vy - 40)
					wreck.rotation = atan2(p2.y - p1.y, p2.x - p1.x)
					_world.add_child(wreck)
		
		# Gaps logic
		if has_gaps:
			cur_x = end_x + randf_range(80, 200)
			if cur_x <= total_len:
				_stage_terrain.append(Vector2(end_x + 1, 740.0))
				_stage_terrain.append(Vector2(cur_x - 1, 740.0))
		else:
			cur_x = end_x
	
	# Mist Layer (Final cleanup layer)
	for i in 15:
		var fog = ColorRect.new(); fog.size = Vector2(1500, 400); fog.position = Vector2(i * 1200, 300); fog.color = Color(1,1,1,0.05); fog.z_index = 5
		_world.add_child(fog)



func _spawn_turret(x, y) -> void:
	var t = TURRET_SCENE.instantiate()
	_world.add_child(t)
	t.position = Vector2(x, y)

func _spawn_boss(x, y) -> void:
	# Cổng Dinh Độc Lập / Independence Palace Gates
	
	# Palace Yard (Green grass behind the gate)
	var yard = ColorRect.new(); yard.size = Vector2(800, 150); yard.position = Vector2(x, y-150); yard.color = Color(0.15, 0.4, 0.15); yard.z_index = -35; _add_to_level(yard)
	var palace_bg = ColorRect.new(); palace_bg.size = Vector2(800, 300); palace_bg.position = Vector2(x, y-450); palace_bg.color = Color(0.85, 0.85, 0.8); palace_bg.z_index = -36; _add_to_level(palace_bg)
	
	# Tropical Palm Trees in the palace yard
	for i in 4:
		_create_palm_tree(Vector2(x + 100 + i*150, y))
		# Palms are already in the level node, but we need to find the latest
		var tree_node = _level_node.get_child(_level_node.get_child_count()-1)
		tree_node.z_index = -34
	
	# Iron fences (Broken in the middle)
	for i in 22:
		# Create a gap in the middle where the tank crashed
		if i > 7 and i < 15: continue 
		var bar = ColorRect.new(); bar.size = Vector2(8, 450); bar.position = Vector2(x-80 + i*35, y-450); bar.color = Color(0.2, 0.2, 0.2); bar.z_index = -15; _add_to_level(bar)
		var spike = Polygon2D.new(); spike.polygon = PackedVector2Array([Vector2(0,0), Vector2(4, -15), Vector2(8, 0)]); spike.color = Color(0.8, 0.7, 0.2); spike.position = Vector2(x-80 + i*35, y-450); spike.z_index = -15; _add_to_level(spike)

	# Concrete Pillars
	for idx_gate in 4:
		var px_pos = x - 100 + idx_gate * 260
		# Destroyed central pillars
		var pillar_h = 500.0 if (idx_gate == 0 or idx_gate == 3) else randf_range(100.0, 200.0)
		var pillar = ColorRect.new(); pillar.size = Vector2(60, pillar_h); pillar.position = Vector2(px_pos, y-pillar_h); pillar.color = Color(0.8, 0.8, 0.75); pillar.z_index = -10; _add_to_level(pillar)
		var base = ColorRect.new(); base.size = Vector2(80, 40); base.position = Vector2(px_pos-10, y-40); base.color = Color(0.6, 0.6, 0.55); pillar.add_child(base)

	# Banner above the gate
	var banner = ColorRect.new(); banner.size = Vector2(500, 60); banner.position = Vector2(x-100, y-550); banner.color = Color(0.8, 0.1, 0.1); banner.z_index = -9; _add_to_level(banner)
	
	# Iconic T-54 Tank husk that rammed the center gate
	var tank_husk = StaticBody2D.new(); tank_husk.position = Vector2(x + 100, y); _add_to_level(tank_husk)
	var tcol = CollisionShape2D.new(); var tshp = RectangleShape2D.new(); tshp.size = Vector2(250, 100); tcol.shape = tshp; tcol.position = Vector2(0, -50); tcol.one_way_collision = true; tank_husk.add_child(tcol)
	var tbody = Polygon2D.new(); tbody.polygon = PackedVector2Array([Vector2(-125, 0), Vector2(-100, -80), Vector2(100, -100), Vector2(125, 0)])
	tbody.color = Color(0.1, 0.35, 0.1) # Viet Cong Green
	tank_husk.add_child(tbody)
	var star = Polygon2D.new(); var pts = []
	for j in 10:
		var r = 20 if j % 2 == 0 else 8
		pts.append(Vector2(cos(j*TAU/10 - PI/2)*r, sin(j*TAU/10 - PI/2)*r))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; star.position = Vector2(-20, -50); tank_husk.add_child(star)

	# Note: No win_check timer needed. Winning is triggered by walking over STAGE_LENGTH - 100

func _create_truck_husk(pos: Vector2) -> void:
	var husk = StaticBody2D.new(); husk.position = pos; _add_to_level(husk)
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(160, 80); col.shape = shp; col.position = Vector2(0, -40); col.one_way_collision = true; husk.add_child(col)
	var body = Polygon2D.new(); body.polygon = PackedVector2Array([Vector2(-80, 0), Vector2(-80, -60), Vector2(-40, -80), Vector2(80, -80), Vector2(80, 0)])
	body.color = Color(0.25, 0.28, 0.22); husk.add_child(body)
	var w1 = ColorRect.new(); w1.size = Vector2(24, 24); w1.position = Vector2(-60, -12); w1.color = Color(0.1, 0.1, 0.1); husk.add_child(w1)
	var w2 = ColorRect.new(); w2.size = Vector2(24, 24); w2.position = Vector2(40, -12); w2.color = Color(0.1, 0.1, 0.1); husk.add_child(w2)
	if randf() < 0.5:
		var fire = ColorRect.new(); fire.size = Vector2(12, 18); fire.position = Vector2(-20, -98); fire.color = Color(1.0, 0.4, 0.0); husk.add_child(fire)
		var tw = create_tween().set_loops(); tw.tween_property(fire, "scale:y", 1.5, 0.15); tw.tween_property(fire, "scale:y", 1.0, 0.15)

func _create_sandbag_fort(pos: Vector2, h: float) -> void:
	var fort = StaticBody2D.new(); fort.position = pos; _add_to_level(fort)
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(100, h); col.shape = shp; col.position = Vector2(0, -h/2); col.one_way_collision = true; fort.add_child(col)
	for r in int(h/15):
		for c in 4:
			var bag = ColorRect.new(); bag.size = Vector2(24, 14); bag.position = Vector2(-50 + c*25 + (r%2)*10, -15 - r*15); bag.color = Color(0.5, 0.45, 0.35).darkened(randf_range(0.0, 0.2)); fort.add_child(bag)

# Helper to spawn enemies and decorations based on stage
func _spawn_enemy_wave(count: int, officer_p: float) -> void:
	for i in range(count):
		# Distribute across stage
		var x = 800 + i * (STAGE_LENGTH / count) + randf_range(-100, 100)
		if x > STAGE_LENGTH - 400: continue
		
		var is_off = randf() < officer_p
		var ey = _get_ground_y(x) - 20.0 # Just slightly above to drop onto ground
		if current_stage == 2:
			ey = 550 # Only spawn on surface ground
		
		# Ensure they are not stacked exactly on top of other active enemies
		for e in get_tree().get_nodes_in_group("enemy"):
			if not is_instance_valid(e) or e.is_queued_for_deletion(): continue
			if abs(e.position.x - x) < 200: 
				x += 300 # Push further if too close
				ey = _get_ground_y(x) - 20.0
		
		if x > STAGE_LENGTH - 400: continue
		_spawn_enemy(x, ey, is_off)
		
		# Sniper logic restricted: only for Base/Tunnel stages where formal platforms exist
		if (current_stage == 2 or current_stage == 4) and randf() < 0.1: 
			_spawn_enemy(x + 120, ey - 200, false)
		
		# (Removed the sneaky random tank spawn here. Tanks are only spawned directly by stage logic now)
	
	# Initial delay for first bomber: scales with stage
	var base_delay = lerp(8.0, 3.0, float(current_stage - 1) / 4.0)
	_bomber_timer = base_delay

func _spawn_decoration_density(tree_p: float, rock_p: float) -> void:
	for i in range(100):
		var x = randf_range(0, STAGE_LENGTH)
		var y = _get_ground_y(x)
		if randf() < tree_p: _create_palm_tree(Vector2(x, y))
		if randf() < rock_p: _create_rock(Vector2(x, y))
		if randf() < 0.3: _create_flower(Vector2(x, y))

func _setup_clouds(count: int) -> void:
	for i in range(count):
		_create_cloud_premium(Vector2(i * (STAGE_LENGTH/count) + randf_range(-100, 100), randf_range(40, 180)))

func _create_platform_complex(count: int, low: bool = false) -> void:
	for i in range(count):
		var y = randf_range(350, 480) if not low else randf_range(450, 520)
		var x = 400 + i * (STAGE_LENGTH/count) + randf_range(-50, 50)
		_create_platform_detailed(Vector2(x, y), randf_range(150, 350))

func _create_floor_detailed(start_x, end_x, y, grass_color = Color(0.08, 0.22, 0.05)) -> void:
	var floor_node = StaticBody2D.new()
	var col = CollisionShape2D.new()
	var shape = WorldBoundaryShape2D.new()
	shape.normal = Vector2.UP
	col.shape = shape
	floor_node.add_child(col)
	floor_node.position.y = y
	_add_to_level(floor_node)
	
	var dirt = ColorRect.new()
	dirt.color = Color(0.2, 0.12, 0.05)
	dirt.size = Vector2(end_x - start_x, 400)
	dirt.position = Vector2(start_x, 0)
	floor_node.add_child(dirt)
	
	var grass = ColorRect.new()
	grass.color = grass_color
	grass.size = Vector2(end_x - start_x, 20)
	grass.position = Vector2(start_x, -5)
	floor_node.add_child(grass)
	
	for i in range(600):
		var leaf = Polygon2D.new()
		var lx: float = randf_range(float(start_x), float(end_x))
		leaf.polygon = PackedVector2Array([Vector2(-3, 0), Vector2(0, -12), Vector2(3, 0)])
		leaf.color = grass_color.lightened(0.2)
		leaf.position = Vector2(lx, 0)
		floor_node.add_child(leaf)

func _create_palm_tree(pos: Vector2) -> void:
	var rng_p := RandomNumberGenerator.new()
	rng_p.seed = int(pos.x * 11.0 + pos.y * 5.0)

	var tree := Node2D.new()
	tree.position = pos
	tree.z_index  = -20
	tree.scale    = Vector2.ONE * rng_p.randf_range(0.80, 1.25)
	tree.rotation = rng_p.randf_range(-0.06, 0.06)
	_add_to_level(tree)

	var trunk_h := rng_p.randf_range(100.0, 145.0)
	var lean_x  := rng_p.randf_range(-18.0, 18.0)

	# Ground shadow
	var ao := Polygon2D.new()
	var ao_pts: Array = []
	for ai in 10:
		var aa: float = float(ai) * TAU / 10.0
		ao_pts.append(Vector2(cos(aa) * 14.0, sin(aa) * 5.0 + 3))
	ao.polygon = PackedVector2Array(ao_pts)
	ao.color   = Color(0.0, 0.0, 0.0, 0.28)
	tree.add_child(ao)

	# Trunk: tapered curved polygon using 6 spine points
	var spine: Array = []
	for si in 6:
		var st := float(si) / 5.0
		spine.append(Vector2(lean_x * st * st, -trunk_h * st))

	var tw_base := 7.0
	var tw_top  := 3.5
	var left_pts:  Array = []
	var right_pts: Array = []
	for si2 in spine.size():
		var sp: Vector2 = spine[si2]
		var tw2: float = lerp(tw_base, tw_top, float(si2) / float(spine.size() - 1))
		left_pts.append(sp + Vector2(-tw2, 0.0))
		right_pts.append(sp + Vector2(tw2, 0.0))
	right_pts.reverse()
	var trunk_arr: Array = left_pts + right_pts
	var trunk := Polygon2D.new()
	trunk.polygon = PackedVector2Array(trunk_arr)
	trunk.color   = Color(0.30, 0.19, 0.09)
	tree.add_child(trunk)

	# Trunk highlight left
	var thl := Polygon2D.new()
	var thl_l: Array = []
	var thl_r: Array = []
	for si3 in spine.size():
		var sp3: Vector2 = spine[si3]
		var tw3: float = lerp(tw_base, tw_top, float(si3) / float(spine.size() - 1))
		thl_l.append(sp3 + Vector2(-tw3, 0.0))
		thl_r.append(sp3 + Vector2(-tw3 * 0.3, 0.0))
	thl_r.reverse()
	thl.polygon = PackedVector2Array(thl_l + thl_r)
	thl.color   = Color(0.52, 0.33, 0.15, 0.38)
	tree.add_child(thl)

	# Trunk shadow right
	var tsh := Polygon2D.new()
	var tsh_l: Array = []
	var tsh_r: Array = []
	for si4 in spine.size():
		var sp4: Vector2 = spine[si4]
		var tw4: float = lerp(tw_base, tw_top, float(si4) / float(spine.size() - 1))
		tsh_l.append(sp4 + Vector2(tw4 * 0.3, 0.0))
		tsh_r.append(sp4 + Vector2(tw4, 0.0))
	tsh_r.reverse()
	tsh.polygon = PackedVector2Array(tsh_l + tsh_r)
	tsh.color   = Color(0.0, 0.0, 0.0, 0.25)
	tree.add_child(tsh)

	# Ring scars on trunk (characteristic of real palms)
	var n_rings := int(trunk_h / 22.0)
	for ri in n_rings:
		var rt := float(ri) / float(n_rings)
		var sp_r: Vector2 = spine[int(rt * (spine.size() - 1))]
		var ring := ColorRect.new()
		ring.size     = Vector2(tw_base * 2.2, 2)
		ring.position = Vector2(sp_r.x - tw_base * 1.1, sp_r.y - 1)
		ring.color    = Color(0.15, 0.09, 0.04, 0.45)
		tree.add_child(ring)

	# Crown position
	var crown_pos: Vector2 = spine[spine.size() - 1]

	# Crown shadow blob
	var crown_sh := Polygon2D.new()
	var csh: Array = []
	for ci in 14:
		var ca: float = float(ci) * TAU / 14.0
		csh.append(crown_pos + Vector2(cos(ca) * 32.0 + 8, sin(ca) * 14.0 + 10))
	crown_sh.polygon = PackedVector2Array(csh)
	crown_sh.color   = Color(0.0, 0.0, 0.0, 0.20)
	tree.add_child(crown_sh)

	# Fronds: curved rachis + paired pinnae leaflets
	var n_fronds := rng_p.randi_range(8, 11)
	for fi in n_fronds:
		var fa := float(fi) / float(n_fronds) * TAU + rng_p.randf_range(-0.15, 0.15)
		var flen2 := rng_p.randf_range(52.0, 78.0)
		var droop := rng_p.randf_range(0.25, 0.55)
		var f_tip := Vector2(cos(fa) * flen2 * 0.9, sin(fa) * flen2 * 0.9 + flen2 * droop)
		var f_mid := (crown_pos * 2.0 + f_tip) / 3.0 + Vector2(0, flen2 * droop * 0.4)
		# Rachis midrib
		var rachis := Polygon2D.new()
		rachis.position = crown_pos
		rachis.polygon  = PackedVector2Array([
			Vector2(-1.5, 0), f_mid - crown_pos + Vector2(-1, 0),
			f_tip - crown_pos + Vector2(1, 0), f_tip - crown_pos + Vector2(-1, 0),
			f_mid - crown_pos + Vector2(1, 0), Vector2(1.5, 0),
		])
		rachis.color = Color(0.10, 0.30, 0.05)
		tree.add_child(rachis)
		# Pinnae
		var n_pinnae := int(flen2 / 9.0)
		for pi2 in n_pinnae:
			var pt := float(pi2 + 1) / float(n_pinnae + 1)
			var pb: Vector2 = crown_pos.lerp(f_tip, pt) + Vector2(0, flen2 * droop * pt * pt)
			var plen := flen2 * 0.22 * (1.0 - pt * 0.5)
			for pside in [-1, 1]:
				var pina := Polygon2D.new()
				var pa2: float = fa + float(pside) * PI * 0.46
				pina.polygon = PackedVector2Array([
					pb,
					pb + Vector2(cos(pa2) * plen, sin(pa2) * plen),
					pb + Vector2(cos(pa2 + 0.4) * plen * 0.55, sin(pa2 + 0.4) * plen * 0.55),
				])
				pina.color = Color(0.07, 0.30 + rng_p.randf() * 0.12, 0.04).lightened(rng_p.randf() * 0.18)
				tree.add_child(pina)

	# Coconut cluster
	var n_nuts := rng_p.randi_range(2, 4)
	for ni in n_nuts:
		var na := float(ni) / float(n_nuts) * TAU
		var nut := Polygon2D.new()
		var nut_pts: Array = []
		for npi in 10:
			var npa: float = float(npi) * TAU / 10.0
			nut_pts.append(crown_pos + Vector2(cos(na) * 8.0 + cos(npa) * 5.5, sin(na) * 5.0 + sin(npa) * 5.5))
		nut.polygon = PackedVector2Array(nut_pts)
		nut.color   = Color(0.28, 0.52, 0.08)
		tree.add_child(nut)

func _create_jungle_shrub(pos: Vector2) -> void:
	var shrub = Polygon2D.new(); shrub.position = pos; _world.add_child(shrub)
	shrub.polygon = PackedVector2Array([Vector2(-25, 0), Vector2(-15, -40), Vector2(0, -55), Vector2(15, -40), Vector2(25, 0)])
	shrub.color = Color(0.1, 0.28, 0.08, 0.9)

func _create_cloud_premium(pos: Vector2) -> void:
	var cloud = Node2D.new()
	cloud.position = pos
	cloud.modulate.a = 0.55
	_world.add_child(cloud)
	for i in 4:
		var puffy = Polygon2D.new()
		var pts = []
		var rd = 40 + randf() * 20
		for j in 12:
			var a = j * TAU / 12
			pts.append(Vector2(cos(a) * rd, sin(a) * rd / 1.8))
		puffy.polygon = PackedVector2Array(pts)
		puffy.color = Color.WHITE
		puffy.position = Vector2(i * 40 - 60, randf() * 10)
		cloud.add_child(puffy)

func _create_rocky_outcrop(pos: Vector2) -> void:
	# A cluster of 2–4 rocks forming a small boulder step / ledge
	var rng_ro := RandomNumberGenerator.new()
	rng_ro.seed = int(pos.x * 17.0 + pos.y * 3.0)

	var rock_root := Node2D.new()
	rock_root.position = pos
	rock_root.z_index  = -18
	_world.add_child(rock_root)

	# Wide ground AO shadow for the whole cluster
	var cs := Polygon2D.new()
	var cs_pts: Array = []
	for csi in 12:
		var csa := csi * TAU / 12.0
		cs_pts.append(Vector2(cos(csa) * rng_ro.randf_range(30.0, 48.0), sin(csa) * rng_ro.randf_range(10.0, 15.0) + 9))
	cs.polygon = PackedVector2Array(cs_pts)
	cs.color   = Color(0.0, 0.0, 0.0, 0.30)
	rock_root.add_child(cs)

	var n_rocks := rng_ro.randi_range(2, 4)
	var base_gray := rng_ro.randf_range(0.28, 0.40)
	var offsets: Array = [
		Vector2(0.0, 0.0),
		Vector2(-rng_ro.randf_range(20.0, 35.0),  rng_ro.randf_range(6.0, 12.0)),
		Vector2( rng_ro.randf_range(18.0, 32.0),  rng_ro.randf_range(5.0, 11.0)),
		Vector2( rng_ro.randf_range(-8.0,  8.0),  rng_ro.randf_range(10.0, 18.0)),
	]
	var ro_scales: Array = [1.0, 0.72, 0.68, 0.55]

	for ri3 in n_rocks:
		var off: Vector2   = offsets[ri3]
		var sc3: float     = ro_scales[ri3]
		var rw3 := rng_ro.randf_range(14.0, 26.0) * sc3
		var rh3 := rng_ro.randf_range(10.0, 18.0) * sc3
		var rot3 := rng_ro.randf_range(-0.25, 0.25)
		var n_rpts := rng_ro.randi_range(7, 10)

		# Main rock fill
		var rpts: Array = []
		for rpi2 in n_rpts:
			var rpa := rpi2 * TAU / float(n_rpts)
			var rjit := rng_ro.randf_range(0.78, 1.22)
			rpts.append(off + Vector2(cos(rpa) * rw3 * rjit, sin(rpa) * rh3 * rjit).rotated(rot3))
		var rm := Polygon2D.new()
		rm.polygon = PackedVector2Array(rpts)
		rm.color   = Color(base_gray, base_gray * 0.94, base_gray * 1.06)
		rock_root.add_child(rm)

		# Light face (upper-left arc)
		var hl3: Array = []
		for rpi3 in n_rpts:
			var rpa3 := rpi3 * TAU / float(n_rpts)
			if rpa3 > PI * 1.05 or rpa3 < PI * 0.08:
				hl3.append(off + Vector2(cos(rpa3) * rw3 * 0.92, sin(rpa3) * rh3 * 0.92).rotated(rot3))
		if hl3.size() >= 3:
			var rhl := Polygon2D.new()
			rhl.polygon = PackedVector2Array(hl3)
			rhl.color   = Color(1.0, 1.0, 1.0, 0.18)
			rock_root.add_child(rhl)

		# Shadow face (lower-right arc)
		var sh3: Array = []
		for rpi4 in n_rpts:
			var rpa4 := rpi4 * TAU / float(n_rpts)
			if rpa4 > 0.1 and rpa4 < PI * 1.1:
				sh3.append(off + Vector2(cos(rpa4) * rw3 * 0.92, sin(rpa4) * rh3 * 0.92).rotated(rot3))
				sh3.append(off + Vector2(cos(rpa4) * rw3,        sin(rpa4) * rh3       ).rotated(rot3))
		if sh3.size() >= 3:
			var rsh := Polygon2D.new()
			rsh.polygon = PackedVector2Array(sh3)
			rsh.color   = Color(0.0, 0.0, 0.0, 0.28)
			rock_root.add_child(rsh)

		# Crack
		var crack3 := ColorRect.new()
		crack3.size     = Vector2(2.0, rh3 * rng_ro.randf_range(0.5, 0.8))
		crack3.position = off + Vector2(rng_ro.randf_range(-rw3 * 0.3, rw3 * 0.3), -rh3 * 0.75)
		crack3.color    = Color(0.0, 0.0, 0.0, 0.28)
		crack3.rotation = rng_ro.randf_range(-0.3, 0.3)
		rock_root.add_child(crack3)

		# Moss cap
		if rng_ro.randf() < 0.60:
			var m3pts: Array = []
			for mpi3 in 8:
				var mpa3 := mpi3 * TAU / 8.0
				m3pts.append(off + Vector2(cos(mpa3) * rw3 * 0.58, sin(mpa3) * rh3 * 0.32 - rh3 * 0.62).rotated(rot3))
			var rmoss3 := Polygon2D.new()
			rmoss3.polygon = PackedVector2Array(m3pts)
			rmoss3.color   = Color(0.14, 0.34, 0.07, 0.55)
			rock_root.add_child(rmoss3)

	# Grass tufts between rocks
	for gi2 in rng_ro.randi_range(3, 6):
		var gx2 := rng_ro.randf_range(-28.0, 28.0)
		var gh2 := rng_ro.randf_range(6.0, 14.0)
		var bl2 := Polygon2D.new()
		bl2.polygon = PackedVector2Array([
			Vector2(gx2 - 2, 0),
			Vector2(gx2 + rng_ro.randf_range(-0.2, 0.2) * gh2, -gh2),
			Vector2(gx2 + 2, 0),
		])
		bl2.color = Color(0.22, 0.45, 0.08, 0.90)
		rock_root.add_child(bl2)

func _create_rock(pos: Vector2) -> void:
	var rng_r := RandomNumberGenerator.new()
	rng_r.seed = int(pos.x * 9.0 + pos.y * 19.0)

	var r_root := Node2D.new()
	r_root.position = pos
	r_root.z_index  = -18
	_world.add_child(r_root)

	var rw := rng_r.randf_range(9.0, 18.0)
	var rh := rng_r.randf_range(7.0, 13.0)
	var rot_r := rng_r.randf_range(-0.35, 0.35)
	var gray := rng_r.randf_range(0.30, 0.44)

	# AO shadow
	var rao := Polygon2D.new()
	var rao_pts: Array = []
	for rapi in 10:
		var rapa := rapi * TAU / 10.0
		rao_pts.append(Vector2(cos(rapa) * rw * 1.3, sin(rapa) * rh * 0.6 + 5))
	rao.polygon = PackedVector2Array(rao_pts)
	rao.color   = Color(0.0, 0.0, 0.0, 0.25)
	r_root.add_child(rao)

	# Main body
	var n_rp := rng_r.randi_range(7, 9)
	var rp: Array = []
	for rpi5 in n_rp:
		var rpa5 := rpi5 * TAU / float(n_rp)
		var rj := rng_r.randf_range(0.80, 1.20)
		rp.append(Vector2(cos(rpa5) * rw * rj, sin(rpa5) * rh * rj).rotated(rot_r))
	var r_body := Polygon2D.new()
	r_body.polygon = PackedVector2Array(rp)
	r_body.color   = Color(gray, gray * 0.94, gray * 1.06)
	r_root.add_child(r_body)

	# Highlight upper-left
	var rhl_pts2: Array = []
	for rpi6 in n_rp:
		var rpa6 := rpi6 * TAU / float(n_rp)
		if rpa6 > PI * 1.05 or rpa6 < PI * 0.08:
			rhl_pts2.append(Vector2(cos(rpa6) * rw * 0.92, sin(rpa6) * rh * 0.92).rotated(rot_r))
	if rhl_pts2.size() >= 3:
		var rhl2 := Polygon2D.new()
		rhl2.polygon = PackedVector2Array(rhl_pts2)
		rhl2.color   = Color(1.0, 1.0, 1.0, 0.20)
		r_root.add_child(rhl2)

	# Shadow lower-right
	var rsh_pts2: Array = []
	for rpi7 in n_rp:
		var rpa7 := rpi7 * TAU / float(n_rp)
		if rpa7 > 0.1 and rpa7 < PI:
			rsh_pts2.append(Vector2(cos(rpa7) * rw * 0.88, sin(rpa7) * rh * 0.88).rotated(rot_r))
			rsh_pts2.append(Vector2(cos(rpa7) * rw,        sin(rpa7) * rh       ).rotated(rot_r))
	if rsh_pts2.size() >= 3:
		var rsh2 := Polygon2D.new()
		rsh2.polygon = PackedVector2Array(rsh_pts2)
		rsh2.color   = Color(0.0, 0.0, 0.0, 0.22)
		r_root.add_child(rsh2)

	# Moss cap
	if rng_r.randf() < 0.55:
		var rmpts: Array = []
		for rmi in 8:
			var rma := rmi * TAU / 8.0
			rmpts.append(Vector2(cos(rma) * rw * 0.55, sin(rma) * rh * 0.30 - rh * 0.65).rotated(rot_r))
		var rmoss := Polygon2D.new()
		rmoss.polygon = PackedVector2Array(rmpts)
		rmoss.color   = Color(0.14, 0.34, 0.07, 0.52)
		r_root.add_child(rmoss)

	# Crack
	var rcrack := ColorRect.new()
	rcrack.size     = Vector2(1.5, rh * rng_r.randf_range(0.45, 0.75))
	rcrack.position = Vector2(rng_r.randf_range(-rw * 0.25, rw * 0.25), -rh * 0.75)
	rcrack.color    = Color(0.0, 0.0, 0.0, 0.28)
	rcrack.rotation = rng_r.randf_range(-0.4, 0.4)
	r_root.add_child(rcrack)

func _create_flower(pos: Vector2) -> void:
	var fl = Polygon2D.new()
	fl.position = pos
	_world.add_child(fl)
	fl.polygon = PackedVector2Array([
		Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)
	])
	fl.color = [Color.RED, Color.YELLOW, Color.MAGENTA, Color.ORANGE, Color.CYAN].pick_random()

func _create_platform_detailed(pos: Vector2, width: float) -> void:
	var hill = Polygon2D.new()
	var hill_h = 600 - pos.y
	hill.polygon = PackedVector2Array([
		Vector2(-width/2 - 20, hill_h), 
		Vector2(-width/2 + 10, 0), 
		Vector2(width/2 - 10, 0), 
		Vector2(width/2 + 20, hill_h)
	])
	hill.color = Color(0.25, 0.15, 0.08)
	hill.position = pos
	_add_to_level(hill)
	
	var plat = StaticBody2D.new()
	var col = CollisionShape2D.new()
	col.one_way_collision = true
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, 16)
	col.shape = shape
	plat.add_child(col)
	plat.position = pos
	_add_to_level(plat)
	
	var log_v = ColorRect.new()
	log_v.size = Vector2(width, 16)
	log_v.position = Vector2(-width/2, -8)
	log_v.color = Color(0.28, 0.18, 0.08)
	plat.add_child(log_v)
	
	var moss = ColorRect.new()
	moss.size = Vector2(width, 4)
	moss.position = Vector2(-width/2, -10)
	moss.color = Color(0.2, 0.5, 0.1)
	plat.add_child(moss)
	
	for i in range(int(width/30)):
		var vine = ColorRect.new()
		vine.size = Vector2(2, randf_range(30, 80))
		vine.position = Vector2(-width/2 + i * 30 + 10, 8)
		vine.color = Color(0.12, 0.35, 0.1)
		plat.add_child(vine)

func _create_tunnel_rat(pos: Vector2) -> void:
	var rat = Node2D.new()
	rat.position = pos
	rat.z_index = -5
	_add_to_level(rat)
	
	var body = ColorRect.new()
	body.size = Vector2(8, 4)
	body.position = Vector2(-4, -4)
	body.color = Color(0.3, 0.25, 0.2)
	rat.add_child(body)
	
	var tail = Line2D.new()
	tail.points = PackedVector2Array([Vector2(-4, -2), Vector2(-10, -1), Vector2(-12, -3)])
	tail.width = 1.0
	tail.default_color = Color(0.4, 0.35, 0.3)
	rat.add_child(tail)
	
	var head = ColorRect.new()
	head.size = Vector2(3, 3)
	head.position = Vector2(4, -4)
	head.color = Color(0.35, 0.3, 0.25)
	rat.add_child(head)
	
	# Scuttle animation
	var tw = create_tween().set_loops().bind_node(rat)
	var next_x = pos.x + (100 if randf() > 0.5 else -100)
	tw.tween_property(rat, "position:x", next_x, randf_range(1.5, 3.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): if is_instance_valid(rat): rat.scale.x *= -1)
	tw.set_parallel(false)
	tw.tween_interval(randf_range(0.5, 1.5))
	tw.tween_property(rat, "position:x", pos.x, randf_range(1.5, 3.0)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): if is_instance_valid(rat): rat.scale.x *= -1)
	tw.tween_interval(randf_range(0.5, 1.5))

func _create_war_bulldozer(pos: Vector2) -> void:
	# Design: Rome Plow D7 (Vietnam War era)
	var dozer = StaticBody2D.new()
	dozer.position = pos
	dozer.z_index = -5
	_add_to_level(dozer)
	
	# Primary collision (for jumping on)
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new()
	shp.size = Vector2(180, 80)
	col.shape = shp
	col.position = Vector2(0, -40)
	col.one_way_collision = true
	dozer.add_child(col)
	
	# Secondary collision for the front blade (hard wall or step)
	var b_col = CollisionShape2D.new()
	var b_shp = RectangleShape2D.new()
	b_shp.size = Vector2(40, 100)
	b_col.shape = b_shp
	b_col.position = Vector2(110, -50)
	dozer.add_child(b_col)
	
	# --- Visuals ---
	# Tracks
	var tracks = ColorRect.new()
	tracks.size = Vector2(160, 25)
	tracks.position = Vector2(-80, -25)
	tracks.color = Color(0.1, 0.1, 0.15)
	dozer.add_child(tracks)
	
	# Track details/links
	for i in 8:
		var link = ColorRect.new()
		link.size = Vector2(12, 10)
		link.position = Vector2(-75 + i*20, -20)
		link.color = Color(0.2, 0.2, 0.2)
		dozer.add_child(link)

	# Main Body (Olive Drab)
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(-80, -25), Vector2(-80, -70), 
		Vector2(20, -70), Vector2(20, -25)
	])
	body.color = Color(0.28, 0.32, 0.18)
	dozer.add_child(body)
	
	# Engine Hood
	var engine = ColorRect.new()
	engine.size = Vector2(70, 45)
	engine.position = Vector2(20, -70)
	engine.color = Color(0.25, 0.3, 0.15)
	dozer.add_child(engine)
	
	# Rome Plow Blade (Large, slanted, heavy)
	var blade = Polygon2D.new()
	blade.polygon = PackedVector2Array([
		Vector2(90, -10), Vector2(130, -100), 
		Vector2(145, -100), Vector2(105, -10)
	])
	blade.color = Color(0.35, 0.35, 0.35)
	dozer.add_child(blade)
	
	# Sharp vertical splitter on the blade (The 'Rome' part)
	var splitter = ColorRect.new()
	splitter.size = Vector2(6, 60)
	splitter.position = Vector2(135, -100)
	splitter.color = Color(0.5, 0.1, 0.1)
	dozer.add_child(splitter)
	
	# Protective Roll Cage (ROPS)
	var cage = Line2D.new()
	cage.points = PackedVector2Array([
		Vector2(-70, -70), Vector2(-70, -110), 
		Vector2(30, -110), Vector2(30, -70)
	])
	cage.width = 4.0
	cage.default_color = Color(0.15, 0.15, 0.1)
	dozer.add_child(cage)
	
	# Exhaust pipe & Smoke
	var exhaust = ColorRect.new()
	exhaust.size = Vector2(5, 40)
	exhaust.position = Vector2(40, -105)
	exhaust.color = Color(0.2, 0.2, 0.2)
	dozer.add_child(exhaust)
	
	var smoke = ColorRect.new()
	smoke.size = Vector2(10, 10)
	smoke.position = Vector2(38, -115)
	smoke.color = Color(1, 1, 1, 0.4)
	dozer.add_child(smoke)
	var stw = create_tween().set_loops().bind_node(smoke)
	stw.tween_property(smoke, "position:y", -140, 0.8)
	stw.parallel().tween_property(smoke, "modulate:a", 0.0, 0.8)
	stw.tween_callback(func(): if is_instance_valid(smoke): smoke.position.y = -115; smoke.modulate.a = 0.4)

func _create_highland_truck(pos: Vector2) -> void:
	# Design: ZIL-131 style transport truck (Vietnam War era)
	var truck = StaticBody2D.new()
	truck.position = pos
	truck.z_index = -15
	_add_to_level(truck)
	
	# Platform collision (Top bed and cabin)
	var col = CollisionShape2D.new()
	var shp = RectangleShape2D.new()
	shp.size = Vector2(240, 90)
	col.shape = shp
	col.position = Vector2(0, -45)
	col.one_way_collision = true
	truck.add_child(col)
	
	# --- Visuals ---
	# Massive wheels
	for wpos in [Vector2(-80, -18), Vector2(-40, -18), Vector2(70, -18)]:
		var wheel = ColorRect.new()
		wheel.size = Vector2(44, 44)
		wheel.position = wpos - Vector2(22, 22)
		wheel.color = Color(0.1, 0.1, 0.12)
		truck.add_child(wheel)
		var hub = ColorRect.new(); hub.size = Vector2(14, 14); hub.position = wpos - Vector2(7, 7); hub.color = Color(0.25, 0.25, 0.25); truck.add_child(hub)

	# Main Chassis frame
	var frame = ColorRect.new()
	frame.size = Vector2(230, 12)
	frame.position = Vector2(-115, -35)
	frame.color = Color(0.12, 0.12, 0.12)
	truck.add_child(frame)
	
	# Cabin (Angular Soviet style)
	var cabin = Polygon2D.new()
	cabin.polygon = PackedVector2Array([
		Vector2(20, -35), Vector2(20, -105), 
		Vector2(100, -105), Vector2(115, -75), Vector2(115, -35)
	])
	cabin.color = Color(0.22, 0.28, 0.16)
	truck.add_child(cabin)
	
	# Windshield
	var glass = ColorRect.new()
	glass.size = Vector2(40, 35)
	glass.position = Vector2(65, -95)
	glass.color = Color(0.4, 0.6, 0.7, 0.5)
	truck.add_child(glass)
	
	# Cargo Bed (Wooden planks texture)
	var bed = ColorRect.new()
	bed.size = Vector2(150, 45)
	bed.position = Vector2(-120, -80)
	bed.color = Color(0.3, 0.2, 0.12)
	truck.add_child(bed)
	
	# Canvas canopy (Camouflage/Green)
	var canopy = Polygon2D.new()
	canopy.polygon = PackedVector2Array([
		Vector2(-120, -80), Vector2(-120, -125), 
		Vector2(-40, -140), Vector2(20, -125), Vector2(20, -80)
	])
	canopy.color = Color(0.18, 0.32, 0.14)
	truck.add_child(canopy)
	
	# Detailed camo splotches on canopy
	for i in 3:
		var splotch = Polygon2D.new()
		var sp_pos = Vector2(-100 + i*40, -110)
		splotch.polygon = PackedVector2Array([Vector2(-15, -10), Vector2(15, -5), Vector2(10, 15), Vector2(-10, 10)])
		splotch.color = Color(0.1, 0.2, 0.05, 0.4)
		splotch.position = sp_pos
		truck.add_child(splotch)

	# Front Bumper & Headlights
	var bumper = ColorRect.new(); bumper.size = Vector2(10, 30); bumper.position = Vector2(115, -55); bumper.color = Color(0.2, 0.2, 0.18); truck.add_child(bumper)
	var light = ColorRect.new(); light.size = Vector2(12, 12); light.position = Vector2(110, -85); light.color = Color(1, 1, 0.8, 0.9); truck.add_child(light)

func _spawn_enemy(x, y, is_off: bool = false) -> void:
	var e = ENEMY_SCENE.instantiate()
	e.is_officer = is_off
	_add_to_level(e) # Add for proper scrolling & cleanup
	e.position = Vector2(x, y)

func _spawn_background_soldiers(count: int) -> void:
	for i in range(count):
		var x = 400 + i * (STAGE_LENGTH / count) + randf_range(-400, 400)
		var y: float
		var is_tun: bool = false
		if current_stage == 2 and i % 2 == 0:
			y = 650.0  # Lower/Tunnel path (only for Stage 2)
			is_tun = true
		else:
			y = _get_ground_y(x)
			is_tun = false
		_add_individual_background_soldier(x, y, is_tun)

func _add_individual_background_soldier(x: float, y: float = 600, is_tun: bool = false) -> void:
	# Check for overlaps (loosen even more to 60px for density)
	for s in get_tree().get_nodes_in_group("ally_army"):
		if abs(s.position.x - x) < 60: return 
	var soldier = Node2D.new()
	var body_node = Node2D.new(); soldier.add_child(body_node)
	var head_node = Node2D.new(); body_node.add_child(head_node)
	
	# Leg visuals (Back & Front)
	var leg_poly = PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(4.5, 16), Vector2(-4.5, 16)])
	var l_l = Polygon2D.new(); l_l.polygon = leg_poly; l_l.color = Color(0.12, 0.28, 0.1); l_l.name = "LegL"; soldier.add_child(l_l); l_l.position = Vector2(-3, 0)
	var l_r = Polygon2D.new(); l_r.polygon = leg_poly; l_r.color = Color(0.18, 0.4, 0.15); l_r.name = "LegR"; soldier.add_child(l_r); l_r.position = Vector2(3, 0)
	
	# --- Body (Olive Green Uniform with depth) ---
	var soldier_color = Color(0.18, 0.38, 0.15)
	var torso = Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-9, -18), Vector2(9, -18), Vector2(10, 0), Vector2(-10, 0)])
	torso.color = soldier_color
	body_node.add_child(torso)
	
	# Shading
	var t_shade = Polygon2D.new(); t_shade.polygon = PackedVector2Array([Vector2(4, -18), Vector2(9, -18), Vector2(10, 0), Vector2(5, 0)]); t_shade.color = soldier_color.darkened(0.15); body_node.add_child(t_shade)
	
	# Ba lô con cóc (Backpack)
	var pack = Polygon2D.new(); pack.polygon = PackedVector2Array([Vector2(-14, -16), Vector2(-8, -16), Vector2(-8, -4), Vector2(-15, -6)]); pack.color = soldier_color.darkened(0.2); body_node.add_child(pack)

	# --- Head & Realistic Mũ Cối ---
	var face = ColorRect.new(); face.size = Vector2(10, 7); face.position = Vector2(-5, -23); face.color = Color(0.95, 0.8, 0.65); head_node.add_child(face)
	
	# Mũ Cối (High detail)
	var hat_base = Polygon2D.new(); hat_base.polygon = [Vector2(-11, -24), Vector2(11, -24), Vector2(9, -20), Vector2(-9, -20)]; hat_base.color = Color(0.1, 0.32, 0.1); head_node.add_child(hat_base)
	var hat_dome = Polygon2D.new(); hat_dome.polygon = [Vector2(-8, -24), Vector2(8, -24), Vector2(7, -33), Vector2(0, -35), Vector2(-7, -33)]; hat_dome.color = Color(0.15, 0.4, 0.15); head_node.add_child(hat_dome)
	
	# Star
	var star = Polygon2D.new(); var pts = []
	for j in 5:
		var a = j*TAU/5-PI/2; pts.append(Vector2(cos(a)*1.5, sin(a)*1.5 - 28))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; head_node.add_child(star)
	
	# Rifle (Súng AK-47 visual)
	var gun = ColorRect.new(); gun.size = Vector2(28, 4); gun.position = Vector2(2, -12); gun.color = Color(0.08, 0.08, 0.08); body_node.add_child(gun)
	var stock = ColorRect.new(); stock.size = Vector2(6, 4); stock.position = Vector2(-4, -12); stock.color = Color(0.4, 0.15, 0.05); body_node.add_child(stock)
	
	soldier.z_index = -4
	# Snap Y immediately so soldiers don't fall from sky
	var snapped_y = 650.0 if is_tun else _get_ground_y(x)
	soldier.position = Vector2(x, snapped_y)
	soldier.z_index = 4 # Explicitly in front of props
	soldier.add_to_group("ally_army")
	soldier.set_meta("walk_speed", randf_range(100, 180))  # Slightly faster so they keep up
	soldier.set_meta("on_tunnel", is_tun)
	soldier.set_meta("jump_time", 0.0)  # Pre-set so _process_background_army never fails
	_add_to_level(soldier)
	# Bobbing animation handled procedurally in _process_background_army (no looping tween)

	# Stage 5: occasional allied tank
	if current_stage == 5 and randf() < 0.25:
		_add_allied_tank(x - randf_range(100, 300), y)

func _add_allied_tank(x: float, y: float) -> void:
	var tank_count = 0
	for s in get_tree().get_nodes_in_group("ally_army"):
		if s.has_meta("is_tank"):
			tank_count += 1
			if abs(s.position.x - x) < 800: return # Keep them spread out
			
	if tank_count >= 2: return # Limit total allied tanks on screen

	var tank = Node2D.new()
	tank.position = Vector2(x, y)
	tank.z_index = 3 # In front of props but slightly behind soldiers
	
	# T-54 Tank Body
	var body = Polygon2D.new()
	body.polygon = PackedVector2Array([Vector2(-60, 0), Vector2(-50, -40), Vector2(50, -40), Vector2(60, 0)])
	body.color = Color(0.1, 0.35, 0.1) # Viet Cong Green
	tank.add_child(body)
	
	var turret = Polygon2D.new()
	turret.polygon = PackedVector2Array([Vector2(-30, -40), Vector2(-15, -65), Vector2(15, -65), Vector2(20, -40)])
	turret.color = Color(0.08, 0.28, 0.08)
	tank.add_child(turret)
	
	var barrel = ColorRect.new()
	barrel.size = Vector2(70, 8); barrel.position = Vector2(10, -58); barrel.color = Color(0.05, 0.15, 0.05)
	tank.add_child(barrel)
	
	# Yellow Star
	var star = Polygon2D.new(); var pts = []
	for j in 10:
		var r = 12 if j % 2 == 0 else 5
		pts.append(Vector2(cos(j*TAU/10 - PI/2)*r, sin(j*TAU/10 - PI/2)*r))
	star.polygon = PackedVector2Array(pts); star.color = Color.YELLOW; star.position = Vector2(5, -50)
	tank.add_child(star)

	tank.add_to_group("ally_army")
	tank.set_meta("walk_speed", randf_range(150, 220)) # Slower than some soldiers, faster than others
	tank.set_meta("is_tank", true) 
	
	# Slight bobbing to simulate treads
	var tw = create_tween().set_loops()
	tw.tween_property(tank, "rotation", deg_to_rad(-1.5), 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(tank, "rotation", deg_to_rad(1.5), 0.25).set_trans(Tween.TRANS_SINE)

	_add_to_level(tank)

func _process_background_army(delta: float) -> void:
	var tree = get_tree()
	if not tree: return
	var army_nodes = tree.get_nodes_in_group("ally_army")
	var cam_pos = camera.position
	
	for idx_a in range(army_nodes.size()):
		var soldier = army_nodes[idx_a]
		if not is_instance_valid(soldier): continue
		
		var cam_x = cam_pos.x
		var dist_to_cam = soldier.position.x - cam_x
		var leg_h = 0.0
		
		# --- Boundary checks FIRST (before any skip) ---
		# Too far behind the left edge: remove
		if dist_to_cam < -630:  # Just past left edge of screen (576px + buffer)
			soldier.queue_free()
			continue
		
		# Too far ahead (past right edge): remove
		if dist_to_cam > 620:  # Just past right edge of screen
			soldier.queue_free()
			continue
		
		# Skip animation/movement for distant units (performance)
		if (idx_a + _perf_frame) % 2 != 0: continue
		
		if not soldier.has_meta("walk_speed"): continue
		var base_speed = soldier.get_meta("walk_speed")
		soldier.position.x += base_speed * delta * 2.0
		
		# --- Procedural Animation ---
		var is_tank = soldier.has_meta("is_tank")
		if not is_tank:
			var walk_time = (Time.get_ticks_msec() / 1000.0) * 12.0 + float(soldier.get_instance_id() % 100)
			var step = sin(walk_time)
			var s_body = soldier.get_child(0) if soldier.get_child_count() > 0 else null
			if s_body:
				s_body.position.y = abs(step) * -4.0
				s_body.rotation = step * 0.04
			
			var s_leg_l = soldier.get_node_or_null("LegL"); var s_leg_r = soldier.get_node_or_null("LegR")
			if s_leg_l and s_leg_r:
				s_leg_l.position.x = -3 + step * 8.5
				s_leg_r.position.x = 3 - step * 8.5
				s_leg_l.rotation = step * 0.18
				s_leg_r.rotation = -step * 0.18
		
		# Ground snapping
		var is_tunnel_soldier = soldier.has_meta("on_tunnel") and soldier.get_meta("on_tunnel")
		if not is_tunnel_soldier:
			var tx = soldier.position.x
			var current_ground_y = _get_ground_y(tx)
			leg_h = 0.0 if is_tank else 16.0
			var target_y = current_ground_y - leg_h
			
			var jump_time = soldier.get_meta("jump_time", 0.0)
			var jump_offset = 0.0
			if jump_time > 0:
				jump_time -= delta * 3.0
				jump_offset = sin((1.0 - jump_time) * PI) * 60.0
				if jump_time <= 0: jump_time = 0
			else:
				# Check ahead for jumping up ledges
				if _get_ground_y(tx + 80.0) < target_y - 25.0:
					jump_time = 1.0
			
			soldier.set_meta("jump_time", jump_time)
			var final_target = target_y - jump_offset
			if soldier.position.y > target_y + 30:
				soldier.position.y = target_y
			else:
				var follow_speed = 12.0 if soldier.position.y < target_y else 25.0
				soldier.position.y = lerp(soldier.position.y, final_target, follow_speed * delta * 2.0)

func _spawn_heavy_enemy(x, y, type: String, is_ally: bool = false, can_shoot: bool = true) -> void:
	var e = null
	if type == "tank":
		e = CharacterBody2D.new()
		e.set_script(TANK_SCENE)
		e.is_ally = is_ally
		e.can_shoot = can_shoot
		e.add_to_group("tank")
		e.z_index = 5 # Ensure tanks are visible over terrain props
		if is_ally: e.patrol_direction = 1 # Face right
	
	if e:
		_add_to_level(e)
		e.position = Vector2(x, y)

func screen_shake(p, t) -> void:
	_shake_power = p
	_shake_time = t

func refresh_heavy_weapon(cooldown: float, _max_cooldown: float) -> void:
	var cd_bar  = get_node_or_null("UI/HUDPanel/B40CoolBar")
	var cd_lbl  = get_node_or_null("UI/HUDPanel/B40CDLabel")
	# Legacy fallback: lazy-create old box if HUDPanel not found
	if not cd_lbl and not has_node("UI/HeavyWeaponBox"):
		var box = Node2D.new(); box.name = "HeavyWeaponBox"; box.position = Vector2(250, 45); $UI.add_child(box)
		var bg = ColorRect.new(); bg.size = Vector2(60, 40); bg.color = Color(0,0,0,0.5); box.add_child(bg)
		var icon = Label.new(); icon.text = "B40"; icon.position = Vector2(5, 2); icon.add_theme_font_size_override("font_size", 12); box.add_child(icon)
		var lbl2 = Label.new(); lbl2.name = "CDLabel"; lbl2.position = Vector2(5, 18); lbl2.add_theme_font_size_override("font_size", 16); box.add_child(lbl2)
	if not cd_lbl: cd_lbl = get_node_or_null("UI/HeavyWeaponBox/CDLabel")

	if is_instance_valid(cd_bar):
		cd_bar.max_value = _max_cooldown
		cd_bar.value = _max_cooldown - cooldown  # bar fills up as cooldown counts down
	if is_instance_valid(cd_lbl):
		if cooldown > 0:
			cd_lbl.text = "%.1fs" % cooldown
			cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
		else:
			cd_lbl.text = "SẴN SÀNG"
			cd_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))

func on_player_die():
	# FIX: call_deferred to avoid physics state changes during collision callbacks
	call_deferred("_start_stage", current_stage, true)

func on_stage_complete():
	if is_game_over: return  # FIX: prevent double-firing if player lingers at boundary
	if current_stage == 5:
		_show_victory()
	else:
		# --- EPIC STAGE VICTORY UI ---
		is_game_over = true # Stop enemy spawning/bombers
		
		var vic_title = Label.new()
		vic_title.text = "CHIẾN THẮNG!"
		vic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vic_title.add_theme_font_size_override("font_size", 60)
		vic_title.add_theme_color_override("font_color", Color.YELLOW)
		vic_title.add_theme_constant_override("outline_size", 10)
		vic_title.add_theme_color_override("font_outline_color", Color.DARK_RED)
		vic_title.size = Vector2(1152, 200); vic_title.position = Vector2(0, 200)
		$UI.add_child(vic_title)
		
		var sub = Label.new()
		sub.text = "NHIỆM VỤ HOÀN THÀNH - CHUẨN BỊ CHO CHIẾN DỊCH TIẾP THEO"
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.size = Vector2(1152, 50); sub.position = Vector2(0, 320)
		sub.add_theme_font_size_override("font_size", 18); sub.add_theme_color_override("font_color", Color.WHITE)
		$UI.add_child(sub)
		
		PlayerData.unlock_next_stage()
		var tree = get_tree()
		if tree:
			await tree.create_timer(3.5).timeout
			tree.change_scene_to_file("res://scenes/level_select.tscn")


func flash_damage() -> void:
	if not is_instance_valid(_damage_vignette): return
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_damage_vignette, "color:a", 0.38, 0.05)
	tw.tween_property(_damage_vignette, "color:a", 0.0,  0.35).set_delay(0.05)

func show_alert(msg: String, duration: float = 2.5) -> void:
	# Create or reuse the alert panel
	if not is_instance_valid(_alert_panel):
		_alert_panel = Panel.new()
		_alert_panel.name = "AlertPanel"
		_alert_panel.size = Vector2(520, 58)
		_alert_panel.position = Vector2((1152 - 520) * 0.5, 175)
		_alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_alert_panel.z_index = 95
		var sty := StyleBoxFlat.new()
		sty.bg_color = Color(0.05, 0.10, 0.04, 0.93)
		sty.border_color = Color(0.84, 0.72, 0.22)
		sty.border_width_left = 2; sty.border_width_right  = 2
		sty.border_width_top  = 2; sty.border_width_bottom = 2
		sty.set_corner_radius_all(8)
		_alert_panel.add_theme_stylebox_override("panel", sty)
		var al: Label = Label.new()
		al.name = "AlertText"
		al.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		al.add_theme_font_size_override("font_size", 20)
		al.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
		al.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		al.add_theme_constant_override("shadow_offset_x", 2)
		al.add_theme_constant_override("shadow_offset_y", 2)
		_alert_panel.add_child(al)
		$UI.add_child(_alert_panel)
		_alert_panel.modulate.a = 0.0
	var text_lbl: Node = _alert_panel.get_node_or_null("AlertText")
	if text_lbl is Label: (text_lbl as Label).text = msg
	_alert_panel.scale = Vector2(0.6, 0.6)
	_alert_panel.pivot_offset = _alert_panel.size * 0.5
	var tw: Tween = create_tween()
	tw.tween_property(_alert_panel, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(_alert_panel, "scale", Vector2(1.05, 1.05), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_alert_panel, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(duration)
	tw.tween_property(_alert_panel, "modulate:a", 0.0, 0.3)

func _show_victory() -> void:
	is_game_over = true
	var tree: SceneTree = get_tree()
	if tree:
		for n in tree.get_nodes_in_group("enemy"): n.queue_free()

	# Dark overlay fade-in
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.size = Vector2(1152, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 96
	$UI.add_child(overlay)
	var ov_tw: Tween = create_tween()
	ov_tw.tween_property(overlay, "color:a", 0.65, 1.2).set_trans(Tween.TRANS_SINE)

	# Main title — bounce-in after 0.3s
	var vic_label := Label.new()
	vic_label.text = "GIẢI PHÓNG MIỀN NAM"
	vic_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_label.add_theme_font_size_override("font_size", 54)
	vic_label.add_theme_color_override("font_color", Color.YELLOW)
	vic_label.add_theme_constant_override("outline_size", 12)
	vic_label.add_theme_color_override("font_outline_color", Color.RED)
	vic_label.size = Vector2(1152, 120)
	vic_label.position = Vector2(0, 80)
	vic_label.modulate.a = 0.0
	vic_label.scale = Vector2(0.7, 0.7)
	vic_label.pivot_offset = Vector2(576, 60)
	vic_label.z_index = 97
	$UI.add_child(vic_label)
	var vl_tw: Tween = create_tween()
	vl_tw.tween_interval(0.3)
	vl_tw.tween_property(vic_label, "modulate:a", 1.0, 0.2)
	vl_tw.parallel().tween_property(vic_label, "scale", Vector2(1.1, 1.1), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	vl_tw.tween_property(vic_label, "scale", Vector2(1.0, 1.0), 0.15)

	# Subtitle — slide up from offset
	var sub_lbl := Label.new()
	sub_lbl.text = "30 tháng 4, 1975"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(0.85, 0.78, 0.45))
	sub_lbl.size = Vector2(1152, 50)
	sub_lbl.position = Vector2(0, 245)
	sub_lbl.modulate.a = 0.0
	sub_lbl.z_index = 97
	$UI.add_child(sub_lbl)
	var sl_tw: Tween = create_tween()
	sl_tw.tween_interval(0.65)
	sl_tw.tween_property(sub_lbl, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_EXPO)

	# 3 Polygon2D gold stars below subtitle
	for s_idx: int in 3:
		var star := Polygon2D.new()
		var spts: Array = []
		for j: int in 10:
			var sr: float = 24.0 if j % 2 == 0 else 10.0
			spts.append(Vector2(cos(j * TAU / 10.0 - PI / 2.0) * sr, sin(j * TAU / 10.0 - PI / 2.0) * sr))
		star.polygon = PackedVector2Array(spts)
		star.color = Color(1.0, 0.85, 0.05)
		star.position = Vector2(516.0 + s_idx * 62.0, 315.0)
		star.scale = Vector2.ZERO
		star.z_index = 97
		$UI.add_child(star)
		var s_tw: Tween = create_tween()
		var s_delay: float = 0.8 + s_idx * 0.2
		s_tw.tween_interval(s_delay)
		s_tw.tween_property(star, "scale", Vector2(1.2, 1.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		s_tw.tween_property(star, "scale", Vector2(1.0, 1.0), 0.10)

	var btn := Button.new()
	btn.text = "VỀ MÀN HÌNH CHÍNH"
	btn.size = Vector2(250, 60)
	btn.position = Vector2(451, 370)
	btn.z_index = 97
	btn.pressed.connect(_exit_to_main_menu)
	$UI.add_child(btn)

	
	# === LÁ CỜ MẶT TRẬN GIẢI PHÓNG KÉO LÊN ===
	if current_stage == 5:
		# Cột cờ Dinh Độc Lập
		var flag_pole = ColorRect.new()
		flag_pole.size = Vector2(12, 500)
		flag_pole.position = Vector2(STAGE_LENGTH - 150, 100)
		flag_pole.color = Color(0.7, 0.7, 0.7)
		flag_pole.z_index = -8
		_add_to_level(flag_pole)
		
		# Chân đế cột cờ
		var base_f = ColorRect.new(); base_f.size = Vector2(40, 20); base_f.position = Vector2(STAGE_LENGTH - 164, 600); base_f.color = Color(0.4, 0.4, 0.4); base_f.z_index = -8; _add_to_level(base_f)
		
		# Lá cờ nửa trên đỏ, nửa dưới xanh, sao vàng
		var giant_flag = Node2D.new()
		giant_flag.position = Vector2(STAGE_LENGTH - 144, 450) # Cờ bắt đầu kéo ở dưới
		giant_flag.z_index = -7
		_add_to_level(giant_flag)
		
		var red_half = ColorRect.new(); red_half.size = Vector2(240, 75); red_half.color = Color(0.85, 0.15, 0.15); giant_flag.add_child(red_half)
		var blue_half = ColorRect.new(); blue_half.size = Vector2(240, 75); blue_half.position = Vector2(0, 75); blue_half.color = Color(0.1, 0.4, 0.85); giant_flag.add_child(blue_half)
		
		var big_star = Polygon2D.new(); var s_pts = []
		for j in 10:
			var sr = 42 if j%2==0 else 16
			s_pts.append(Vector2(cos(j*TAU/10-PI/2)*sr, sin(j*TAU/10-PI/2)*sr))
		big_star.polygon = PackedVector2Array(s_pts); big_star.color = Color.YELLOW; big_star.position = Vector2(120, 75)
		giant_flag.add_child(big_star)
		
		# Anime kéo cờ từ từ lên đỉnh cột
		var tw_flag = create_tween()
		tw_flag.tween_property(giant_flag, "position:y", 100, 3.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		
		# Hiệu ứng cờ bay phấp phới trong gió
		var wave_tw = create_tween().set_loops()
		wave_tw.tween_property(giant_flag, "scale:y", 0.95, 0.2)
		wave_tw.tween_property(giant_flag, "scale:y", 1.05, 0.2)
	
	# Victory SFX and slow mo
	Engine.time_scale = 0.5
	screen_shake(15.0, 2.0)
	
	# Spawn victory particles (fireworks)
	if tree:
		for i in 20:
			var delay = i * 0.15
			tree.create_timer(delay).timeout.connect(_spawn_firework)
	
		await tree.create_timer(6.0).timeout
		Engine.time_scale = 1.0
		tree.change_scene_to_file("res://scenes/menu.tscn")
	else:
		Engine.time_scale = 1.0

func _spawn_firework() -> void:
	var colors := [Color(1.0,0.15,0.1), Color(1.0,0.85,0.0), Color(0.2,0.9,0.3), Color(0.2,0.7,1.0), Color(1.0,0.4,0.9)]
	var cx := camera.global_position.x + randf_range(-420, 420)
	var cy := camera.global_position.y + randf_range(-230, 80)
	var fc: Color = colors.pick_random()
	# Burst: 12 spark particles radiating outward
	for i in 12:
		var spark := Polygon2D.new()
		var spts := PackedVector2Array()
		for k in 8:
			var a := k * TAU / 8.0
			spts.append(Vector2(cos(a) * 5, sin(a) * 5))
		spark.polygon = spts
		spark.color = fc
		spark.position = Vector2(cx, cy)
		add_child(spark)
		var angle := i * TAU / 12.0
		var dist  := randf_range(60.0, 180.0)
		var end_pos := Vector2(cx + cos(angle) * dist, cy + sin(angle) * dist)
		var tw := spark.create_tween().set_parallel(true)
		tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(spark, "position", end_pos, 0.55)
		tw.tween_property(spark, "modulate:a", 0.0, 0.55)
		tw.tween_property(spark, "scale", Vector2(0.3, 0.3), 0.55)
		tw.finished.connect(spark.queue_free)
	# Central flash
	var flash := Polygon2D.new()
	var fpts := PackedVector2Array()
	for k in 16:
		var a := k * TAU / 16.0
		fpts.append(Vector2(cos(a) * 22, sin(a) * 22))
	flash.polygon = fpts; flash.color = fc; flash.position = Vector2(cx, cy)
	add_child(flash)
	var ftw := flash.create_tween().set_parallel(true)
	ftw.tween_property(flash, "scale", Vector2(3.0, 3.0), 0.3)
	ftw.tween_property(flash, "modulate:a", 0.0, 0.3)
	ftw.finished.connect(flash.queue_free)

func _setup_cheat_menu() -> void:
	_cheat_menu = Control.new()
	_cheat_menu.name = "CheatMenu"
	_cheat_menu.visible = false
	_cheat_menu.z_index = 1000
	$UI.add_child(_cheat_menu)
	
	var bg = ColorRect.new()
	bg.size = Vector2(400, 500)
	bg.position = Vector2(376, 110)
	bg.color = Color(0, 0, 0, 0.85)
	_cheat_menu.add_child(bg)
	
	var title = Label.new()
	title.text = "GIAO DIỆN KIỂM THỬ (CHEAT)"
	title.position = Vector2(400, 130)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.YELLOW)
	_cheat_menu.add_child(title)
	
	var btn_v = VBoxContainer.new()
	btn_v.size = Vector2(360, 400)
	btn_v.position = Vector2(396, 170)
	btn_v.add_theme_constant_override("separation", 15)
	_cheat_menu.add_child(btn_v)
	
	var cheats = [
		{"id": "god", "name": "BẤT TỬ (GOD MODE)", "fn": _cheat_god_mode},
		{"id": "ammo", "name": "VÔ HẠN ĐẠN (INF AMMO)", "fn": _cheat_inf_ammo},
		{"id": "hp", "name": "HỒI ĐẦY MÁU", "fn": _cheat_heal},
		{"id": "s2", "name": "NHẢY ĐẾN MÀN 2", "fn": func(): call_deferred("_start_stage", 2); _toggle_cheat_menu()},
		{"id": "s3", "name": "NHẢY ĐẾN MÀN 3", "fn": func(): call_deferred("_start_stage", 3); _toggle_cheat_menu()},
		{"id": "s4", "name": "NHẢY ĐẾN MÀN 4", "fn": func(): call_deferred("_start_stage", 4); _toggle_cheat_menu()},
		{"id": "s5", "name": "NHẢY ĐẾN MÀN 5", "fn": func(): call_deferred("_start_stage", 5); _toggle_cheat_menu()},
		{"id": "tank", "name": "GỌI XE TĂNG CHIẾN ĐẤU", "fn": _cheat_spawn_tank},
		{"id": "speed", "name": "SIÊU TỐC ĐỘ", "fn": _cheat_speed},
	]
	
	for c in cheats:
		var b = Button.new()
		b.name = "Btn_" + c["id"]
		b.text = c["name"]
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(c["fn"])
		btn_v.add_child(b)
	
	# CRITICAL: Allow cheat menu to process even when the game is paused
	_cheat_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS

func _setup_pause_button() -> void:
	var btn := Button.new()
	btn.name = "PauseBtn"
	btn.text = "⏸"
	btn.position = Vector2(1094, 8)
	btn.size = Vector2(50, 50)
	btn.z_index = 100
	btn.process_mode = PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(0.95, 0.88, 0.30))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.4))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.06, 0.12, 0.05, 0.7)
	sn.border_color = Color(0.82, 0.70, 0.18, 0.8)
	sn.border_width_left = 2; sn.border_width_right = 2
	sn.border_width_top = 2; sn.border_width_bottom = 2
	sn.set_corner_radius_all(8)
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.12, 0.22, 0.08, 0.9)
	sh.border_color = Color(1.0, 0.9, 0.3)
	btn.add_theme_stylebox_override("normal", sn)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.pressed.connect(func():
		if not _is_cheat_visible:
			_toggle_pause_menu()
	)
	$UI.add_child(btn)

func _setup_pause_menu() -> void:
	_pause_menu = Control.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.visible = false
	_pause_menu.process_mode = PROCESS_MODE_ALWAYS
	_pause_menu.anchor_right = 1.0; _pause_menu.anchor_bottom = 1.0
	_pause_menu.offset_right = 1152; _pause_menu.offset_bottom = 720
	$UI.add_child(_pause_menu)

	_setup_history_panel()

	# ── Màn nền mờ ──────────────────────────────────────────────────────────
	var dim_bg := ColorRect.new()
	dim_bg.size = Vector2(1152, 720)
	dim_bg.color = Color(0.0, 0.04, 0.0, 0.72)
	_pause_menu.add_child(dim_bg)

	# ── Panel chính: military olive + viền vàng ──────────────────────────────
	var panel := Panel.new()
	panel.name = "MainPanel"
	panel.size = Vector2(380, 360)
	panel.position = Vector2(386, 180)
	var sty := StyleBoxFlat.new()
	sty.bg_color        = Color(0.06, 0.12, 0.05, 0.97)
	sty.border_color    = Color(0.82, 0.70, 0.18)
	sty.border_width_left = 2; sty.border_width_right = 2
	sty.border_width_top  = 2; sty.border_width_bottom = 2
	sty.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", sty)
	_pause_menu.add_child(panel)

	# Thanh tiêu đề vàng ở đỉnh panel
	var title_bar := ColorRect.new()
	title_bar.size = Vector2(380, 44)
	title_bar.color = Color(0.15, 0.22, 0.07, 0.95)
	panel.add_child(title_bar)

	var title_sep := ColorRect.new()
	title_sep.size = Vector2(380, 2); title_sep.position = Vector2(0, 44)
	title_sep.color = Color(0.82, 0.70, 0.18, 0.8)
	panel.add_child(title_sep)

	# Biểu tượng + tiêu đề "⏸  TẠM DỪNG"
	var title := Label.new()
	title.text = "⏸  TẠM DỪNG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.30))
	title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.size = Vector2(380, 44); title.position = Vector2(0, 0)
	panel.add_child(title)

	# Thông tin wave / điểm bên trong panel
	var info_lbl := Label.new()
	info_lbl.name = "PauseInfoLabel"
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_font_size_override("font_size", 13)
	info_lbl.add_theme_color_override("font_color", Color(0.70, 0.82, 0.55))
	info_lbl.size = Vector2(360, 24); info_lbl.position = Vector2(10, 52)
	panel.add_child(info_lbl)

	# ── Nút bấm — tạo với style micro military ──────────────────────────────
	var btn_v := VBoxContainer.new()
	btn_v.size = Vector2(300, 260)
	btn_v.position = Vector2(40, 84)
	btn_v.add_theme_constant_override("separation", 12)
	panel.add_child(btn_v)

	var _mk_pbtn := func(txt: String) -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(0, 48)
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_color", Color(0.90, 0.86, 0.55))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.2))
		b.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(0.10, 0.18, 0.06, 0.92); sn.border_color = Color(0.55, 0.48, 0.12)
		sn.border_width_left = 1; sn.border_width_right = 1
		sn.border_width_top  = 1; sn.border_width_bottom = 1
		sn.set_corner_radius_all(5)
		var sh := sn.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.16, 0.30, 0.10, 0.96); sh.border_color = Color(0.82, 0.70, 0.18)
		var sp := sn.duplicate() as StyleBoxFlat
		sp.bg_color = Color(0.06, 0.10, 0.04, 0.96)
		b.add_theme_stylebox_override("normal",  sn)
		b.add_theme_stylebox_override("hover",   sh)
		b.add_theme_stylebox_override("pressed", sp)
		return b

	var btn_resume: Button = _mk_pbtn.call("▶  TIẾP TỤC  [ESC]")
	btn_resume.process_mode = PROCESS_MODE_ALWAYS
	btn_resume.pressed.connect(_toggle_pause_menu)
	btn_v.add_child(btn_resume)

	var btn_history: Button = _mk_pbtn.call("📖  LỊCH SỬ CHIẾN DỊCH")
	btn_history.process_mode = PROCESS_MODE_ALWAYS
	btn_history.pressed.connect(func(): _show_history_info())
	btn_v.add_child(btn_history)

	var btn_settings: Button = _mk_pbtn.call("⚙  CÀI ĐẶT")
	btn_settings.process_mode = PROCESS_MODE_ALWAYS
	btn_settings.pressed.connect(func(): _show_settings_from_pause())
	btn_v.add_child(btn_settings)

	var btn_exit: Button = _mk_pbtn.call("✖  THOÁT RA MENU")
	btn_exit.process_mode = PROCESS_MODE_ALWAYS
	btn_exit.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	btn_exit.pressed.connect(_exit_to_main_menu)
	btn_v.add_child(btn_exit)

func _setup_history_panel() -> void:
	_history_panel = ColorRect.new()
	_history_panel.name = "HistoryPanel"
	_history_panel.visible = false
	_history_panel.size = Vector2(850, 580)
	# Reliable manual centering
	_history_panel.position = Vector2(151, 70) 
	_history_panel.color = Color(0.08, 0.08, 0.08, 1.0) # Full opaque
	_history_panel.z_index = 2500
	_history_panel.process_mode = PROCESS_MODE_ALWAYS
	$UI.add_child(_history_panel)
	
	# Border
	var border = ReferenceRect.new()
	border.size = _history_panel.size
	border.editor_only = false
	border.border_color = Color(0.8, 0.7, 0.2, 0.8)
	border.border_width = 3.0
	_history_panel.add_child(border)
	
	var content_v = VBoxContainer.new()
	content_v.name = "ContentV"
	content_v.anchor_left = 0.0; content_v.anchor_right = 1.0
	content_v.anchor_top = 0.0; content_v.anchor_bottom = 1.0
	content_v.offset_left = 40; content_v.offset_right = -40
	content_v.offset_top = 30; content_v.offset_bottom = -30
	content_v.add_theme_constant_override("separation", 20)
	_history_panel.add_child(content_v)
	
	var h_title = Label.new()
	h_title.name = "HTitle"
	h_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h_title.add_theme_font_size_override("font_size", 28)
	h_title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	content_v.add_child(h_title)
	
	var h_separator = ColorRect.new()
	h_separator.custom_minimum_size = Vector2(600, 2)
	h_separator.color = Color(0.4, 0.4, 0.4)
	content_v.add_child(h_separator)
	
	var h_scroll = ScrollContainer.new()
	h_scroll.custom_minimum_size = Vector2(640, 300)
	content_v.add_child(h_scroll)
	
	var h_text_lbl = Label.new()
	h_text_lbl.name = "HDescription"
	h_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h_text_lbl.custom_minimum_size = Vector2(620, 0)
	h_text_lbl.add_theme_font_size_override("font_size", 18)
	h_text_lbl.add_theme_constant_override("line_spacing", 8)
	h_scroll.add_child(h_text_lbl)
	
	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(1, 10); content_v.add_child(spacer)
	
	var close_btn = Button.new()
	close_btn.text = "ĐÓNG LẠI"
	close_btn.custom_minimum_size = Vector2(200, 50)
	close_btn.pressed.connect(_close_history)
	content_v.add_child(close_btn)
	content_v.set_alignment(BoxContainer.ALIGNMENT_CENTER)

func _show_history_info() -> void:
	var h_data = [
		{
			"title": "MÀN 1: CHIẾN DỊCH TÂY NGUYÊN (04/03 - 03/04/1975)",
			"desc": "Đây là đòn then chốt chiến lược mở đầu cuộc Tổng tiến công và nổi dậy Xuân 1975. Quân Giải phóng đã bí mật tập trung lực lượng lớn, bất ngờ tấn công đánh chiếm thị xã Buôn Ma Thuột - yết hầu của Tây Nguyên.\n\nSự kiện then chốt này đã làm rung chuyển toàn bộ hệ thống phòng thủ của đối phương, buộc họ phải rút quân hỗn loạn khỏi vùng Tây Nguyên, tạo đà thắng lợi thần tốc cho chiến dịch giải phóng hoàn toàn miền Nam."
		},
		{
			"title": "MÀN 2: CHIẾN DỊCH CEDAR FALLS (08/01 - 26/01/1967)",
			"desc": "Cuộc hành quân quy mô lớn nhất của quân đội Mỹ nhằm xóa sổ 'Tam giác sắt' Củ Chi - cửa ngõ quan trọng dẫn vào Sài Gòn. Mỹ đã sử dụng xe ủi, bom napalm và các đội 'Chuột cống' để phá hủy địa đạo.\n\nTuy nhiên, dựa vào mạng lưới địa đạo chằng chịt dài hàng trăm km, quân và dân Củ Chi đã kiên cường bám trụ, sử dụng lối đánh du kích, cài bẫy chông và mìn tự chế để đẩy lùi quân đoàn khổng lồ của Mỹ, biến nơi đây thành 'vùng đất thép'."
		},
		{
			"title": "MÀN 3: CHIẾN DỊCH ĐƯỜNG 9 - NAM LÀO (08/02 - 23/03/1971)",
			"desc": "Trận chiến ác liệt nhằm bảo vệ Đường Trường Sơn - tuyến đường huyết mạch tiếp tế lửa đạn cho miền Nam. Quân lực Sài Gòn huy động lực lượng tinh nhuệ hòng cắt đứt tuyến đường nhưng đã bị chặn đứng hoàn toàn.\n\nChiến thắng này khẳng định sự lớn mạnh của quân đội dân tộc, bảo vệ vững chắc con đường huyền thoại giúp vận chuyển hàng vạn tấn vũ khí, lương thực tiến về phía Nam."
		},
		{
			"title": "MÀN 4: CHIẾN DỊCH XUÂN LỘC (09/04 - 20/04/1975)",
			"desc": "Trận chiến tại Xuân Lộc được mệnh danh là 'Cánh cửa thép' cuối cùng bảo vệ thủ đô Sài Gòn. Đây là nơi diễn ra những màn đọ pháo và đấu tăng dữ dội nhất thềm kết thúc chiến tranh.\n\nSau 12 ngày đêm chiến đấu không ngừng nghỉ, bằng lòng quả cảm và chiến thuật linh hoạt, quân giải phóng đã đập tan phòng tuyến cuối cùng, mở toang đại lộ giải phóng tiến về Sài Gòn."
		},
		{
			"title": "MÀN 5: CHIẾN DỊCH HỒ CHÍ MINH (26/04 - 30/04/1975)",
			"desc": "Chiến dịch vĩ đại nhất trong lịch sử dân tộc. 5 cánh quân từ các hướng đồng loạt tiến công vào trung tâm Sài Gòn.\n\n- 11h30 ngày 30/04: Xe tăng 390 húc đổ cổng Dinh Độc Lập.\n- Đại diện chính quyền Sài Gòn tuyên bố đầu hàng không điều kiện.\n- Lá cờ Giải phóng tung bay trên nóc dinh, kết thúc 21 năm kháng chiến chống Mỹ, thống nhất hoàn toàn đất nước."
		}
	]
	
	var hist_data = h_data[current_stage - 1] if current_stage <= h_data.size() else h_data[0]
	var h_t = _history_panel.find_child("HTitle", true, false)
	var h_d = _history_panel.find_child("HDescription", true, false)
	if h_t: h_t.text = hist_data["title"]
	if h_d: h_d.text = hist_data["desc"]
	_history_panel.visible = true
	
	# Hide main pause buttons to focus on history
	var p_main = _pause_menu.get_node_or_null("MainPanel")
	if p_main: p_main.visible = false

func _show_settings_from_pause() -> void:
	# Build a lightweight settings popup similar to menu's SettingsPopup
	var ui = get_node_or_null("UI")
	if not ui: return
	# If popup already exists, bring to front
	var existing = ui.get_node_or_null("SettingsPopup")
	if existing:
		ui.move_child(existing, -1)
		existing.show()
		var p_main2 = _pause_menu.get_node_or_null("MainPanel")
		if p_main2: p_main2.visible = false
		return

	var popup = Control.new()
	popup.name = "SettingsPopup"
	popup.visible = true
	# Ensure popup receives input while the game is paused
	popup.process_mode = PROCESS_MODE_ALWAYS
	popup.size = Vector2(1152, 720)
	ui.add_child(popup)
	ui.move_child(popup, -1)

	var dim = ColorRect.new()
	dim.size = popup.size
	dim.color = Color(0, 0, 0, 0.75)
	popup.add_child(dim)

	var bg_panel = Panel.new()
	bg_panel.size = Vector2(500, 370)
	bg_panel.position = (popup.size - bg_panel.size) * 0.5
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.1, 0.15, 0.08, 0.98)
	sbox.border_color = Color(0.84, 0.72, 0.22)
	sbox.border_width_left = 2; sbox.border_width_right = 2
	sbox.border_width_top = 2; sbox.border_width_bottom = 2
	sbox.set_corner_radius_all(10)
	bg_panel.add_theme_stylebox_override("panel", sbox)
	popup.add_child(bg_panel)

	var title = Label.new()
	title.text = "⚙  CÀI ĐẶT"
	title.position = Vector2(20, 20)
	title.size = Vector2(460, 40)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.84, 0.72, 0.22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg_panel.add_child(title)

	var sep = ColorRect.new()
	sep.position = Vector2(40, 70)
	sep.size = Vector2(420, 2)
	sep.color = Color(0.84, 0.72, 0.22, 0.5)
	bg_panel.add_child(sep)

	var content_vbox = VBoxContainer.new()
	content_vbox.position = Vector2(40, 90)
	content_vbox.size = Vector2(420, 200)
	content_vbox.add_theme_constant_override("separation", 20)
	bg_panel.add_child(content_vbox)

	# Volume Row
	var vol_row = HBoxContainer.new()
	var vol_lbl = Label.new(); vol_lbl.text = "Nhạc nền "; vol_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88)); vol_lbl.add_theme_font_size_override("font_size", 20); vol_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vol_slider = HSlider.new(); vol_slider.name = "VolumeSlider"; vol_slider.custom_minimum_size = Vector2(160, 32); vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER; vol_slider.min_value = 0.0; vol_slider.max_value = 100.0; vol_slider.value = PlayerData.volume * 100.0
	var vol_val_btn = Button.new(); vol_val_btn.name = "VolumeValueLabel"; vol_val_btn.custom_minimum_size = Vector2(52, 0); vol_val_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0)); vol_val_btn.add_theme_font_size_override("font_size", 18); vol_val_btn.text = ("🔊" if PlayerData.music_enabled else "🔇")
	vol_row.add_child(vol_lbl); vol_row.add_child(vol_slider); vol_row.add_child(vol_val_btn)
	content_vbox.add_child(vol_row)

	# SFX Row
	var sfx_row = HBoxContainer.new()
	var sfx_lbl = Label.new(); sfx_lbl.text = "Hiệu ứng âm thanh"; sfx_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88)); sfx_lbl.add_theme_font_size_override("font_size", 20); sfx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sfx_slider = HSlider.new(); sfx_slider.name = "SfxSlider"; sfx_slider.custom_minimum_size = Vector2(160, 32); sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER; sfx_slider.min_value = 0.0; sfx_slider.max_value = 100.0; sfx_slider.value = PlayerData.sfx_volume * 100.0
	var sfx_val_btn = Button.new(); sfx_val_btn.name = "SfxValueLabel"; sfx_val_btn.custom_minimum_size = Vector2(52, 0); sfx_val_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0)); sfx_val_btn.add_theme_font_size_override("font_size", 18); sfx_val_btn.text = ("🔊" if PlayerData.sfx_enabled else "🔇")
	sfx_row.add_child(sfx_lbl); sfx_row.add_child(sfx_slider); sfx_row.add_child(sfx_val_btn)
	content_vbox.add_child(sfx_row)

	# add reset button
	var reset_btn = Button.new(); reset_btn.name = "ResetBtn"; reset_btn.custom_minimum_size = Vector2(220, 42); reset_btn.add_theme_font_size_override("font_size", 18); reset_btn.text = "🗑  XÓA DỮ LIỆU / CHƠI LẠI"; reset_btn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	content_vbox.add_child(reset_btn)

	# Close Button
	var close_btn = Button.new()
	close_btn.text = "ĐÓNG"
	close_btn.size = Vector2(160, 40)
	close_btn.position = Vector2(170, 310)
	close_btn.pressed.connect(_close_settings_popup)
	bg_panel.add_child(close_btn)

	# Handlers
	vol_val_btn.pressed.connect(func():
		Audio.play("button_click")
		PlayerData.music_enabled = not PlayerData.music_enabled
		PlayerData.save_data()
		vol_val_btn.text = ("🔊" if PlayerData.music_enabled else "🔇")
		Audio.refresh_music()
	)
	vol_slider.value_changed.connect(func(val: float):
		PlayerData.volume = val / 100.0
		PlayerData.apply_volume()
		PlayerData.save_data()
	)

	sfx_val_btn.pressed.connect(func():
		Audio.play("button_click")
		PlayerData.sfx_enabled = not PlayerData.sfx_enabled
		PlayerData.save_data()
		sfx_val_btn.text = ("🔊" if PlayerData.sfx_enabled else "🔇")
	)
	sfx_slider.value_changed.connect(func(val: float):
		PlayerData.sfx_volume = val / 100.0
		PlayerData.apply_volume()
		PlayerData.save_data()
	)

	reset_btn.pressed.connect(func():
		Audio.play("button_click")
		PlayerData.reset_data()
		HighScore.reset_scores()
		PlayerData.music_enabled = false
		PlayerData.save_data()
		Audio.refresh_music()
		vol_slider.value = 100.0
	)

	# Hide main pause buttons while settings is visible
	var p_main4 = _pause_menu.get_node_or_null("MainPanel")
	if p_main4: p_main4.visible = false

func _close_history() -> void:
	_history_panel.visible = false
	# Always restore MainPanel visibility
	var p_main = _pause_menu.get_node_or_null("MainPanel")
	if p_main: p_main.visible = true
	# If this was the stage-start history, unpause the game
	if _showing_stage_history:
		_showing_stage_history = false
		get_tree().paused = false

func _close_settings_popup() -> void:
	Audio.play("button_click")
	var ui = get_node_or_null("UI")
	if not ui: return
	var sp = ui.get_node_or_null("SettingsPopup")
	if sp:
		sp.hide()
	var p_main = _pause_menu.get_node_or_null("MainPanel")
	if p_main: p_main.visible = true
	# ensure pause state is preserved
	_is_paused = true
	_update_pause_state()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			if not _is_paused: # Don't open cheat menu if game is paused by PauseMenu
				_toggle_cheat_menu()
		elif event.keycode == KEY_ESCAPE:
			if not _is_cheat_visible: # Don't open pause menu if cheat menu is open
				# If settings popup is open, close it and resume play
				var ui = get_node_or_null("UI")
				if ui:
					var sp = ui.get_node_or_null("SettingsPopup")
					if sp and sp.visible:
						sp.hide()
						var p_main_sp = _pause_menu.get_node_or_null("MainPanel")
						if p_main_sp: p_main_sp.visible = true
						# keep _is_paused as true so game remains paused; just return to pause menu
						_update_pause_state()
						return
				# otherwise toggle pause menu as before
				_toggle_pause_menu()

func _toggle_cheat_menu() -> void:
	_is_cheat_visible = !_is_cheat_visible
	_cheat_menu.visible = _is_cheat_visible
	_update_pause_state()

func _toggle_pause_menu() -> void:
	_is_paused = !_is_paused
	_pause_menu.visible = _is_paused
	if _is_paused:
		# Cập nhật thông tin wave/điểm vào label bên trong pause panel
		var info = get_node_or_null("UI/PauseMenu/MainPanel/PauseInfoLabel")
		if info:
			var titles: Array[String] = ["RỪNG GIÀ", "ĐỊA ĐẠO", "ĐƯỜNG MÒN", "CĂN CỨ ĐỊCH", "SÀI GÒN"]
			var stage_name: String = titles[current_stage - 1] if current_stage <= titles.size() else "MÀN %d" % current_stage
			info.text = "Chiến dịch %d: %s  |  Điểm: %d" % [current_stage, stage_name, score]
	_update_pause_state()

func _update_pause_state() -> void:
	get_tree().paused = _is_cheat_visible or _is_paused

func _exit_to_main_menu() -> void:
	get_tree().paused = false # Must resume before changing scene
	var tree = get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/menu.tscn")

func _cheat_god_mode() -> void:
	if is_instance_valid(player):
		player.is_god_mode = !player.is_god_mode
		var btn = _cheat_menu.find_child("Btn_god", true, false)
		if btn: btn.text = "GOD MODE: " + ("BẬT" if player.is_god_mode else "TẮT")
		ui_label.text = "GOD MODE: " + ("BẬT" if player.is_god_mode else "TẮT")

func _cheat_inf_ammo() -> void:
	if is_instance_valid(player):
		player.is_infinite_ammo = !player.is_infinite_ammo
		var btn = _cheat_menu.find_child("Btn_ammo", true, false)
		if btn: btn.text = "INF AMMO: " + ("BẬT" if player.is_infinite_ammo else "TẮT")
		ui_label.text = "INF AMMO: " + ("BẬT" if player.is_infinite_ammo else "TẮT")

func _cheat_heal() -> void:
	if is_instance_valid(player):
		player.hp = player.max_hp
		player._sync_hp()
		ui_label.text = "ĐÃ HỒI MÁU!"

func _cheat_spawn_tank() -> void:
	if is_instance_valid(player):
		var tank = TANK_SCENE.new()
		tank.is_ally = true
		tank.position = player.position - Vector2(200, 0)
		_add_to_level(tank)

func _cheat_speed() -> void:
	if is_instance_valid(player):
		var is_fast = player.SPEED > 250.0
		player.SPEED = 500.0 if not is_fast else 240.0
		var btn = _cheat_menu.find_child("Btn_speed", true, false)
		if btn: btn.text = "SIÊU TỐC ĐỘ: " + ("BẬT" if !is_fast else "TẮT")

func _create_health_kit(pos: Vector2) -> void:
	var kit = Area2D.new(); kit.position = pos; _add_to_level(kit); kit.z_index = -1
	var col = CollisionShape2D.new(); var shp = CircleShape2D.new(); shp.radius = 30; col.shape = shp; kit.add_child(col)
	var box = ColorRect.new(); box.size = Vector2(30, 30); box.position = Vector2(-15, -15); box.color = Color.WHITE; kit.add_child(box)
	var cross1 = ColorRect.new(); cross1.size = Vector2(20, 6); cross1.position = Vector2(-10, -3); cross1.color = Color.RED; kit.add_child(cross1)
	var cross2 = ColorRect.new(); cross2.size = Vector2(6, 20); cross2.position = Vector2(-3, -10); cross2.color = Color.RED; kit.add_child(cross2)
	
	kit.body_entered.connect(func(body):
		if body.is_in_group("player"):
			if body.hp < body.max_hp:
				body.hp = min(body.hp + 1, body.max_hp)
				body._sync_hp()
				Audio.play("collected_item")
				kit.queue_free()
	)
	# Floating animation
	var tw = create_tween().set_loops()
	tw.tween_property(kit, "position:y", pos.y - 15, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(kit, "position:y", pos.y, 0.8).set_trans(Tween.TRANS_SINE)

func _create_checkpoint(pos: Vector2) -> void:
	var cp = Area2D.new(); cp.position = pos; _add_to_level(cp); cp.z_index = -2
	var col = CollisionShape2D.new(); var shp = RectangleShape2D.new(); shp.size = Vector2(100, 200); col.shape = shp; cp.add_child(col)
	
	# Visual: A red/blue pole that turns yellow when activated
	var pole = ColorRect.new(); pole.size = Vector2(8, 120); pole.position = Vector2(-4, -120); pole.color = Color(0.7, 0.7, 0.7); cp.add_child(pole)
	var flag = ColorRect.new(); flag.size = Vector2(40, 25); flag.position = Vector2(4, -120); flag.color = Color.BLUE; cp.add_child(flag)
	
	cp.body_entered.connect(func(body):
		if body.is_in_group("player") and last_checkpoint_x < pos.x:
			last_checkpoint_x = pos.x
			flag.color = Color.YELLOW # Activated
			ui_label.text = "ĐIỂM LƯU TẠM THỜI (CHECKPOINT)!"
	)
	_checkpoint_positions.append(pos.x)

func _update_checkpoint_ui() -> void:
	if not progress_bar: return
	# Remove old first
	for c in progress_bar.get_children(): c.queue_free()
	
	for cx in _checkpoint_positions:
		var marker = ColorRect.new()
		var ratio = cx / STAGE_LENGTH
		marker.size = Vector2(4, 14)
		marker.position = Vector2(ratio * 400 - 2, -2)
		marker.color = Color(0, 0.8, 1.0, 0.8) # Cyan marker
		progress_bar.add_child(marker)
