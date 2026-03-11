extends Node2D
# shop.gd — Cửa hàng mua skin và loại đạn khởi đầu

enum Tab { SKIN, STARTER }
var _current_tab: Tab = Tab.SKIN

@onready var coin_label:   Label         = $UI/TopBar/CoinLabel
@onready var tab_skin:     Button        = $UI/Tabs/SkinTab
@onready var tab_starter:  Button        = $UI/Tabs/StarterTab
@onready var item_list:    VBoxContainer = $UI/Scroll/ItemList
@onready var status_label: Label         = $UI/StatusLabel

const TAB_ACTIVE   := Color(0.3,  0.7,  1.0, 1.0)
const TAB_INACTIVE := Color(0.15, 0.18, 0.3, 1.0)
const C_GOLD       := Color(0.84, 0.72, 0.22)
const C_OLIVE      := Color(0.08, 0.14, 0.06)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
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
	for child in item_list.get_children():
		child.queue_free()
	coin_label.text = "💰 %d coins" % PlayerData.coins
	status_label.text = ""

	if _current_tab == Tab.SKIN:
		for skin: Dictionary in PlayerData.SKINS:
			_add_item(skin["id"], skin["name"], skin["price"],
				PlayerData.owned_skins.has(skin["id"]),
				PlayerData.equipped_skin == skin["id"],
				"skin", skin["color"])
	else:
		for st: Dictionary in PlayerData.STARTERS:
			var suffix: String = ""
			if st["bullet_type"] > 0:
				var names: Array[String] = ["", "ELEC", "FIRE", "ICE", "BOOM", "RICO"]
				suffix = "  [%s]" % names[st["bullet_type"]]
			elif st["bullet_level"] > 1:
				suffix = "  [LV.%d]" % st["bullet_level"]
			_add_item(st["id"], st["name"] + suffix, st["price"],
				PlayerData.owned_starters.has(st["id"]),
				PlayerData.equipped_starter == st["id"],
				"starter", Color.TRANSPARENT)

func _card_style(bg: Color, bdr: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = bdr
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(7)
	s.content_margin_left   = 10.0; s.content_margin_right  = 10.0
	s.content_margin_top    = 6.0;  s.content_margin_bottom = 6.0
	return s

func _btn_style(bg: Color, bdr: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg; s.border_color = bdr
	s.border_width_left = 1; s.border_width_right  = 1
	s.border_width_top  = 1; s.border_width_bottom = 1
	s.set_corner_radius_all(5)
	return s

func _add_item(item_id: int, item_name: String, price: int,
		owned: bool, equipped: bool, category: String, swatch: Color) -> void:

	var can_afford: bool = PlayerData.coins >= price

	# Card panel replaces plain VBoxContainer
	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 52)
	var card_bg: Color = Color(0.12, 0.20, 0.09, 0.92) if equipped else \
						 Color(0.08, 0.14, 0.06, 0.88)
	var card_bdr: Color = Color(0.55, 0.80, 0.45) if equipped else \
						  Color(0.38, 0.36, 0.16, 0.7)
	card.add_theme_stylebox_override("panel", _card_style(card_bg, card_bdr))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(row)

	# Anchor row inside card using anchors
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10; row.offset_right = -10
	row.offset_top  = 6;  row.offset_bottom = -6

	# Swatch
	if swatch != Color.TRANSPARENT:
		var sw := Panel.new()
		sw.custom_minimum_size = Vector2(28, 28)
		var sw_s := StyleBoxFlat.new()
		sw_s.bg_color = swatch
		sw_s.border_color = Color(swatch.r * 1.4, swatch.g * 1.4, swatch.b * 1.4).clamp()
		sw_s.border_width_left = 1; sw_s.border_width_right  = 1
		sw_s.border_width_top  = 1; sw_s.border_width_bottom = 1
		sw_s.set_corner_radius_all(3)
		sw.add_theme_stylebox_override("panel", sw_s)
		row.add_child(sw)

	# Item name label
	var lbl := Label.new()
	lbl.text = item_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 17)
	var name_col: Color = Color(0.95, 0.90, 0.65) if owned else Color(0.55, 0.52, 0.40)
	lbl.add_theme_color_override("font_color", name_col)
	row.add_child(lbl)

	# Right-side widget
	if equipped:
		var badge := Panel.new()
		badge.custom_minimum_size = Vector2(130, 30)
		var b_s := StyleBoxFlat.new()
		b_s.bg_color = Color(0.06, 0.22, 0.08, 0.95)
		b_s.border_color = Color(0.3, 0.85, 0.45)
		b_s.border_width_left = 1; b_s.border_width_right  = 1
		b_s.border_width_top  = 1; b_s.border_width_bottom = 1
		b_s.set_corner_radius_all(5)
		badge.add_theme_stylebox_override("panel", b_s)
		var badge_lbl := Label.new()
		badge_lbl.text = "✔ ĐÃ TRANG BỊ"
		badge_lbl.add_theme_font_size_override("font_size", 13)
		badge_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		badge_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		badge.add_child(badge_lbl)
		row.add_child(badge)

	elif owned:
		var btn := Button.new()
		btn.text = "TRANG BỊ"
		btn.custom_minimum_size = Vector2(110, 30)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color",       Color(0.55, 1.0, 0.6))
		btn.add_theme_color_override("font_hover_color", Color(0.8, 1.0, 0.8))
		btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.08,0.22,0.10), Color(0.3,0.75,0.45)))
		btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.12,0.32,0.15), Color(0.4,0.90,0.55)))
		btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.05,0.14,0.07), Color(0.3,0.75,0.45)))
		btn.pressed.connect(func(): _on_equip(item_id, category))
		row.add_child(btn)

	else:
		# Price — red tint if cannot afford
		var price_lbl := Label.new()
		if can_afford:
			price_lbl.text = "💰 %d" % price
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		else:
			price_lbl.text = "💰 %d  (thiếu %d)" % [price, price - PlayerData.coins]
			price_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.custom_minimum_size = Vector2(130, 0)
		row.add_child(price_lbl)

		var btn := Button.new()
		btn.text = "MUA"
		btn.custom_minimum_size = Vector2(80, 30)
		btn.add_theme_font_size_override("font_size", 14)
		btn.disabled = not can_afford
		if can_afford:
			btn.add_theme_color_override("font_color",       Color(1.0, 0.95, 0.2))
			btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.5))
			btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.28,0.20,0.04), C_GOLD))
			btn.add_theme_stylebox_override("hover",   _btn_style(Color(0.38,0.28,0.06), Color(1.0,0.9,0.3)))
			btn.add_theme_stylebox_override("pressed", _btn_style(Color(0.18,0.14,0.03), C_GOLD))
		else:
			btn.add_theme_stylebox_override("normal",  _btn_style(Color(0.18,0.14,0.12), Color(0.35,0.28,0.28)))
			btn.add_theme_color_override("font_color", Color(0.45, 0.40, 0.40))
		btn.pressed.connect(func(): _on_buy(item_id, category))
		row.add_child(btn)

	item_list.add_child(card)
	# Small gap between cards
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	item_list.add_child(spacer)

func _on_buy(item_id: int, category: String) -> void:
	var ok: bool = false
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

