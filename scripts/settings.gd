extends Node2D
# settings.gd — Cài đặt: bật/tắt âm thanh, âm lượng, reset dữ liệu game

@onready var sound_btn:         Button = $UI/Panel/VBox/SoundRow/SoundBtn
@onready var sound_label:       Label  = $UI/Panel/VBox/SoundRow/SoundLabel
@onready var reset_btn:         Button = $UI/Panel/VBox/ResetBtn
@onready var confirm_box:       VBoxContainer = $UI/ConfirmBox
@onready var status_label:      Label  = $UI/StatusLabel
@onready var volume_slider:     HSlider = $UI/Panel/VBox/VolumeRow/VolumeSlider
@onready var volume_value_lbl:  Label   = $UI/Panel/VBox/VolumeRow/VolumeValueLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	_refresh_sound_btn()
	# Slider âm lượng
	volume_slider.value = PlayerData.volume * 100.0
	_refresh_volume_lbl()
	volume_slider.value_changed.connect(_on_volume_changed)

	$UI/TopBar/BackBtn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	sound_btn.pressed.connect(_on_sound_toggled)
	reset_btn.pressed.connect(_on_reset_pressed)
	$UI/ConfirmBox/BtnRow/YesBtn.pressed.connect(_on_confirm_yes)
	$UI/ConfirmBox/BtnRow/NoBtn.pressed.connect(_on_confirm_no)
	confirm_box.visible = false
	status_label.text   = ""

func _refresh_sound_btn() -> void:
	var on: bool = PlayerData.sound_enabled
	sound_btn.text = "🔊  BẬT" if on else "🔇  TẮT"
	sound_btn.add_theme_color_override("font_color",
		Color(0.2, 1.0, 0.4) if on else Color(0.9, 0.35, 0.35))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)

func _refresh_volume_lbl() -> void:
	var pct: int = roundi(PlayerData.volume * 100.0)
	volume_value_lbl.text = "%d%%" % pct

func _on_volume_changed(value: float) -> void:
	PlayerData.volume = value / 100.0
	PlayerData.apply_volume()
	PlayerData.save_data()
	_refresh_volume_lbl()

func _on_sound_toggled() -> void:
	PlayerData.sound_enabled = not PlayerData.sound_enabled
	PlayerData.save_data()
	_refresh_sound_btn()
	Audio.refresh_music()

func _on_reset_pressed() -> void:
	confirm_box.visible = true
	reset_btn.disabled  = true
	status_label.text   = ""

func _on_confirm_yes() -> void:
	PlayerData.reset_data()
	HighScore.reset_scores()
	confirm_box.visible = false
	reset_btn.disabled  = false
	status_label.text   = "✔ Đã xóa toàn bộ dữ liệu!"
	status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))

func _on_confirm_no() -> void:
	confirm_box.visible = false
	reset_btn.disabled  = false
