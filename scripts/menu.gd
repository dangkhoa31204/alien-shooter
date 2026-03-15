extends Node2D
# menu.gd — Main Menu: Play, Shop, High Score

const C_GOLD      := Color(0.84, 0.72, 0.22)
const C_PARCHMENT := Color(0.94, 0.90, 0.74)
const C_OLIVE     := Color(0.10, 0.18, 0.06)
const C_RED       := Color(1.0,  0.4,  0.35)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()

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
		subtitle_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		subtitle_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
		subtitle_lbl.add_theme_constant_override("shadow_offset_x", 2)
		subtitle_lbl.add_theme_constant_override("shadow_offset_y", 2)
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
	_add_settings_popup()
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
		["◀ ▶",            "Di chuyển"],
		["SPACE",           "Nhảy / Nhảy kép"],
		["S",               "Bắn súng"],
		["↑ / ↓",          "Ngắm lên / Ngồi"],
		["↓ + SHIFT",       "Lộn vòng lướt"],
		["A  (B40)",        "Bắn hỏa tiễn"],
		["X",               "Tên lửa phòng không"],
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



func _on_settings_pressed() -> void:
	Audio.play("button_click")
	var popup = get_node_or_null("UI/SettingsPopup")
	if popup:
		var ui = get_node_or_null("UI")
		if ui: ui.move_child(popup, -1)
		popup.show()
		


func _add_settings_popup() -> void:
	var ui = get_node_or_null("UI")
	if not ui: return
	
	var popup = Control.new()
	popup.name = "SettingsPopup"
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
	bg_panel.size = Vector2(500, 370)
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
	title.text = "⚙  CÀI ĐẶT"
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
	
	# Content Container
	var content_vbox = VBoxContainer.new()
	content_vbox.position = Vector2(40, 90)
	content_vbox.size = Vector2(420, 200)
	content_vbox.add_theme_constant_override("separation", 20)
	bg_panel.add_child(content_vbox)
	
	# Volume Row (contains sound toggle button instead of percent)
	var vol_row = HBoxContainer.new()

	var vol_lbl = Label.new()
	vol_lbl.text = "Nhạc nền "
	vol_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	vol_lbl.add_theme_font_size_override("font_size", 20)
	vol_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vol_slider = HSlider.new()
	vol_slider.name = "VolumeSlider"
	vol_slider.custom_minimum_size = Vector2(160, 32)
	vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_slider.min_value = 0.0
	vol_slider.max_value = 100.0
	vol_slider.value = PlayerData.volume * 100.0

	var vol_val_btn = Button.new()
	vol_val_btn.name = "VolumeValueLabel"
	vol_val_btn.custom_minimum_size = Vector2(52, 0)
	vol_val_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	vol_val_btn.add_theme_font_size_override("font_size", 18)
	vol_val_btn.text = ("🔊" if PlayerData.music_enabled else "🔇")

	vol_row.add_child(vol_lbl)
	vol_row.add_child(vol_slider)
	vol_row.add_child(vol_val_btn)
	content_vbox.add_child(vol_row)
    
	var reset_btn = Button.new()
	reset_btn.name = "ResetBtn"
	reset_btn.custom_minimum_size = Vector2(220, 42)
	reset_btn.add_theme_font_size_override("font_size", 18)
	reset_btn.text = "🗑  XÓA DỮ LIỆU / CHƠI LẠI"
	reset_btn.add_theme_color_override("font_color",       Color(1.0, 0.45, 0.35))
	reset_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.5))
	reset_btn.add_theme_stylebox_override("normal",  _make_btn_style(Color(0.22,0.06,0.04), Color(0.65,0.18,0.14)))
	reset_btn.add_theme_stylebox_override("hover",   _make_btn_style(Color(0.32,0.08,0.06), Color(0.85,0.25,0.20)))
	reset_btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.14,0.04,0.03), Color(0.65,0.18,0.14)))
	
	reset_btn.pressed.connect(func():
		Audio.play("button_click")
		PlayerData.reset_data()
		PlayerData.music_enabled = false
		PlayerData.save_data()
		vol_val_btn.text = "🔇"
		vol_val_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
		vol_val_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.20,0.06,0.06), Color(0.55,0.18,0.18)))
		vol_val_btn.add_theme_stylebox_override("hover",  _make_btn_style(Color(0.28,0.08,0.08), Color(0.70,0.25,0.25)))
		# Stop music via Audio manager instead of muting Master bus
		Audio.refresh_music()
		Audio.refresh_menu_music()
		vol_slider.value = 100.0
		_refresh_coins()
		var title_prev = title.text
		title.text = "✔ Đã xóa dữ liệu!"
		title.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
		await get_tree().create_timer(1.5).timeout
		title.text = title_prev
		title.add_theme_color_override("font_color", Color(0.84, 0.72, 0.22))
	)
	
	# --- Signals and Styling ---
	var update_sound_btn = func(on: bool):
		vol_val_btn.text = ("🔊" if on else "🔇")
		if on:
			vol_val_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			vol_val_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.06,0.20,0.08), Color(0.25,0.75,0.35)))
			vol_val_btn.add_theme_stylebox_override("hover",  _make_btn_style(Color(0.10,0.28,0.12), Color(0.35,0.90,0.45)))
		else:
			vol_val_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
			vol_val_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.20,0.06,0.06), Color(0.55,0.18,0.18)))
			vol_val_btn.add_theme_stylebox_override("hover",  _make_btn_style(Color(0.28,0.08,0.08), Color(0.70,0.25,0.25)))

	update_sound_btn.call(PlayerData.music_enabled)

	vol_val_btn.pressed.connect(func():
		Audio.play("button_click")
		PlayerData.music_enabled = not PlayerData.music_enabled
		PlayerData.save_data()
		update_sound_btn.call(PlayerData.music_enabled)
		# Control music via Audio manager to avoid muting Master (which would affect SFX)
		Audio.refresh_music()
		Audio.refresh_menu_music()
	)
	
	vol_slider.value_changed.connect(func(val: float):
		PlayerData.volume = val / 100.0
		PlayerData.apply_volume()
		PlayerData.save_data()
	)
	
	# Close Button
	var close_btn = Button.new()
	close_btn.text = "ĐÓNG"
	close_btn.size = Vector2(160, 40)
	close_btn.position = Vector2(170, 310)
	_apply_btn_style(close_btn, C_OLIVE, C_GOLD)
	close_btn.pressed.connect(func(): 
		Audio.play("button_click")
		popup.hide()
	)
	bg_panel.add_child(close_btn)

	# --- SFX Row: Hiệu ứng âm thanh
	var sfx_row = HBoxContainer.new()

	var sfx_lbl = Label.new()
	sfx_lbl.text = "Hiệu ứng âm thanh"
	sfx_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	sfx_lbl.add_theme_font_size_override("font_size", 20)
	sfx_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sfx_slider = HSlider.new()
	sfx_slider.name = "SfxSlider"
	sfx_slider.custom_minimum_size = Vector2(160, 32)
	sfx_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 100.0
	sfx_slider.value = PlayerData.sfx_volume * 100.0

	var sfx_val_btn = Button.new()
	sfx_val_btn.name = "SfxValueLabel"
	sfx_val_btn.custom_minimum_size = Vector2(52, 0)
	sfx_val_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	sfx_val_btn.add_theme_font_size_override("font_size", 18)
	sfx_val_btn.text = ("🔊" if PlayerData.sfx_enabled else "🔇")

	sfx_row.add_child(sfx_lbl)
	sfx_row.add_child(sfx_slider)
	sfx_row.add_child(sfx_val_btn)
	content_vbox.add_child(sfx_row)

	# add reset after SFX so order is Volume -> SFX -> Reset
	content_vbox.add_child(reset_btn)

	# SFX handlers
	var update_sfx_btn = func(on: bool):
		sfx_val_btn.text = ("🔊" if on else "🔇")
		if on:
			sfx_val_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
			sfx_val_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.06,0.20,0.08), Color(0.25,0.75,0.35)))
			sfx_val_btn.add_theme_stylebox_override("hover",  _make_btn_style(Color(0.10,0.28,0.12), Color(0.35,0.90,0.45)))
		else:
			sfx_val_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
			sfx_val_btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.20,0.06,0.06), Color(0.55,0.18,0.18)))
			sfx_val_btn.add_theme_stylebox_override("hover",  _make_btn_style(Color(0.28,0.08,0.08), Color(0.70,0.25,0.25)))

	update_sfx_btn.call(PlayerData.sfx_enabled)

	sfx_val_btn.pressed.connect(func():
		Audio.play("button_click")
		PlayerData.sfx_enabled = not PlayerData.sfx_enabled
		PlayerData.save_data()
		update_sfx_btn.call(PlayerData.sfx_enabled)
	)

	sfx_slider.value_changed.connect(func(val: float):
		PlayerData.sfx_volume = val / 100.0
		PlayerData.apply_volume()
		PlayerData.save_data()
	)
