extends Node2D
# shop.gd — Cửa hàng mua skin và loại đạn khởi đầu

enum Tab { SKIN, STARTER }
var _current_tab: Tab = Tab.SKIN

@onready var coin_label:   Label       = $UI/TopBar/CoinLabel
@onready var tab_skin:     Button      = $UI/Tabs/SkinTab
@onready var tab_starter:  Button      = $UI/Tabs/StarterTab
@onready var item_list:    VBoxContainer = $UI/Scroll/ItemList
@onready var status_label: Label       = $UI/StatusLabel

# Màu nút đang chọn tab
const TAB_ACTIVE   := Color(0.3, 0.7, 1.0, 1.0)
const TAB_INACTIVE := Color(0.15, 0.18, 0.3, 1.0)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()   # đảm bảo dữ liệu sở hữu được nạp đúng
	tab_skin.pressed.connect(func(): _switch_tab(Tab.SKIN))
	tab_starter.pressed.connect(func(): _switch_tab(Tab.STARTER))
	$UI/TopBar/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_switch_tab(Tab.SKIN)

func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	tab_skin.add_theme_color_override("font_color",
		TAB_ACTIVE if tab == Tab.SKIN else TAB_INACTIVE)
	tab_starter.add_theme_color_override("font_color",
		TAB_ACTIVE if tab == Tab.STARTER else TAB_INACTIVE)
	_build_list()

func _build_list() -> void:
	# Xoá items cũ
	for child in item_list.get_children():
		child.queue_free()
	coin_label.text = "💰 %d coins" % PlayerData.coins
	status_label.text = ""

	if _current_tab == Tab.SKIN:
		for skin in PlayerData.SKINS:
			_add_item(skin["id"], skin["name"], skin["price"],
				PlayerData.owned_skins.has(skin["id"]),
				PlayerData.equipped_skin == skin["id"],
				"skin", skin["color"])
	else:
		for st in PlayerData.STARTERS:
			var suffix := ""
			if st["bullet_type"] > 0:
				var names := ["", "ELEC", "FIRE", "ICE", "BOOM", "RICO"]
				suffix = "  [%s]" % names[st["bullet_type"]]
			elif st["bullet_level"] > 1:
				suffix = "  [LV.%d]" % st["bullet_level"]
			_add_item(st["id"], st["name"] + suffix, st["price"],
				PlayerData.owned_starters.has(st["id"]),
				PlayerData.equipped_starter == st["id"],
				"starter", Color.TRANSPARENT)

func _add_item(item_id: int, item_name: String, price: int,
		owned: bool, equipped: bool, category: String, swatch: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Ô màu preview skin
	if swatch != Color.TRANSPARENT:
		var sw := ColorRect.new()
		sw.color = swatch
		sw.custom_minimum_size = Vector2(22, 22)
		row.add_child(sw)

	# Tên item
	var lbl := Label.new()
	lbl.text = item_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color",
		Color(0.85, 0.85, 0.85) if owned else Color(0.5, 0.5, 0.55))
	row.add_child(lbl)

	# Giá / trạng thái
	if equipped:
		var eq_lbl := Label.new()
		eq_lbl.text = "✔ ĐÃ TRANG BỊ"
		eq_lbl.add_theme_font_size_override("font_size", 15)
		eq_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		row.add_child(eq_lbl)
	elif owned:
		var btn := Button.new()
		btn.text = "TRANG BỊ"
		btn.custom_minimum_size = Vector2(110, 30)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func(): _on_equip(item_id, category))
		row.add_child(btn)
	else:
		var price_lbl := Label.new()
		price_lbl.text = "💰 %d" % price
		price_lbl.add_theme_font_size_override("font_size", 15)
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		price_lbl.custom_minimum_size = Vector2(90, 0)
		row.add_child(price_lbl)

		var btn := Button.new()
		btn.text = "MUA"
		btn.custom_minimum_size = Vector2(80, 30)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func(): _on_buy(item_id, category))
		row.add_child(btn)

	# Divider
	var sep := HSeparator.new()
	var wrapper := VBoxContainer.new()
	wrapper.add_child(row)
	wrapper.add_child(sep)
	wrapper.add_theme_constant_override("separation", 4)
	item_list.add_child(wrapper)

func _on_buy(item_id: int, category: String) -> void:
	var ok := false
	if category == "skin":
		ok = PlayerData.buy_skin(item_id)
		if ok: PlayerData.equip_skin(item_id)
	else:
		ok = PlayerData.buy_starter(item_id)
		if ok: PlayerData.equip_starter(item_id)
	if ok:
		Audio.play("buy")
		status_label.text = "✔ Mua thành công!"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	else:
		Audio.play("button_click")
		status_label.text = "✘ Không đủ coins!"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	_build_list()

func _on_equip(item_id: int, category: String) -> void:
	if category == "skin":
		PlayerData.equip_skin(item_id)
	else:
		PlayerData.equip_starter(item_id)
	_build_list()
