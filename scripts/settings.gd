extends Node2D
# settings.gd — Cài đặt: bật/tắt âm thanh, âm lượng, reset dữ liệu game

@onready var reset_btn:        Button        = $UI/Panel/VBox/ResetBtn
@onready var confirm_box:      VBoxContainer = $UI/ConfirmBox
@onready var status_label:     Label         = $UI/StatusLabel
@onready var volume_slider:    HSlider       = $UI/Panel/VBox/VolumeRow/VolumeSlider
# This button replaces the old percent label and acts as the sound on/off toggle
@onready var sound_toggle_btn: Button        = $UI/Panel/VBox/VolumeRow/VolumeValueLabel
@onready var sfx_slider:       HSlider       = $UI/Panel/VBox/SfxRow/SfxSlider
@onready var sfx_toggle_btn:   Button        = $UI/Panel/VBox/SfxRow/SfxValueLabel

const C_GOLD  := Color(0.84, 0.72, 0.22)
const C_OLIVE := Color(0.08, 0.14, 0.06)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	_style_panel()
	_style_confirm_box()
	_style_reset_btn()
	_refresh_sound_btn()
	_refresh_sfx_btn()
	volume_slider.value = PlayerData.volume * 100.0
	volume_slider.value_changed.connect(_on_volume_changed)
	sound_toggle_btn.pressed.connect(_on_sound_toggled)
	sfx_slider.value = PlayerData.sfx_volume * 100.0
	sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_toggle_btn.pressed.connect(_on_sfx_toggled)

	$UI/TopBar/BackBtn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	reset_btn.pressed.connect(_on_reset_pressed)
	$UI/ConfirmBox/BtnRow/YesBtn.pressed.connect(_on_confirm_yes)
	$UI/ConfirmBox/BtnRow/NoBtn.pressed.connect(_on_confirm_no)
	confirm_box.visible = false
	status_label.text   = ""

func _btn_flat(bg: Color, bdr: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = bdr
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(6)
	return s

func _style_panel() -> void:
	var panel: Node = get_node_or_null("UI/Panel")
	if not panel: return
	# Panel background
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.07, 0.12, 0.05, 0.96)
	ps.border_color = C_GOLD
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(10)
	ps.content_margin_top = 52.0
	if panel is Panel:
		(panel as Panel).add_theme_stylebox_override("panel", ps)
	# Title bar ColorRect inside panel
	var title_bar := ColorRect.new()
	title_bar.color = Color(0.06, 0.10, 0.04)
	title_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_bar.size = Vector2(0, 44)
	title_bar.size_flags_horizontal = Control.SIZE_FILL
	panel.add_child(title_bar)
	panel.move_child(title_bar, 0)
	# Title label
	var title_lbl := Label.new()
	title_lbl.text = "⚙  CÀI ĐẶT"
	title_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title_lbl.size = Vector2(0, 44)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", C_GOLD)
	panel.add_child(title_lbl)
	panel.move_child(title_lbl, 1)
	# Gold divider
	var divider := ColorRect.new()
	divider.color = C_GOLD
	divider.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	divider.offset_top = 44; divider.size = Vector2(0, 1)
	divider.size_flags_horizontal = Control.SIZE_FILL
	panel.add_child(divider)
	panel.move_child(divider, 2)

func _style_confirm_box() -> void:
	var cb: Node = get_node_or_null("UI/ConfirmBox")
	if not cb: return
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.18, 0.04, 0.04, 0.98)
	ps.border_color = Color(0.8, 0.2, 0.2)
	ps.border_width_left = 2; ps.border_width_right  = 2
	ps.border_width_top  = 2; ps.border_width_bottom = 2
	ps.set_corner_radius_all(8)
	if cb is Panel:
		(cb as Panel).add_theme_stylebox_override("panel", ps)

	var yes_btn: Node = get_node_or_null("UI/ConfirmBox/BtnRow/YesBtn")
	var no_btn:  Node = get_node_or_null("UI/ConfirmBox/BtnRow/NoBtn")
	if yes_btn is Button:
		(yes_btn as Button).add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		(yes_btn as Button).add_theme_stylebox_override("normal",  _btn_flat(Color(0.30,0.04,0.04), Color(0.8,0.2,0.2)))
		(yes_btn as Button).add_theme_stylebox_override("hover",   _btn_flat(Color(0.45,0.06,0.06), Color(1.0,0.3,0.3)))
	if no_btn is Button:
		(no_btn as Button).add_theme_color_override("font_color", Color(0.85, 0.80, 0.50))
		(no_btn as Button).add_theme_stylebox_override("normal",  _btn_flat(C_OLIVE, C_GOLD))
		(no_btn as Button).add_theme_stylebox_override("hover",   _btn_flat(Color(0.14,0.24,0.08), C_GOLD))

func _style_reset_btn() -> void:
	reset_btn.add_theme_color_override("font_color",       Color(1.0, 0.45, 0.35))
	reset_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.6, 0.5))
	reset_btn.add_theme_stylebox_override("normal",  _btn_flat(Color(0.22,0.06,0.04), Color(0.65,0.18,0.14)))
	reset_btn.add_theme_stylebox_override("hover",   _btn_flat(Color(0.32,0.08,0.06), Color(0.85,0.25,0.20)))
	reset_btn.add_theme_stylebox_override("pressed", _btn_flat(Color(0.14,0.04,0.03), Color(0.65,0.18,0.14)))

func _refresh_sound_btn() -> void:
	var on: bool = PlayerData.music_enabled
	sound_toggle_btn.text = "🔊" if on else "🔇"
	if on:
		sound_toggle_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		sound_toggle_btn.add_theme_stylebox_override("normal", _btn_flat(Color(0.06,0.20,0.08), Color(0.25,0.75,0.35)))
		sound_toggle_btn.add_theme_stylebox_override("hover",  _btn_flat(Color(0.10,0.28,0.12), Color(0.35,0.90,0.45)))
	else:
		sound_toggle_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
		sound_toggle_btn.add_theme_stylebox_override("normal", _btn_flat(Color(0.20,0.06,0.06), Color(0.55,0.18,0.18)))
		sound_toggle_btn.add_theme_stylebox_override("hover",  _btn_flat(Color(0.28,0.08,0.08), Color(0.70,0.25,0.25)))
	# Do not mute Master as a fallback (would mute SFX). Music start/stop handled by Audio.refresh_music()/refresh_menu_music().

func _refresh_sfx_btn() -> void:
	var on: bool = PlayerData.sfx_enabled
	sfx_toggle_btn.text = "🔊" if on else "🔇"
	if on:
		sfx_toggle_btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		sfx_toggle_btn.add_theme_stylebox_override("normal", _btn_flat(Color(0.06,0.20,0.08), Color(0.25,0.75,0.35)))
		sfx_toggle_btn.add_theme_stylebox_override("hover",  _btn_flat(Color(0.10,0.28,0.12), Color(0.35,0.90,0.45)))
	else:
		sfx_toggle_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
		sfx_toggle_btn.add_theme_stylebox_override("normal", _btn_flat(Color(0.20,0.06,0.06), Color(0.55,0.18,0.18)))
		sfx_toggle_btn.add_theme_stylebox_override("hover",  _btn_flat(Color(0.28,0.08,0.08), Color(0.70,0.25,0.25)))


func _refresh_volume_lbl() -> void:
	# percent display removed — volume numeric no longer shown in UI
	pass

func _on_volume_changed(value: float) -> void:
	PlayerData.volume = value / 100.0
	PlayerData.apply_volume()
	PlayerData.save_data()

func _on_sfx_changed(value: float) -> void:
	PlayerData.sfx_volume = value / 100.0
	PlayerData.apply_volume()
	PlayerData.save_data()

func _on_sound_toggled() -> void:
	PlayerData.music_enabled = not PlayerData.music_enabled
	PlayerData.save_data()
	_refresh_sound_btn()
	Audio.refresh_music()
	Audio.refresh_menu_music()

func _on_sfx_toggled() -> void:
	PlayerData.sfx_enabled = not PlayerData.sfx_enabled
	PlayerData.save_data()
	_refresh_sfx_btn()

func _on_reset_pressed() -> void:
	confirm_box.visible = true
	reset_btn.disabled  = true
	status_label.text   = ""

func _animate_status() -> void:
	status_label.scale = Vector2(1.0, 1.0)
	status_label.modulate.a = 1.0
	var tw: Tween = create_tween()
	tw.tween_property(status_label, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_BACK)
	tw.tween_property(status_label, "scale", Vector2(1.0, 1.0), 0.1)
	tw.tween_interval(2.5)
	tw.tween_property(status_label, "modulate:a", 0.0, 0.5)

func _on_confirm_yes() -> void:
	PlayerData.reset_data()
	HighScore.reset_scores()
	confirm_box.visible = false
	reset_btn.disabled  = false
	status_label.text   = "✔ Đã xóa toàn bộ dữ liệu!"
	status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
	_animate_status()

func _on_confirm_no() -> void:
	confirm_box.visible = false
	reset_btn.disabled  = false

