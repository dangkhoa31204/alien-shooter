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
	if play_btn:     play_btn.pressed.connect(_on_play_pressed)
	if shop_btn:     shop_btn.pressed.connect(_on_shop_pressed)
	if hi_btn:       hi_btn.pressed.connect(_on_highscore_pressed)
	if settings_btn: settings_btn.pressed.connect(_on_settings_pressed)
	if themes_btn:   themes_btn.pressed.connect(_on_themes_pressed)
	
	_add_campaign_button()
	_refresh_coins()
	Audio.refresh_music()

func _add_campaign_button() -> void:
	var btn := Button.new()
	btn.name = "CampaignBtn"
	btn.text = "CHIẾN DỊCH LỊCH SỬ"
	btn.position = Vector2(400, 520) # Middle bottom area
	btn.size = Vector2(352, 64)
	btn.add_theme_font_size_override("font_size", 22)
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
