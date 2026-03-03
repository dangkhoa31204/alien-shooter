extends Node2D
# menu.gd — Main Menu: Play, Shop, High Score

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	$UI/PlayBtn.pressed.connect(_on_play_pressed)
	$UI/ShopBtn.pressed.connect(_on_shop_pressed)
	$UI/HighscoreBtn.pressed.connect(_on_highscore_pressed)
	_refresh_coins()

func _refresh_coins() -> void:
	$UI/CoinLabel.text = "💰 %d coins" % PlayerData.coins

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

func _on_shop_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/shop.tscn")

func _on_highscore_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/highscore.tscn")
