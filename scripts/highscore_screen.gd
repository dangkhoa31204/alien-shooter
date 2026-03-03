extends Node2D
# highscore_screen.gd — Màn hình điểm cao

@onready var title_label:   Label = $UI/Title
@onready var list_label:    Label = $UI/List
@onready var footer_label:  Label = $UI/Footer
@onready var coin_label:    Label = $UI/CoinLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_list()
	coin_label.text = "💰 Tổng coins: %d" % PlayerData.coins

func _build_list() -> void:
	var entries: Array = HighScore.load_scores()
	if entries.is_empty():
		list_label.text = "Chưa có điểm nào.\nHãy chơi để ghi điểm!"
		return
	var lines := ""
	for i in range(entries.size()):
		var e: Dictionary = entries[i]
		var medal := "  "
		if   i == 0: medal = "🥇"
		elif i == 1: medal = "🥈"
		elif i == 2: medal = "🥉"
		lines += "%s %2d.  %7d pts   Wave %d   %s\n" % [
			medal, i + 1, e.get("score", 0), e.get("wave", 0), e.get("date", "")
		]
	list_label.text = lines.strip_edges()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R or event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")
