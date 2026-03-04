extends Node2D
# themes.gd — Màn chọn gói giao diện (visual pack)

@onready var status_lbl: Label = $UI/StatusLabel

var _cards: Array = []   # bộ card (VBoxContainer) mỗi pack

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	$UI/TopBar/BackBtn.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_build_cards()

func _build_cards() -> void:
	var coin_lbl = get_node_or_null("UI/CoinLabel")
	if coin_lbl: coin_lbl.text = "💰 %d coins" % PlayerData.coins
	var container := $UI/Scroll/HBox
	# Xóa card cũ nếu có
	for c in container.get_children():
		c.queue_free()
	_cards.clear()

	for i in range(ThemePack.PACKS.size()):
		var pack: Dictionary = ThemePack.PACKS[i]
		var is_owned:   bool = i in PlayerData.owned_themes
		var is_active:  bool = (i == PlayerData.active_theme)
		var accent: Color    = pack.get("accent", Color(0.4, 0.8, 1.0))

		# ── Card frame ──────────────────────────────────────────
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(220, 320)
		container.add_child(card)
		_cards.append(card)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 14)
		card.add_child(vbox)

		# Icon + tên
		var icon_lbl := Label.new()
		icon_lbl.text = pack.get("icon", "★")
		icon_lbl.add_theme_font_size_override("font_size", 48)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = pack.get("name", "Pack %d" % i)
		name_lbl.add_theme_font_size_override("font_size", 22)
		name_lbl.add_theme_color_override("font_color", accent)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = pack.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)

		# Dải màu preview (3 ô màu: bg / grid / accent enemy)
		var swatch_row := HBoxContainer.new()
		swatch_row.alignment = BoxContainer.ALIGNMENT_CENTER
		swatch_row.add_theme_constant_override("separation", 6)
		vbox.add_child(swatch_row)
		for sc in [pack.get("bg_top", Color.BLACK), pack.get("grid", Color.BLUE),
		           pack.get("enemy", [Color.RED])[0]]:
			var cr := ColorRect.new()
			cr.custom_minimum_size = Vector2(36, 22)
			cr.color = sc as Color
			swatch_row.add_child(cr)

		# Spacer
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(0, 4)
		sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(sp)

		# Giá
		var price: int = pack.get("price", 0)
		var price_lbl := Label.new()
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_size_override("font_size", 17)
		if price == 0:
			price_lbl.text = "Miễn phí"
			price_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		else:
			price_lbl.text = ("✔ Đã sở hữu" if is_owned else "💰 %d coins" % price)
			price_lbl.add_theme_color_override("font_color",
				Color(0.3, 1.0, 0.5) if is_owned else Color(1.0, 0.85, 0.2))
		vbox.add_child(price_lbl)

		# Nút hành động
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 42)
		btn.add_theme_font_size_override("font_size", 18)
		if is_active:
			btn.text = "✔ ĐANG DÙNG"
			btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45))
			btn.disabled = true
		elif is_owned:
			btn.text = "⬤  TRANG BỊ"
			btn.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
			btn.pressed.connect(_on_equip.bind(i))
		else:
			btn.text = "MUA  %d 💰" % price
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			btn.pressed.connect(_on_buy.bind(i))
		vbox.add_child(btn)

func _on_buy(pack_idx: int) -> void:
	var pack: Dictionary = ThemePack.PACKS[pack_idx]
	var price: int = pack.get("price", 0)
	if PlayerData.spend_coins(price):
		PlayerData.owned_themes.append(pack_idx)
		PlayerData.active_theme = pack_idx
		PlayerData.save_data()
		Audio.play("buy")
		status_lbl.text = "✔ Mua và trang bị %s!" % pack.get("name", "")
		status_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		Audio.play("button_click")
		status_lbl.text = "✘ Không đủ coins!"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_build_cards()

func _on_equip(pack_idx: int) -> void:
	PlayerData.active_theme = pack_idx
	PlayerData.save_data()
	Audio.play("powerup")
	var pack_name: String = (ThemePack.PACKS[pack_idx] as Dictionary).get("name", "")
	status_lbl.text = "✔ Đã trang bị: %s" % pack_name
	status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	_build_cards()
