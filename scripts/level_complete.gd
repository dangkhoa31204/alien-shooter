extends Node2D
# level_complete.gd — Màn hình hoàn thành level

@onready var level_lbl:   Label  = $UI/Card/VBox/LevelName
@onready var score_lbl:   Label  = $UI/Card/VBox/Score
@onready var wave_lbl:    Label  = $UI/Card/VBox/Waves
@onready var coin_lbl:    Label  = $UI/Card/VBox/Coins
@onready var stars_lbl:   Label  = $UI/Card/VBox/Stars
@onready var replay_btn:  Button = $UI/Card/VBox/BtnRow/ReplayBtn
@onready var levels_btn:  Button = $UI/Card/VBox/BtnRow/LevelsBtn
@onready var menu_btn:    Button = $UI/Card/VBox/BtnRow/MenuBtn
@onready var title_lbl:   Label  = $UI/Title

var _anim_score: int  = 0
var _target_score: int = 0
var _ticking: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate()
	replay_btn.pressed.connect(_on_replay)
	levels_btn.pressed.connect(_on_levels)
	menu_btn.pressed.connect(_on_menu)
	# Tween title vào
	title_lbl.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title_lbl, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_EXPO)

func _populate() -> void:
	var lv_name: String = PlayerData.current_level.get("name", "Level")
	var diff:    int    = PlayerData.current_level.get("difficulty", 1)

	level_lbl.text  = lv_name.to_upper()
	wave_lbl.text   = "Wave: %d / %d" % [PlayerData.last_wave, PlayerData.current_level.get("max_waves", 0)]
	coin_lbl.text   = "+%d 💰  (tổng: %d)" % [PlayerData.last_coins_earned, PlayerData.coins]

	# Đếm số sao: dựa vào HP còn lại / hp tối đa
	var hp:     int = PlayerData.last_hp
	var max_hp: int = PlayerData.last_max_hp
	var ratio   := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var stars_count: int
	if ratio >= 0.67:   stars_count = 3
	elif ratio >= 0.34: stars_count = 2
	else:               stars_count = 1
	var stars_str := "★".repeat(stars_count) + "☆".repeat(3 - stars_count)
	stars_lbl.text = stars_str

	# Đếm ngược điểm
	_target_score = PlayerData.last_score
	_anim_score   = 0
	score_lbl.text = "Điểm: 0"
	_ticking = true

func _process(delta: float) -> void:
	if not _ticking: return
	var step: int = maxi(1, _target_score / 40)
	_anim_score = mini(_anim_score + step, _target_score)
	score_lbl.text = "Điểm: %d" % _anim_score
	if _anim_score >= _target_score:
		_ticking = false

func _on_replay() -> void:
	Audio.play("button_click")
	# Giữ nguyên PlayerData.current_level, chơi lại
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_levels() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_menu() -> void:
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
