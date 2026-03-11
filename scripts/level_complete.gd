extends Node2D
# level_complete.gd — Màn hình hoàn thành level

@onready var level_lbl:  Label  = $UI/Card/VBox/LevelName
@onready var score_lbl:  Label  = $UI/Card/VBox/Score
@onready var wave_lbl:   Label  = $UI/Card/VBox/Waves
@onready var coin_lbl:   Label  = $UI/Card/VBox/Coins
@onready var stars_lbl:  Label  = $UI/Card/VBox/Stars
@onready var replay_btn: Button = $UI/Card/VBox/BtnRow/ReplayBtn
@onready var levels_btn: Button = $UI/Card/VBox/BtnRow/LevelsBtn
@onready var menu_btn:   Button = $UI/Card/VBox/BtnRow/MenuBtn
@onready var title_lbl:  Label  = $UI/Title

var _anim_score:   int  = 0
var _target_score: int  = 0
var _ticking:      bool = false
var _tick_frame:   int  = 0
var _coin_done:    bool = false
var _stars_count:  int  = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_card()
	_style_buttons()
	_populate()
	replay_btn.pressed.connect(_on_replay)
	levels_btn.pressed.connect(_on_levels)
	menu_btn.pressed.connect(_on_menu)
	# Title bounce-in
	title_lbl.text = "✦  THÀNH CÔNG!  ✦"
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.modulate.a = 0.0
	title_lbl.scale = Vector2(0.5, 0.5)
	var tw: Tween = create_tween()
	tw.tween_property(title_lbl, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(title_lbl, "scale", Vector2(1.1, 1.1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_lbl, "scale", Vector2(1.0, 1.0), 0.15)

func _style_card() -> void:
	var card: Node = get_node_or_null("UI/Card")
	if not card: return
	var sty := StyleBoxFlat.new()
	sty.bg_color       = Color(0.06, 0.12, 0.05, 0.97)
	sty.border_color   = Color(0.84, 0.72, 0.22)
	sty.border_width_left = 2; sty.border_width_right  = 2
	sty.border_width_top  = 2; sty.border_width_bottom = 2
	sty.set_corner_radius_all(10)
	sty.content_margin_left   = 12.0; sty.content_margin_right  = 12.0
	sty.content_margin_top    = 12.0; sty.content_margin_bottom = 12.0
	if card is Panel:
		(card as Panel).add_theme_stylebox_override("panel", sty)

func _make_btn_style(bg: Color, bdr: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = bdr
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(6)
	return s

func _style_buttons() -> void:
	for btn: Button in [replay_btn, levels_btn, menu_btn]:
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color",         Color(0.95, 0.90, 0.55))
		btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.95, 0.2))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
		btn.add_theme_stylebox_override("normal",  _make_btn_style(Color(0.10,0.18,0.06), Color(0.55,0.48,0.12)))
		btn.add_theme_stylebox_override("hover",   _make_btn_style(Color(0.18,0.32,0.10), Color(0.82,0.70,0.18)))
		btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.06,0.10,0.04), Color(0.55,0.48,0.12)))

func _populate() -> void:
	var lv_name: String = PlayerData.current_level.get("name", "Level")
	level_lbl.text  = lv_name.to_upper()
	level_lbl.add_theme_color_override("font_color", Color(0.84, 0.72, 0.22))
	level_lbl.add_theme_font_size_override("font_size", 24)

	wave_lbl.text = "⚡ Wave: %d / %d" % [PlayerData.last_wave, PlayerData.current_level.get("max_waves", 0)]
	wave_lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 0.55))

	coin_lbl.text = "+%d 💰  (tổng: %d)" % [PlayerData.last_coins_earned, PlayerData.coins]
	coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))

	# Đếm số sao
	var hp:     int   = PlayerData.last_hp
	var max_hp: int   = PlayerData.last_max_hp
	var ratio:  float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
	if ratio >= 0.67:        _stars_count = 3
	elif ratio >= 0.34:      _stars_count = 2
	else:                    _stars_count = 1

	# Ẩn stars_lbl gốc, xây polygon stars
	stars_lbl.visible = false
	_build_star_row()

	# Style score label
	score_lbl.add_theme_font_size_override("font_size", 32)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.2))
	score_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	score_lbl.add_theme_constant_override("shadow_offset_x", 2)
	score_lbl.add_theme_constant_override("shadow_offset_y", 2)

	# Bắt đầu đếm điểm
	_target_score = PlayerData.last_score
	_anim_score   = 0
	_tick_frame   = 0
	_coin_done    = false
	score_lbl.text = "Điểm: 0"
	_ticking = true

func _build_star_row() -> void:
	var vbox: Node = get_node_or_null("UI/Card/VBox")
	if not vbox: return
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	# Chèn vào đúng sau stars_lbl (index của Stars trong VBox)
	var idx: int = stars_lbl.get_index()
	vbox.add_child(hbox)
	vbox.move_child(hbox, idx + 1)

	for s: int in 3:
		var star_node := Node2D.new()
		star_node.custom_minimum_size = Vector2(54, 54)  # for HBox layout
		hbox.add_child(star_node)
		var is_earned: bool = s < _stars_count
		var star_poly := Polygon2D.new()
		var pts: Array = []
		for j: int in 10:
			var r: float = 22.0 if j % 2 == 0 else 9.0
			var a: float = j * TAU / 10.0 - PI / 2.0
			pts.append(Vector2(cos(a) * r, sin(a) * r))
		star_poly.polygon = PackedVector2Array(pts)
		star_poly.color   = Color(1.0, 0.85, 0.0) if is_earned else Color(0.28, 0.28, 0.28)
		star_poly.position = Vector2(27, 27)
		star_node.add_child(star_poly)

		if is_earned:
			star_poly.scale = Vector2.ZERO
			var delay: float = 0.4 + s * 0.3
			var tw_s: Tween = create_tween()
			tw_s.tween_interval(delay)
			tw_s.tween_property(star_poly, "scale", Vector2(1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw_s.tween_property(star_poly, "scale", Vector2(1.0, 1.0), 0.1)

func _process(_delta: float) -> void:
	if not _ticking: return
	_tick_frame += 1
	if _tick_frame % 10 == 0:
		Audio.play("button_click")
	var step: int = maxi(1, _target_score / 40)
	_anim_score = mini(_anim_score + step, _target_score)
	score_lbl.text = "Điểm: %d" % _anim_score
	if _anim_score >= _target_score:
		_ticking = false
		if not _coin_done:
			_coin_done = true
			_animate_coin_popup()

func _animate_coin_popup() -> void:
	var earned: int = PlayerData.last_coins_earned
	if earned <= 0: return
	# Tạo label tạm thời bay lên
	var lbl := Label.new()
	lbl.text = "+%d 💰" % earned
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	# Vị trí gần coin_lbl
	var coin_pos: Vector2 = coin_lbl.global_position
	lbl.position = coin_pos + Vector2(0, 0)
	lbl.modulate.a = 0.0
	get_node("UI").add_child(lbl)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60, 1.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var tw2: Tween = create_tween()
	tw2.tween_interval(0.8)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw2.tween_callback(lbl.queue_free)

func _on_replay() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_levels() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_menu() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")

