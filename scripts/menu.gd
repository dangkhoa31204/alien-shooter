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
	if play_btn:     play_btn.pressed.connect(_on_play_pressed)
	if shop_btn:     shop_btn.pressed.connect(_on_shop_pressed)
	if hi_btn:       hi_btn.pressed.connect(_on_highscore_pressed)
	if settings_btn: settings_btn.pressed.connect(_on_settings_pressed)
	_refresh_coins()
	Audio.refresh_music()

func _refresh_coins() -> void:
	var lbl = get_node_or_null("UI/CoinLabel")
	if lbl: lbl.text = "💰 %d coins" % PlayerData.coins

func _on_play_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_shop_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_highscore_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/highscore.tscn")

func _on_settings_pressed() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/settings.tscn")
