extends Node2D
# highscore_screen.gd — Màn hình điểm cao

@onready var title_label:  Label = $UI/Title
@onready var list_label:   Label = $UI/List
@onready var footer_label: Label = $UI/Footer
@onready var coin_label:   Label = $UI/CoinLabel

const C_GOLD      : Color = Color(0.84, 0.72, 0.22)
const C_PARCHMENT : Color = Color(0.94, 0.90, 0.74)

var _list_container: VBoxContainer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_background()
	_style_title()
	_style_coin_label()
	_build_list()
	_style_footer()

func _style_background() -> void:
	var ui: Node = get_node("UI")

	var bg := ColorRect.new()
	bg.size = Vector2(1152, 720)
	bg.color = Color(0.04, 0.07, 0.03)
	ui.add_child(bg)
	ui.move_child(bg, 0)

	# Viền đỏ ngoài
	for rd: Array in [
		[Vector2(0, 0),    Vector2(1152, 3)],
		[Vector2(0, 717),  Vector2(1152, 3)],
		[Vector2(0, 0),    Vector2(3, 720)],
		[Vector2(1149, 0), Vector2(3, 720)],
	]:
		var b := ColorRect.new(); b.position = rd[0]; b.size = rd[1]
		b.color = Color(0.82, 0.14, 0.14); ui.add_child(b)

	# Viền vàng bên trong
	for rd: Array in [
		[Vector2(6, 6),    Vector2(1140, 1)],
		[Vector2(6, 713),  Vector2(1140, 1)],
		[Vector2(6, 6),    Vector2(1, 708)],
		[Vector2(1145, 6), Vector2(1, 708)],
	]:
		var b := ColorRect.new(); b.position = rd[0]; b.size = rd[1]
		b.color = Color(0.84, 0.72, 0.22, 0.55); ui.add_child(b)

	# Divider dưới tiêu đề
	var div := ColorRect.new()
	div.position = Vector2(60, 112); div.size = Vector2(1032, 1)
	div.color = C_GOLD; ui.add_child(div)

func _style_title() -> void:
	title_label.text = "🏆  BẢNG ĐIỂM CAO"
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_color", C_GOLD)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title_label.add_theme_constant_override("shadow_offset_x", 3)
	title_label.add_theme_constant_override("shadow_offset_y", 3)
	title_label.modulate.a = 0.0
	title_label.scale = Vector2(0.7, 0.7)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(title_label, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _style_coin_label() -> void:
	coin_label.text = "💰  Tổng coins: %d" % PlayerData.coins
	coin_label.add_theme_font_size_override("font_size", 16)
	coin_label.add_theme_color_override("font_color", C_GOLD)

func _build_list() -> void:
	list_label.visible = false
	var ui: Node = get_node("UI")

	if is_instance_valid(_list_container):
		_list_container.queue_free()

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(80, 125)
	scroll.size = Vector2(992, 540)
	ui.add_child(scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_list_container)

	var entries: Array = HighScore.load_scores()

	if entries.is_empty():
		var empty_panel := Panel.new()
		empty_panel.custom_minimum_size = Vector2(992, 200)
		var ep_sty := StyleBoxFlat.new()
		ep_sty.bg_color = Color(0.06, 0.10, 0.04, 0.6)
		ep_sty.border_color = Color(0.84, 0.72, 0.22, 0.3)
		ep_sty.border_width_left = 1; ep_sty.border_width_right = 1
		ep_sty.border_width_top = 1; ep_sty.border_width_bottom = 1
		ep_sty.set_corner_radius_all(8)
		empty_panel.add_theme_stylebox_override("panel", ep_sty)
		_list_container.add_child(empty_panel)

		var icon_lbl := Label.new()
		icon_lbl.text = "⚔"
		icon_lbl.position = Vector2(450, 30)
		icon_lbl.add_theme_font_size_override("font_size", 56)
		icon_lbl.add_theme_color_override("font_color", C_PARCHMENT)
		empty_panel.add_child(icon_lbl)

		var msg_lbl := Label.new()
		msg_lbl.text = "Chưa có trận nào. Hãy ra chiến trường!"
		msg_lbl.position = Vector2(220, 130)
		msg_lbl.add_theme_font_size_override("font_size", 22)
		msg_lbl.add_theme_color_override("font_color", C_PARCHMENT)
		empty_panel.add_child(msg_lbl)
		return

	var bg_colors:     Array[Color] = [Color(0.55,0.45,0.05,0.9), Color(0.35,0.35,0.38,0.9), Color(0.38,0.22,0.08,0.9)]
	var border_colors: Array[Color] = [Color(1.0,0.85,0.1),        Color(0.8,0.8,0.9),         Color(0.8,0.5,0.2)]
	var rank_colors:   Array[Color] = [Color(1.0,0.85,0.1),        Color(0.82,0.82,0.92),       Color(0.85,0.52,0.22)]
	var medals:        Array[String] = ["🥇", "🥈", "🥉"]

	for i: int in entries.size():
		var e: Dictionary = entries[i]
		var bg_col:   Color = bg_colors[i]     if i < 3 else Color(0.08, 0.12, 0.06, 0.8)
		var bdr_col:  Color = border_colors[i] if i < 3 else Color(0.35, 0.32, 0.18, 0.5)
		var rank_col: Color = rank_colors[i]   if i < 3 else Color(0.72, 0.68, 0.52)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(980, 54)
		var sty := StyleBoxFlat.new()
		sty.bg_color = bg_col; sty.border_color = bdr_col
		sty.border_width_left = 2; sty.border_width_right = 2
		sty.border_width_top = 2; sty.border_width_bottom = 2
		sty.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", sty)

		# Rank
		var rank_lbl := Label.new()
		rank_lbl.text = "%d." % (i + 1)
		rank_lbl.position = Vector2(14, 13)
		rank_lbl.add_theme_font_size_override("font_size", 22)
		rank_lbl.add_theme_color_override("font_color", rank_col)
		card.add_child(rank_lbl)

		# Medal
		if i < 3:
			var medal_lbl := Label.new()
			medal_lbl.text = medals[i]
			medal_lbl.position = Vector2(46, 11)
			medal_lbl.add_theme_font_size_override("font_size", 22)
			card.add_child(medal_lbl)

		# Score
		var score_lbl := Label.new()
		score_lbl.text = "%d pts" % e.get("score", 0)
		score_lbl.position = Vector2(100, 10)
		score_lbl.add_theme_font_size_override("font_size", 22)
		score_lbl.add_theme_color_override("font_color", Color(1.0, 0.96, 0.5))
		score_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		score_lbl.add_theme_constant_override("shadow_offset_x", 1)
		score_lbl.add_theme_constant_override("shadow_offset_y", 1)
		card.add_child(score_lbl)

		# Wave
		var wave_lbl := Label.new()
		wave_lbl.text = "⚡ Wave %d" % e.get("wave", 0)
		wave_lbl.position = Vector2(380, 16)
		wave_lbl.add_theme_font_size_override("font_size", 16)
		wave_lbl.add_theme_color_override("font_color", Color(0.72, 0.85, 0.58))
		card.add_child(wave_lbl)

		# Date
		var date_lbl := Label.new()
		date_lbl.text = "📅 %s" % e.get("date", "")
		date_lbl.position = Vector2(580, 17)
		date_lbl.add_theme_font_size_override("font_size", 13)
		date_lbl.add_theme_color_override("font_color", Color(0.55, 0.52, 0.40))
		card.add_child(date_lbl)

		# Animate: fade-in theo thứ tự
		card.modulate.a = 0.0
		_list_container.add_child(card)
		var delay: float = i * 0.08
		var tw_card: Tween = create_tween()
		tw_card.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(delay)

func _style_footer() -> void:
	footer_label.text = "[ ESC / ENTER  →  Quay lại ]"
	footer_label.add_theme_font_size_override("font_size", 16)
	footer_label.add_theme_color_override("font_color", Color(0.62, 0.58, 0.42))
	var tw_foot: Tween = create_tween().set_loops()
	tw_foot.tween_property(footer_label, "modulate:a", 0.4, 0.6)
	tw_foot.tween_property(footer_label, "modulate:a", 1.0, 0.6)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")

