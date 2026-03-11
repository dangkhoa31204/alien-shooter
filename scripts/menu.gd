extends Node2D
# menu.gd — Main Menu: Play, Shop, High Score

const C_GOLD      := Color(0.84, 0.72, 0.22)
const C_PARCHMENT := Color(0.94, 0.90, 0.74)
const C_OLIVE     := Color(0.10, 0.18, 0.06)
const C_RED       := Color(1.0,  0.4,  0.35)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not PlayerData.sound_enabled)

	var play_btn:     Node = get_node_or_null("UI/PlayBtn")
	var shop_btn:     Node = get_node_or_null("UI/ShopBtn")
	var hi_btn:       Node = get_node_or_null("UI/HighscoreBtn")
	var settings_btn: Node = get_node_or_null("UI/SettingsBtn")
	var themes_btn:   Node = get_node_or_null("UI/ThemesBtn")
	var title_lbl:    Node = get_node_or_null("UI/Title")
	var subtitle_lbl: Node = get_node_or_null("UI/Subtitle")

	if play_btn:   play_btn.hide()
	if shop_btn:   shop_btn.hide()
	if hi_btn:     hi_btn.hide()
	if themes_btn: themes_btn.hide()

	if title_lbl:
		title_lbl.text = "CHIẾN DỊCH LỊCH SỬ"
		title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
		title_lbl.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.0))

	if subtitle_lbl:
		subtitle_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 0.8))
		_typewriter(subtitle_lbl as Label, "Kháng chiến chống Mỹ cứu nước")

	var divider: Node = get_node_or_null("UI/Divider")
	if divider: divider.color = Color(0.8, 0.0, 0.0, 0.4)

	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
		settings_btn.position = Vector2(426, 330)
		settings_btn.size = Vector2(300, 46)
		settings_btn.text = "CÀI ĐẶT"
		_apply_btn_style(settings_btn as Button, C_OLIVE, C_GOLD)
		_add_hover_scale(settings_btn as Button)

	_add_campaign_button()
	_add_quit_button()
	_add_how_to_play_button()
	_add_how_to_play_popup()
	_style_coin_label()
	_add_version_label()
	_refresh_coins()
	Audio.play_menu_music()

	var bg: Node = get_node_or_null("Background")
	if bg:
		if bg.has_method("force_vietnam_mode"):
			bg.force_vietnam_mode()
		if bg.has_method("set_custom_background"):
			bg.set_custom_background("res://assets/art/vietnam_bg.png")

func _make_btn_style(bg: Color, bdr: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = bdr
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(8)
	return s

func _apply_btn_style(btn: Button, normal_bg: Color, bdr: Color) -> void:
	btn.add_theme_color_override("font_color",         Color(0.95, 0.90, 0.55))
	btn.add_theme_color_override("font_hover_color",   Color(1.0,  0.95, 0.15))
	btn.add_theme_color_override("font_pressed_color", Color(1.0,  1.0,  1.0))
	var hover_bg   := Color(normal_bg.r + 0.08, normal_bg.g + 0.14, normal_bg.b + 0.04)
	var pressed_bg := Color(normal_bg.r - 0.04, normal_bg.g - 0.06, normal_bg.b - 0.02)
	btn.add_theme_stylebox_override("normal",  _make_btn_style(normal_bg,  bdr))
	btn.add_theme_stylebox_override("hover",   _make_btn_style(hover_bg,   Color(bdr.r + 0.1, bdr.g + 0.05, bdr.b)))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(pressed_bg, bdr))

func _add_hover_scale(btn: Button) -> void:
	btn.pivot_offset = btn.size * 0.5
	btn.mouse_entered.connect(func():
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.04, 1.04), 0.1)
	)
	btn.mouse_exited.connect(func():
		var tw: Tween = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.1)
	)

func _typewriter(lbl: Label, full_text: String) -> void:
	lbl.text = ""
	var tw: Tween = create_tween()
	for i: int in full_text.length():
		var idx: int = i + 1
		tw.tween_callback(func(): lbl.text = full_text.substr(0, idx))
		tw.tween_interval(0.045)

func _style_coin_label() -> void:
	var ui: Node = get_node_or_null("UI")
	var coin_lbl: Node = get_node_or_null("UI/CoinLabel")
	if not coin_lbl or not ui: return
	# Style the label
	coin_lbl.add_theme_font_size_override("font_size", 18)
	coin_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	coin_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	coin_lbl.add_theme_constant_override("shadow_offset_x", 1)
	coin_lbl.add_theme_constant_override("shadow_offset_y", 1)

func _add_version_label() -> void:
	var ui: Node = get_node_or_null("UI")
	if not ui: return
	var ver := Label.new()
	ver.name = "VersionLabel"
	ver.text = "v1.0  •  1975"
	ver.position = Vector2(1050, 700)
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.40, 0.38, 0.28))
	ui.add_child(ver)


func _add_how_to_play_button() -> void:
	var btn := Button.new()
	btn.name = "HowToPlayBtn"
	btn.text = "CÁCH CHƠI"
	btn.position = Vector2(426, 396)
	btn.size = Vector2(300, 46)
	btn.add_theme_font_size_override("font_size", 21)
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(btn)
	_apply_btn_style(btn, C_OLIVE, C_GOLD)
	_add_hover_scale(btn)
	btn.pressed.connect(_on_how_to_play_pressed)

func _add_how_to_play_popup() -> void:
	var ui = get_node_or_null("UI")
	if not ui: return
	
	var popup = Control.new()
	popup.name = "HowToPlayPopup"
	popup.visible = false
	popup.size = Vector2(1152, 720)
	ui.add_child(popup)
	
	# Ensure it's on top of other siblings
	ui.move_child(popup, -1)
	
	# Dim background
	var dim = ColorRect.new()
	dim.size = popup.size
	dim.color = Color(0, 0, 0, 0.75)
	popup.add_child(dim)
	
	# Panel
	var bg_panel = Panel.new()
	bg_panel.size = Vector2(500, 480)
	bg_panel.position = (popup.size - bg_panel.size) * 0.5
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.1, 0.15, 0.08, 0.98) # Dark military green
	sbox.border_color = Color(0.84, 0.72, 0.22) # Gold
	sbox.border_width_left = 2; sbox.border_width_right = 2
	sbox.border_width_top = 2; sbox.border_width_bottom = 2
	sbox.set_corner_radius_all(10)
	bg_panel.add_theme_stylebox_override("panel", sbox)
	popup.add_child(bg_panel)
	
	# Title
	var title = Label.new()
	title.text = "⚙  ĐIỀU KHIỂN"
	title.position = Vector2(20, 20)
	title.size = Vector2(460, 40)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.84, 0.72, 0.22))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bg_panel.add_child(title)
	
	# Separator
	var sep = ColorRect.new()
	sep.position = Vector2(40, 70)
	sep.size = Vector2(420, 2)
	sep.color = Color(0.84, 0.72, 0.22, 0.5)
	bg_panel.add_child(sep)
	
	# Instructions
	var keys_vbox = VBoxContainer.new()
	keys_vbox.position = Vector2(40, 90)
	keys_vbox.size = Vector2(420, 320)
	keys_vbox.add_theme_constant_override("separation", 12)
	bg_panel.add_child(keys_vbox)
	
	var rows: Array = [
		["A / D  |  ◀ ▶",  "Di chuyển"],
		["SPACE",           "Nhảy / Nhảy kép"],
		["S",               "Bắn súng"],
		["↑  (khi chạy)",  "Bắn chéo 45°"],
		["↓ + SHIFT",       "Lộn vòng lướt"],
		["A  (B40)",        "Bắn hỏa tiễn"],
		["F",               "Đánh cận chiến"],
		["F1",              "Cheat Menu"],
	]
	
	for row in rows:
		var h = HBoxContainer.new()
		var k_lbl = Label.new()
		k_lbl.text = row[0]
		k_lbl.custom_minimum_size.x = 180
		k_lbl.add_theme_color_override("font_color", Color(0.7, 0.62, 0.3)) # Bamboo
		k_lbl.add_theme_font_size_override("font_size", 18)
		
		var d_lbl = Label.new()
		d_lbl.text = row[1]
		d_lbl.add_theme_color_override("font_color", Color(0.58, 0.54, 0.4)) # Text dim
		d_lbl.add_theme_font_size_override("font_size", 18)
		
		h.add_child(k_lbl)
		h.add_child(d_lbl)
		keys_vbox.add_child(h)

	# Close Button
	var close_btn = Button.new()
	close_btn.text = "ĐÓNG"
	close_btn.size = Vector2(160, 40)
	close_btn.position = Vector2(170, 420)
	close_btn.pressed.connect(func(): popup.hide())
	bg_panel.add_child(close_btn)

func _on_how_to_play_pressed() -> void:
	Audio.play("button_click")
	var popup = get_node_or_null("UI/HowToPlayPopup")
	if popup:
		var ui = get_node_or_null("UI")
		if ui: ui.move_child(popup, -1) # Double check it's on top
		popup.show()

func _add_campaign_button() -> void:
	var btn := Button.new()
	btn.name = "CampaignBtn"
	btn.text = "⚔  CHƠI"
	btn.position = Vector2(400, 240)
	btn.size = Vector2(352, 64)
	btn.add_theme_font_size_override("font_size", 26)
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(btn)
	_apply_btn_style(btn, Color(0.10, 0.28, 0.15), Color(0.8, 0.7, 0.2))
	_add_hover_scale(btn)
	btn.pressed.connect(_on_campaign_pressed)

func _add_quit_button() -> void:
	var btn := Button.new()
	btn.name = "QuitBtn"
	btn.text = "THOÁT"
	btn.position = Vector2(426, 462)
	btn.size = Vector2(300, 46)
	btn.add_theme_font_size_override("font_size", 21)
	var ui: Node = get_node_or_null("UI")
	if ui: ui.add_child(btn)
	_apply_btn_style(btn, C_OLIVE, Color(0.55, 0.20, 0.18))
	btn.add_theme_color_override("font_color",       C_RED)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.55))
	_add_hover_scale(btn)
	btn.pressed.connect(_on_quit_pressed)

func _on_quit_pressed() -> void:
	Audio.play("button_click")
	get_tree().quit()

func _on_campaign_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _refresh_coins() -> void:
	var lbl = get_node_or_null("UI/CoinLabel")
	if lbl: lbl.text = "💰 %d coins" % PlayerData.coins

func _on_play_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/airplane_level_select.tscn")

func _on_shop_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_highscore_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/highscore.tscn")

func _on_settings_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/settings.tscn")

func _on_themes_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/themes.tscn")
