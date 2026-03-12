extends Node2D
# main.gd — Entry point: quản lý game state, score, kết nối wave manager

signal game_over_signal

const MAX_HP: int = 5   # giá trị mặc định; có thể thay đổi bởi skin
var max_hp: int = 5

var score: int = 0
var current_wave: int = 0
var is_game_over: bool = false

@onready var wave_manager: Node = $WaveManager
@onready var bullet_container: Node2D = $BulletContainer
@onready var ui_label: Label = $UI/Label
@onready var hp_label: Label = $UI/HPLabel
@onready var weapon_label: Label = $UI/WeaponLabel
@onready var boss_hp_bar: ProgressBar = $UI/BossHPBar
@onready var boss_label: Label = $UI/BossLabel
@onready var alert_label: Label = $UI/AlertLabel
var special_label: Label = null
var skill_label:   Label = null
var _pause_overlay: Control = null
var _is_paused: bool = false
var _prev_cancel: bool = false
var _cam: Camera2D = null
var _shake_power: float = 0.0
var _shake_time:  float = 0.0
@onready var player = $Player

func _ready() -> void:
	get_tree().paused = false
	# Root chạy ALWAYS — chỉ để bắt phím ESC và hiển pause overlay
	process_mode = Node.PROCESS_MODE_ALWAYS
	Audio.stop_menu_music()
	# ── Đặt tất cả node game-world thành PAUSABLE ──────────────────────
	# (Buộc phải gản tường minh vì root là ALWAYS nên con INHERIT sẽ thừa hưởng ALWAYS)
	for child_name in ["Player", "WaveManager", "BulletContainer",
			"EnemySpawner", "AsteroidContainer", "Background"]:
		var n := get_node_or_null(child_name)
		if n: n.process_mode = Node.PROCESS_MODE_PAUSABLE
	# Camera2D for screen shake — position at viewport centre so world origin stays top-left
	_cam = Camera2D.new()
	_cam.name = "MainCamera"
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_cam)
	_cam.position = get_viewport_rect().size * 0.5
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	if wave_manager.has_signal("level_completed"):
		wave_manager.level_completed.connect(_on_level_completed)
	refresh_hp(MAX_HP)
	boss_hp_bar.visible = false
	if boss_label: boss_label.visible = false
	# Tạo label vũ khí đặc biệt nếu chưa có trong scene
	special_label = get_node_or_null("UI/SpecialLabel")
	if special_label == null:
		special_label = Label.new()
		special_label.name = "SpecialLabel"
		special_label.add_theme_font_size_override("font_size", 14)
		special_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		special_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
		special_label.add_theme_constant_override("shadow_offset_x", 1)
		special_label.add_theme_constant_override("shadow_offset_y", 1)
		special_label.position = Vector2(8, 108)
		$UI.add_child(special_label)
	special_label.visible = false
	# Tạo skill label
	skill_label = get_node_or_null("UI/SkillLabel")
	if skill_label == null:
		skill_label = Label.new()
		skill_label.name = "SkillLabel"
		skill_label.add_theme_font_size_override("font_size", 13)
		skill_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
		skill_label.add_theme_constant_override("shadow_offset_x", 1)
		skill_label.add_theme_constant_override("shadow_offset_y", 1)
		skill_label.position = Vector2(8, 130)
		$UI.add_child(skill_label)
	# HUD background panel mờ phía sau các nhãn
	var hud_bg := Panel.new()
	hud_bg.name = "HUDBackground"
	hud_bg.position = Vector2(6, 8)
	hud_bg.size = Vector2(340, 158)
	hud_bg.z_index = -1
	var hud_sty := StyleBoxFlat.new()
	hud_sty.bg_color = Color(0.0, 0.02, 0.08, 0.55)
	hud_sty.border_color = Color(0.15, 0.45, 0.75, 0.45)
	hud_sty.border_width_left = 1
	hud_sty.border_width_right = 1
	hud_sty.border_width_top = 1
	hud_sty.border_width_bottom = 1
	hud_sty.corner_radius_top_left = 6
	hud_sty.corner_radius_top_right = 6
	hud_sty.corner_radius_bottom_left = 6
	hud_sty.corner_radius_bottom_right = 6
	hud_bg.add_theme_stylebox_override("panel", hud_sty)
	$UI.add_child(hud_bg)
	await get_tree().create_timer(1.0).timeout
	_build_pause_overlay()
	start_next_wave()

func _process(delta: float) -> void:
	if is_game_over: return
	# Screen shake decay
	if _shake_time > 0.0:
		_shake_time = maxf(0.0, _shake_time - delta)
		var s := _shake_power * (_shake_time / maxf(0.001, _shake_time + delta))
		if is_instance_valid(_cam):
			_cam.offset = Vector2(randf_range(-s, s), randf_range(-s, s))
		if _shake_time <= 0.0 and is_instance_valid(_cam):
			_cam.offset = Vector2.ZERO
			_shake_power = 0.0
	var pressed := Input.is_action_pressed("ui_cancel")
	if pressed and not _prev_cancel:
		_toggle_pause()
	_prev_cancel = pressed

func _toggle_pause() -> void:
	_is_paused = not _is_paused
	get_tree().paused = _is_paused
	if is_instance_valid(_pause_overlay):
		_pause_overlay.visible = _is_paused

func _build_pause_overlay() -> void:
	# Container luôn xử lý ngay cả khi game pause
	_pause_overlay = Control.new()
	_pause_overlay.name            = "PauseOverlay"
	_pause_overlay.process_mode    = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.anchor_right    = 1.0
	_pause_overlay.anchor_bottom   = 1.0
	_pause_overlay.visible         = false
	$UI.add_child(_pause_overlay)

	# Nền mờ
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.06, 0.72)
	_pause_overlay.add_child(bg)

	# Panel trung tâm
	var vp_size := get_viewport().get_visible_rect().size
	var panel_w: float = 280.0
	var panel_h: float = 220.0
	var panel := Panel.new()
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	panel.size     = Vector2(panel_w, panel_h)
	var sty := StyleBoxFlat.new()
	sty.bg_color            = Color(0.04, 0.04, 0.14, 0.94)
	sty.border_color        = Color(0.3, 0.7, 1.0, 0.85)
	sty.border_width_left   = 2
	sty.border_width_right  = 2
	sty.border_width_top    = 2
	sty.border_width_bottom = 2
	sty.corner_radius_top_left     = 8
	sty.corner_radius_top_right    = 8
	sty.corner_radius_bottom_left  = 8
	sty.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", sty)
	_pause_overlay.add_child(panel)

	# Tiêu đề PAUSED
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(panel_w, 48)
	title.position = Vector2(0, 22)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.4, 0.8, 0.7))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(title)

	# Nút Tiếp tục
	var btn_resume := _make_pause_btn("Tiếp tục  [ESC]", Vector2(30, 88), panel_w - 60)
	panel.add_child(btn_resume)
	btn_resume.pressed.connect(_toggle_pause)

	# Nút Về Menu
	var btn_menu := _make_pause_btn("Về Menu chính", Vector2(30, 148), panel_w - 60)
	panel.add_child(btn_menu)
	btn_menu.pressed.connect(_on_pause_menu_pressed)

func _make_pause_btn(txt: String, pos: Vector2, w: float) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = pos
	btn.size     = Vector2(w, 44)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color",         Color(0.95, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(0.3, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.4))
	var sty_n := StyleBoxFlat.new()
	sty_n.bg_color          = Color(0.08, 0.12, 0.28, 0.9)
	sty_n.border_color      = Color(0.25, 0.55, 0.85, 0.7)
	sty_n.border_width_left   = 1
	sty_n.border_width_right  = 1
	sty_n.border_width_top    = 1
	sty_n.border_width_bottom = 1
	sty_n.corner_radius_top_left     = 5
	sty_n.corner_radius_top_right    = 5
	sty_n.corner_radius_bottom_left  = 5
	sty_n.corner_radius_bottom_right = 5
	var sty_h := sty_n.duplicate() as StyleBoxFlat
	sty_h.bg_color     = Color(0.12, 0.28, 0.55, 0.95)
	sty_h.border_color = Color(0.4, 0.85, 1.0, 1.0)
	var sty_p := sty_n.duplicate() as StyleBoxFlat
	sty_p.bg_color = Color(0.05, 0.08, 0.18, 0.9)
	btn.add_theme_stylebox_override("normal",   sty_n)
	btn.add_theme_stylebox_override("hover",    sty_h)
	btn.add_theme_stylebox_override("pressed",  sty_p)
	return btn

func _on_pause_menu_pressed() -> void:
	get_tree().paused = false
	_is_paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

func start_next_wave() -> void:
	current_wave += 1
	# Kiểm tra giới hạn wave của level
	var max_w: int = PlayerData.current_level.get("max_waves", 999)
	if current_wave > max_w:
		_on_level_completed()
		return
	refresh_ui()
	wave_manager.start_wave(current_wave)

func _on_wave_cleared() -> void:
	await get_tree().create_timer(2.0).timeout
	if not is_game_over:
		start_next_wave()

func _on_level_completed() -> void:
	if is_game_over: return
	is_game_over = true
	hide_boss_hp()
	Audio.play("level_complete")
	# Thưởng coin theo độ khó
	var diff: int = PlayerData.current_level.get("difficulty", 1)
	var earned_coins: int = 20 * diff
	PlayerData.add_coins(earned_coins)
	HighScore.save_score(score, current_wave)
	# Lưu kết quả để hiển thị màn hoàn thành
	PlayerData.last_score        = score
	PlayerData.last_coins_earned = earned_coins
	PlayerData.last_wave         = current_wave
	PlayerData.last_hp           = player.hp if is_instance_valid(player) else 0
	PlayerData.last_max_hp       = player._max_hp if is_instance_valid(player) else 1
	# Cập nhật tiến trình phiên chơi
	if PlayerData.current_level.get("is_special", false):
		# Hoàn thành màn đặc biệt → reset phiên
		PlayerData.session_levels_completed = 0
	else:
		PlayerData.session_levels_completed += 1
		var _lidx: int = PlayerData.current_level.get("level_idx", -1)
		if _lidx >= 0 and not PlayerData.session_completed_indices.has(_lidx):
			PlayerData.session_completed_indices.append(_lidx)
	show_alert("★ LEVEL COMPLETE! ★")
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/level_complete.tscn")

func add_score(points: int) -> void:
	score += points
	refresh_ui()

func screen_shake(intensity: float, duration: float) -> void:
	if intensity > _shake_power: _shake_power = intensity
	if duration  > _shake_time:  _shake_time  = duration

func refresh_ui() -> void:
	if ui_label:
		var lv_name: String = PlayerData.current_level.get("name", "")
		var max_w: int = PlayerData.current_level.get("max_waves", 999)
		var wave_tag: String
		if current_wave % 5 == 0:
			wave_tag = " ☠ BOSS!"
		elif current_wave % 3 == 0:
			wave_tag = " ☄ ASTEROID"
		else:
			wave_tag = ""
		var prog_str: String = "%d/%d" % [current_wave, max_w] if max_w < 999 else str(current_wave)
		ui_label.text = "%s  Wave: %s%s   Score: %d" % [lv_name, prog_str, wave_tag, score]

# Cập nhật thanh máu — gọi từ player.gd khi bị damage
func refresh_hp(hp: int, p_max: int = -1) -> void:
	if p_max > 0: max_hp = p_max
	if hp_label:
		var hearts := ""
		for i in range(max_hp):
			hearts += "♥ " if i < hp else "♡ "
		hp_label.text = hearts.strip_edges()

func set_max_hp(n: int) -> void:
	max_hp = n

# Hiển thị loại và cấp độ đạn trên UI
func refresh_skill(active: bool, timer_val: float, cd_val: float, skin_id: int) -> void:
	if not is_instance_valid(skill_label): return
	const SKILL_NAMES: Array = ["OVERDRIVE", "MAX LVL", "MAX STREAMS", "BLINK", "FORTRESS"]
	var name_str: String = SKILL_NAMES[skin_id] if skin_id < SKILL_NAMES.size() else "SKILL"
	if active:
		# Đang chạy — hiển thị thời gian còn lại, màu xanh lá
		skill_label.text = "[J] %s  %.1fs" % [name_str, timer_val]
		skill_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		skill_label.visible = true
	elif cd_val > 0.0:
		# Cooldown — hiển thị thời gian chờ, màu xám
		skill_label.text = "[J] %s  CD %.0fs" % [name_str, cd_val]
		skill_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		skill_label.visible = true
	else:
		# Sẵn sàng — màu vàng sáng
		skill_label.text = "[J] %s  READY" % name_str
		skill_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
		skill_label.visible = true

# Hiển thị loại và cấp độ đạn trên UI
func refresh_weapon(btype: int, blevel: int, streams: int) -> void:
	if weapon_label:
		var type_names: Array[String] = ["NORMAL", "ELECTRIC", "FIRE", "ICE", "EXPLOSIVE", "RICOCHET"]
		var tname: String = type_names[btype] if btype < type_names.size() else "NORMAL"
		var stream_str := " +%d" % streams if streams > 0 else ""
		weapon_label.text = "⚡ %s  LV.%d%s" % [tname, blevel, stream_str]

# Hiển thị thông báo ngắn giữa màn hình (tự biến sau 2.5s)
func show_alert(text: String) -> void:
	if alert_label:
		alert_label.text = text
		alert_label.visible = true
		alert_label.modulate.a = 1.0
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(alert_label):
			alert_label.visible = false

# ── BOSS HP BAR ─────────────────────────────────────────────────────────────
func show_boss_hp(max_val: int, cur_val: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_val
		boss_hp_bar.value = cur_val
		boss_hp_bar.visible = true
	if boss_label:
		boss_label.visible = true

func update_boss_hp(cur_val: int) -> void:
	if boss_hp_bar:
		boss_hp_bar.value = cur_val

func hide_boss_hp() -> void:
	if boss_hp_bar:
		boss_hp_bar.visible = false
	if boss_label:
		boss_label.visible = false

# Hiển thị vũ khí đặc biệt hiện có (gọi từ player.gd)
func refresh_special(left: int, right: int) -> void:
	if not is_instance_valid(special_label): return
	const NAMES: Array = ["MGun", "Msl", "BHole"]
	var parts: Array = []
	var p := get_node_or_null("Player")
	var la: int = p.sw_left_ammo  if p else 0
	var ra: int = p.sw_right_ammo if p else 0
	if left  >= 0: parts.append("[K] %s x%d" % [NAMES[left],  la])
	if right >= 0: parts.append("[L] %s x%d" % [NAMES[right], ra])
	if parts.is_empty():
		special_label.visible = false
	else:
		special_label.text = " | ".join(parts)
		special_label.visible = true

func trigger_game_over() -> void:
	if is_game_over:
		return
	is_game_over = true
	hide_boss_hp()
	emit_signal("game_over_signal")
	Audio.play("game_over")
	# Game over: ít coin hơn hoàn thành, tính theo điểm / 50 (tối thiểu 5)
	var earned_coins: int = maxi(5, score / 50)
	PlayerData.add_coins(earned_coins)
	if hp_label:
		hp_label.text = ""
	HighScore.save_score(score, current_wave)
	# Hiển thị popup thất bại sau 1.5s — dùng Timer thay vì await để chắc chắn
	var _go_timer := Timer.new()
	_go_timer.wait_time = 1.5
	_go_timer.one_shot = true
	_go_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_go_timer.timeout.connect(_show_game_over_popup.bind(earned_coins))
	add_child(_go_timer)
	_go_timer.start()

func _show_game_over_popup(earned_coins: int) -> void:
	var overlay := Control.new()
	overlay.name         = "GameOverOverlay"
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.anchor_right  = 1.0
	overlay.anchor_bottom = 1.0
	$UI.add_child(overlay)

	# Nền mờ
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	overlay.add_child(bg)

	# Panel trung tâm
	var vp_size := get_viewport().get_visible_rect().size
	var panel_w: float = 320.0
	var panel_h: float = 300.0
	var panel := Panel.new()
	panel.position = Vector2((vp_size.x - panel_w) * 0.5, (vp_size.y - panel_h) * 0.5)
	panel.size     = Vector2(panel_w, panel_h)
	var sty := StyleBoxFlat.new()
	sty.bg_color            = Color(0.12, 0.04, 0.04, 0.96)
	sty.border_color        = Color(0.9, 0.2, 0.2, 0.9)
	sty.border_width_left   = 2
	sty.border_width_right  = 2
	sty.border_width_top    = 2
	sty.border_width_bottom = 2
	sty.corner_radius_top_left     = 10
	sty.corner_radius_top_right    = 10
	sty.corner_radius_bottom_left  = 10
	sty.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", sty)
	overlay.add_child(panel)

	# Tiêu đề THẤT BẠI
	var title := Label.new()
	title.text = "THẤT BẠI"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(panel_w, 50)
	title.position = Vector2(0, 20)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	panel.add_child(title)

	# Thông tin điểm
	var score_lbl := Label.new()
	score_lbl.text = "Điểm: %d" % score
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.size = Vector2(panel_w, 30)
	score_lbl.position = Vector2(0, 80)
	score_lbl.add_theme_font_size_override("font_size", 20)
	score_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	panel.add_child(score_lbl)

	# Thông tin wave
	var wave_info := Label.new()
	var max_w: int = PlayerData.current_level.get("max_waves", 999)
	wave_info.text = "Wave: %d / %d" % [current_wave, max_w] if max_w < 999 else "Wave: %d" % current_wave
	wave_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_info.size = Vector2(panel_w, 26)
	wave_info.position = Vector2(0, 112)
	wave_info.add_theme_font_size_override("font_size", 16)
	wave_info.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	panel.add_child(wave_info)

	# Thông tin coin nhận được
	var coin_lbl := Label.new()
	coin_lbl.text = "+%d 💰" % earned_coins
	coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coin_lbl.size = Vector2(panel_w, 26)
	coin_lbl.position = Vector2(0, 140)
	coin_lbl.add_theme_font_size_override("font_size", 16)
	coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	panel.add_child(coin_lbl)

	# Nút Chơi lại
	var btn_w: float = panel_w - 60.0
	var btn_replay := _make_gameover_btn("Chơi lại", Vector2(30, 185), btn_w)
	panel.add_child(btn_replay)
	btn_replay.pressed.connect(_on_gameover_replay)

	# Nút Thoát (về level select)
	var btn_exit := _make_gameover_btn("Thoát", Vector2(30, 240), btn_w)
	panel.add_child(btn_exit)
	btn_exit.pressed.connect(_on_gameover_exit)

	# Animation xuất hiện
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.7, 0.7)
	panel.pivot_offset = Vector2(panel_w * 0.5, panel_h * 0.5)
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	get_tree().paused = true

func _make_gameover_btn(txt: String, pos: Vector2, w: float) -> Button:
	var btn := Button.new()
	btn.text     = txt
	btn.position = pos
	btn.size     = Vector2(w, 44)
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color",         Color(0.95, 0.95, 1.0))
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.6, 0.5))
	btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 0.4))
	var sty_n := StyleBoxFlat.new()
	sty_n.bg_color          = Color(0.18, 0.08, 0.08, 0.9)
	sty_n.border_color      = Color(0.7, 0.25, 0.2, 0.7)
	sty_n.border_width_left   = 1
	sty_n.border_width_right  = 1
	sty_n.border_width_top    = 1
	sty_n.border_width_bottom = 1
	sty_n.corner_radius_top_left     = 6
	sty_n.corner_radius_top_right    = 6
	sty_n.corner_radius_bottom_left  = 6
	sty_n.corner_radius_bottom_right = 6
	var sty_h := sty_n.duplicate() as StyleBoxFlat
	sty_h.bg_color     = Color(0.35, 0.12, 0.12, 0.95)
	sty_h.border_color = Color(1.0, 0.4, 0.3, 1.0)
	var sty_p := sty_n.duplicate() as StyleBoxFlat
	sty_p.bg_color = Color(0.10, 0.05, 0.05, 0.9)
	btn.add_theme_stylebox_override("normal",   sty_n)
	btn.add_theme_stylebox_override("hover",    sty_h)
	btn.add_theme_stylebox_override("pressed",  sty_p)
	return btn

func _on_gameover_replay() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_gameover_exit() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
