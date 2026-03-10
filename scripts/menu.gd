extends Node2D
# menu.gd — Main Menu: Play, Shop, High Score

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, not PlayerData.sound_enabled)
	
	var play_btn     = get_node_or_null("UI/PlayBtn")
	var shop_btn     = get_node_or_null("UI/ShopBtn")
	var hi_btn       = get_node_or_null("UI/HighscoreBtn")
	var settings_btn = get_node_or_null("UI/SettingsBtn")
	var themes_btn   = get_node_or_null("UI/ThemesBtn")
	var title_lbl    = get_node_or_null("UI/Title")
	var subtitle_lbl = get_node_or_null("UI/Subtitle")
	
	if play_btn:     play_btn.hide()
	if shop_btn:     shop_btn.hide()
	if hi_btn:       hi_btn.hide()
	if themes_btn:   themes_btn.hide()
	
	if title_lbl:
		title_lbl.text = "CHIẾN DỊCH LỊCH SỬ"
		title_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # Yellow
		title_lbl.add_theme_color_override("font_shadow_color", Color(0.8, 0.0, 0.0)) # Red shadow
	
	if subtitle_lbl:
		subtitle_lbl.text = "Kháng chiến chống Mỹ cứu nước"
		subtitle_lbl.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 0.8)) # Light green tint
	
	var divider = get_node_or_null("UI/Divider")
	if divider: divider.color = Color(0.8, 0.0, 0.0, 0.4) # Red divider
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
		settings_btn.position = Vector2(426, 330) # Moved slightly up
		settings_btn.size = Vector2(300, 46)
		settings_btn.text = "CÀI ĐẶT"
	
	_add_campaign_button()
	_add_quit_button()
	_add_how_to_play_button() # Add button
	_add_how_to_play_popup()  # Add popup LAST so it's on top
	_refresh_coins()
	Audio.play_menu_music()
	
	# Force Vietnam background mode and set custom image
	var bg = get_node_or_null("Background")
	if bg:
		if bg.has_method("force_vietnam_mode"):
			bg.force_vietnam_mode()
		if bg.has_method("set_custom_background"):
			bg.set_custom_background("res://assets/art/vietnam_bg.png")

func _add_how_to_play_button() -> void:
	var btn := Button.new()
	btn.name = "HowToPlayBtn"
	btn.text = "CÁCH CHƠI"
	btn.position = Vector2(426, 396) # Below Settings
	btn.size = Vector2(300, 46)
	btn.add_theme_font_size_override("font_size", 21)
	
	var ui = get_node_or_null("UI")
	if ui:
		ui.add_child(btn)
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
	btn.text = "CHƠI"
	btn.position = Vector2(400, 240) # Positioned where PLAY was
	btn.size = Vector2(352, 64)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.45))
	
	var sty := StyleBoxFlat.new()
	sty.bg_color = Color(0.1, 0.28, 0.15) # Army green
	sty.border_color = Color(0.8, 0.7, 0.2)
	sty.border_width_left = 2
	sty.border_width_right = 2
	sty.border_width_top = 2
	sty.border_width_bottom = 2
	sty.corner_radius_top_left = 8
	sty.corner_radius_top_right = 8
	sty.corner_radius_bottom_left = 8
	sty.corner_radius_bottom_right = 8
	btn.add_theme_stylebox_override("normal", sty)
	
	var ui = get_node_or_null("UI")
	if ui:
		ui.add_child(btn)
	btn.pressed.connect(_on_campaign_pressed)

func _add_quit_button() -> void:
	var btn := Button.new()
	btn.name = "QuitBtn"
	btn.text = "THOÁT"
	btn.position = Vector2(426, 462) # Shifted down
	btn.size = Vector2(300, 46)
	btn.add_theme_font_size_override("font_size", 21)
	
	var ui = get_node_or_null("UI")
	if ui:
		ui.add_child(btn)
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
