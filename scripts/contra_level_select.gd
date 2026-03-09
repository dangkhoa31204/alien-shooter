extends Control

# contra_level_select.gd
# Level selection menu for Historical Campaign with unlock progression.

@onready var grid: GridContainer = $CenterContainer/GridContainer

var stage_data = [
	{"name": "MÀN 1: RỪNG SÂU", "desc": "Lính Mỹ tuần tra dày đặc.", "difficulty": "Dễ"},
	{"name": "MÀN 2: ĐỊA ĐẠO CỦ CHI", "desc": "Địa hình hẹp, lính ẩn nấp.", "difficulty": "Trung bình"},
	{"name": "MÀN 3: ĐƯỜNG TRƯỜNG SƠN", "desc": "Máy bay ném bom liên tục.", "difficulty": "Khó"},
	{"name": "MÀN 4: CĂN CỨ ĐỊCH", "desc": "Đồn bốt kiên cố, hỏa lực mạnh.", "difficulty": "Rất Khó"},
	{"name": "MÀN 5: CHIẾN THẮNG CUỐI CÙNG", "desc": "Tổng tấn công và nổi dậy.", "difficulty": "Tử thần"}
]

func _ready() -> void:
	_setup_background()
	_create_level_buttons()

func _setup_background() -> void:
	# Jungle themed background for menu
	var bg = ColorRect.new()
	bg.size = Vector2(1280, 720)
	bg.color = Color(0.05, 0.1, 0.05)
	add_child(bg)
	move_child(bg, 0)
	
	var title = Label.new()
	title.text = "CHỌN CHIẾN DỊCH LỊCH SỬ"
	title.add_theme_font_size_override("font_size", 48)
	title.position = Vector2(350, 50)
	title.modulate = Color(1, 0.9, 0.2)
	add_child(title)

func _create_level_buttons() -> void:
	var unlocked_stage = PlayerData.get_unlocked_stage() # Assuming PlayerData exists
	
	for i in range(5):
		var stage_num = i + 1
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 200)
		btn.text = stage_data[i]["name"] + "\n\n" + stage_data[i]["difficulty"]
		
		# Styling
		var style = StyleBoxFlat.new()
		var is_locked = stage_num > unlocked_stage
		
		if is_locked:
			style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			btn.disabled = true
			btn.text = "ĐANG KHÓA\n\n(Hoàn thành màn " + str(i) + ")"
		else:
			style.bg_color = Color(0.1, 0.3, 0.1, 0.8)
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.pressed.connect(_on_level_pressed.bind(stage_num))
		
		style.border_width_left = 2; style.border_width_right = 2; style.border_width_top = 2; style.border_width_bottom = 2
		style.border_color = Color(1, 1, 0.4, 0.3)
		style.set_corner_radius_all(10)
		
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style.duplicate())
		btn.get_theme_stylebox("hover").bg_color = Color(0.2, 0.5, 0.2)
		
		grid.add_child(btn)

	# Back button
	var back = Button.new()
	back.text = "QUAY LẠI TRANG CHỦ"
	back.position = Vector2(540, 620)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	add_child(back)

func _on_level_pressed(num: int) -> void:
	# Save selected level to a global or pass it
	PlayerData.current_selected_stage = num
	get_tree().change_scene_to_file("res://scenes/contra_main.tscn")
