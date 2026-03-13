extends Control

# Data structure for tabs and slots
const TABS = [
	{"id": "main_weapon", "name": "Vũ Khí Chính"},
	{"id": "sub_weapon", "name": "Vũ Khí Phụ"},
	{"id": "skill", "name": "Kỹ Năng"},
	{"id": "armor", "name": "Giáp"},
	{"id": "accessory", "name": "Phụ Kiện"},
	{"id": "special", "name": "Đặc Biệt"}
]

var current_tab_id: String = "main_weapon"
var selected_item_id: String = ""

# UI Nodes
var coin_label: Label
var item_list_vbox: VBoxContainer
var detail_panel: Panel
var item_info_label: RichTextLabel
var equip_btn: Button
var unequip_btn: Button
var upgrade_btn: Button
var slot_buttons: Dictionary = {}

var confirm_popup: Panel

func _ready() -> void:
	# Bố cục desktop 1152x720
	size = Vector2(1152, 720)
	
	# Background
	var bg = ColorRect.new()
	bg.size = size
	bg.color = Color(0.05, 0.08, 0.05, 1.0) # Màu tối quân sự
	add_child(bg)
	
	# Pattern hoặc lưới mờ (tùy chọn UI)
	var grid = ColorRect.new()
	grid.size = size
	grid.color = Color(0.2, 0.3, 0.2, 0.1)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grid)
	
	_build_top_bar()
	_build_left_panel()
	_build_right_panel()
	_build_bottom_bar()
	_build_confirm_popup()
	
	# Load data
	PlayerData.load_data()
	
	# Cấp free một số món nếu chưa có để test
	if not PlayerData.inventory.has("wpn_ak47"): PlayerData.inventory["wpn_ak47"] = 1
	if not PlayerData.inventory.has("sub_pistol"): PlayerData.inventory["sub_pistol"] = 1
	
	_refresh_ui()

func _build_top_bar():
	var top = ColorRect.new()
	top.size = Vector2(1152, 60)
	top.color = Color(0.1, 0.15, 0.1, 0.9)
	add_child(top)
	
	# Nút Back
	var back_btn = Button.new()
	back_btn.text = "◀ QUAY LẠI"
	back_btn.position = Vector2(20, 10)
	back_btn.size = Vector2(120, 40)
	back_btn.add_theme_color_override("font_color", Color(0.8, 0.9, 0.8))
	_style_btn(back_btn, Color(0.2, 0.3, 0.2), Color(0.4, 0.6, 0.4))
	back_btn.pressed.connect(_on_back_pressed)
	top.add_child(back_btn)
	
	# Tiêu đề
	var title = Label.new()
	title.text = "TRẠM TRANG BỊ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(400, 60)
	title.position = Vector2(376, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	top.add_child(title)
	
	# Tài nguyên
	coin_label = Label.new()
	coin_label.text = "💰 0"
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	coin_label.size = Vector2(200, 60)
	coin_label.position = Vector2(932, 0)
	coin_label.add_theme_font_size_override("font_size", 24)
	coin_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	top.add_child(coin_label)

func _build_left_panel():
	var pnl = Panel.new()
	pnl.size = Vector2(400, 520)
	pnl.position = Vector2(40, 90)
	_style_panel(pnl, Color(0.08, 0.12, 0.08), Color(0.3, 0.4, 0.3))
	add_child(pnl)
	
	# Silhouette nhân vật
	var sil = ColorRect.new()
	sil.size = Vector2(120, 240)
	sil.position = Vector2(140, 100)
	sil.color = Color(0.3, 0.4, 0.3, 0.3)
	pnl.add_child(sil)
	var lbl = Label.new()
	lbl.text = "NHÂN VẬT"
	lbl.position = Vector2(0, 100)
	lbl.size = Vector2(120, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sil.add_child(lbl)
	
	# Các ô chứa trang bị
	var slot_positions = [
		{"id": "main_weapon", "pos": Vector2(20, 60), "name": "Vũ Khí Chính"},
		{"id": "skill", "pos": Vector2(20, 180), "name": "Kỹ Năng"},
		{"id": "accessory", "pos": Vector2(20, 300), "name": "Phụ Kiện"},
		{"id": "sub_weapon", "pos": Vector2(280, 60), "name": "Vũ Khí Phụ"},
		{"id": "armor", "pos": Vector2(280, 180), "name": "Giáp"},
		{"id": "special", "pos": Vector2(280, 300), "name": "Đặc Biệt"}
	]
	
	for s in slot_positions:
		var btn = Button.new()
		btn.size = Vector2(100, 100)
		btn.position = s.pos
		_style_slot(btn)
		
		# Tên slot
		var sl_lbl = Label.new()
		sl_lbl.text = s.name
		sl_lbl.size = Vector2(100, 20)
		sl_lbl.position = Vector2(0, -25)
		sl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl_lbl.add_theme_font_size_override("font_size", 14)
		btn.add_child(sl_lbl)
		
		btn.pressed.connect(func(): _on_tab_selected(s.id))
		pnl.add_child(btn)
		slot_buttons[s.id] = btn

func _build_right_panel():
	# Tabs
	var tab_pnl = Control.new()
	tab_pnl.size = Vector2(650, 40)
	tab_pnl.position = Vector2(460, 90)
	add_child(tab_pnl)
	
	var tab_w = 105
	for i in range(TABS.size()):
		var t = TABS[i]
		var btn = Button.new()
		btn.text = t.name
		btn.size = Vector2(tab_w, 40)
		btn.position = Vector2(i * (tab_w + 5), 0)
		btn.name = "Tab_" + t.id
		_style_btn(btn, Color(0.15, 0.2, 0.15), Color(0.3, 0.4, 0.3))
		btn.pressed.connect(func(): _on_tab_selected(t.id))
		tab_pnl.add_child(btn)
		
	# Item List Panel
	var list_pnl = Panel.new()
	list_pnl.size = Vector2(340, 470)
	list_pnl.position = Vector2(460, 140)
	_style_panel(list_pnl, Color(0.08, 0.12, 0.08), Color(0.3, 0.4, 0.3))
	add_child(list_pnl)
	
	var scroll = ScrollContainer.new()
	scroll.size = Vector2(320, 450)
	scroll.position = Vector2(10, 10)
	list_pnl.add_child(scroll)
	
	item_list_vbox = VBoxContainer.new()
	item_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_list_vbox)
	
	# Detail Panel
	detail_panel = Panel.new()
	detail_panel.size = Vector2(300, 470)
	detail_panel.position = Vector2(810, 140)
	_style_panel(detail_panel, Color(0.06, 0.09, 0.06), Color(0.5, 0.6, 0.5))
	add_child(detail_panel)
	
	item_info_label = RichTextLabel.new()
	item_info_label.size = Vector2(280, 450)
	item_info_label.position = Vector2(10, 10)
	item_info_label.bbcode_enabled = true
	item_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_info_label.add_theme_font_size_override("font_size", 14)
	detail_panel.add_child(item_info_label)

func _build_bottom_bar():
	var bot = ColorRect.new()
	bot.size = Vector2(1152, 80)
	bot.position = Vector2(0, 640)
	bot.color = Color(0.1, 0.15, 0.1, 0.9)
	add_child(bot)
	
	equip_btn = Button.new()
	equip_btn.text = "📥 TRANG BỊ"
	equip_btn.size = Vector2(180, 50)
	equip_btn.position = Vector2(460, 15)
	_style_btn(equip_btn, Color(0.2, 0.5, 0.2), Color(0.4, 0.8, 0.4))
	equip_btn.pressed.connect(_on_equip_pressed)
	bot.add_child(equip_btn)
	
	unequip_btn = Button.new()
	unequip_btn.text = "📤 THÁO"
	unequip_btn.size = Vector2(120, 50)
	unequip_btn.position = Vector2(650, 15)
	_style_btn(unequip_btn, Color(0.5, 0.3, 0.2), Color(0.8, 0.5, 0.4))
	unequip_btn.pressed.connect(_on_unequip_pressed)
	bot.add_child(unequip_btn)
	
	upgrade_btn = Button.new()
	upgrade_btn.text = "⭐ NÂNG CẤP"
	upgrade_btn.size = Vector2(180, 50)
	upgrade_btn.position = Vector2(930, 15)
	_style_btn(upgrade_btn, Color(0.2, 0.3, 0.6), Color(0.4, 0.6, 1.0))
	upgrade_btn.pressed.connect(_on_upgrade_pressed)
	bot.add_child(upgrade_btn)

func _build_confirm_popup():
	confirm_popup = Panel.new()
	confirm_popup.size = Vector2(400, 200)
	confirm_popup.position = Vector2(376, 260)
	confirm_popup.visible = false
	confirm_popup.z_index = 100
	_style_panel(confirm_popup, Color(0.1, 0.1, 0.1, 0.95), Color(1.0, 0.8, 0.2))
	add_child(confirm_popup)
	
	var lbl = Label.new()
	lbl.name = "Msg"
	lbl.text = "Bạn có chắc chắn muốn nâng cấp?"
	lbl.size = Vector2(380, 100)
	lbl.position = Vector2(10, 20)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_popup.add_child(lbl)
	
	var btn_ok = Button.new()
	btn_ok.name = "BtnOK"
	btn_ok.text = "Đồng ý"
	btn_ok.size = Vector2(120, 40)
	btn_ok.position = Vector2(60, 140)
	_style_btn(btn_ok, Color(0.2, 0.5, 0.2), Color(0.4, 0.8, 0.4))
	confirm_popup.add_child(btn_ok)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Hủy"
	btn_cancel.size = Vector2(120, 40)
	btn_cancel.position = Vector2(220, 140)
	_style_btn(btn_cancel, Color(0.5, 0.2, 0.2), Color(0.8, 0.4, 0.4))
	btn_cancel.pressed.connect(func(): confirm_popup.hide())
	confirm_popup.add_child(btn_cancel)

func _refresh_ui():
	coin_label.text = "💰 %d" % PlayerData.coins
	
	# Update Slots
	for slot_id in slot_buttons.keys():
		var btn = slot_buttons[slot_id] as Button
		var item_id = PlayerData.loadout.get(slot_id, "")
		if item_id == "":
			btn.text = "Trống"
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			_style_slot(btn)
		else:
			var it = ItemDatabase.get_item(item_id)
			if it.is_empty(): continue
			var lvl = PlayerData.inventory.get(item_id, 1)
			btn.text = "%s\nLv.%d" % [it.name, lvl]
			var rare_col = ItemDatabase.RARITY_COLORS.get(it.rarity, Color.WHITE)
			btn.add_theme_color_override("font_color", rare_col)
			_style_slot(btn, rare_col)
	
	_populate_item_list()
	_update_detail_panel()

func _on_tab_selected(tab_id: String):
	current_tab_id = tab_id
	selected_item_id = ""
	Audio.play("button_click")
	
	# Highlight the active tab (Optional visual logic)
	for i in range(TABS.size()):
		var t = TABS[i]
		var btn = get_node_or_null("Tab_" + t.id)
		if btn:
			if t.id == tab_id:
				_style_btn(btn, Color(0.3, 0.4, 0.3), Color(0.6, 0.8, 0.6))
			else:
				_style_btn(btn, Color(0.15, 0.2, 0.15), Color(0.3, 0.4, 0.3))
	
	_refresh_ui()

func _populate_item_list():
	for c in item_list_vbox.get_children():
		c.queue_free()
		
	var items = ItemDatabase.get_all_items()
	for it in items:
		if it.type != current_tab_id: continue
		
		# Kẻ viền cho item trong danh sách
		var pnl = PanelContainer.new()
		pnl.custom_minimum_size = Vector2(320, 60)
		
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.12, 0.15, 0.12) if selected_item_id != it.id else Color(0.2, 0.3, 0.2)
		s.border_width_bottom = 1
		s.border_color = Color(0.3, 0.4, 0.3)
		pnl.add_theme_stylebox_override("panel", s)
		
		var hbox = HBoxContainer.new()
		pnl.add_child(hbox)
		
		var owns = PlayerData.inventory.has(it.id)
		var is_equipped = (PlayerData.loadout.get(current_tab_id) == it.id)
		
		var rare_col = ItemDatabase.RARITY_COLORS.get(it.rarity, Color.WHITE)
		
		var name_lbl = Label.new()
		name_lbl.text = it.name
		name_lbl.custom_minimum_size = Vector2(160, 0)
		name_lbl.add_theme_color_override("font_color", rare_col)
		if not owns:
			name_lbl.modulate.a = 0.5
		hbox.add_child(name_lbl)
		
		var lvl_lbl = Label.new()
		if owns:
			lvl_lbl.text = "Lv.%d" % PlayerData.inventory[it.id]
			lvl_lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			lvl_lbl.text = "Khóa"
			lvl_lbl.add_theme_color_override("font_color", Color.RED)
		lvl_lbl.custom_minimum_size = Vector2(60, 0)
		hbox.add_child(lvl_lbl)
		
		var eq_lbl = Label.new()
		if is_equipped:
			eq_lbl.text = "[Đã Gắn]"
			eq_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
		hbox.add_child(eq_lbl)
		
		# Invisible button to capture click
		var btn = Button.new()
		btn.flat = true
		btn.size = Vector2(320, 60)
		btn.pressed.connect(func(): _on_item_select(it.id))
		pnl.add_child(btn)
		
		item_list_vbox.add_child(pnl)

func _on_item_select(item_id: String):
	selected_item_id = item_id
	Audio.play("button_click")
	
	# Tween anim nhẹ cho panel detail
	detail_panel.modulate.a = 0.5
	var tw = create_tween()
	tw.tween_property(detail_panel, "modulate:a", 1.0, 0.15)
	
	_refresh_ui()

func _update_detail_panel():
	if selected_item_id == "":
		item_info_label.text = "Chọn một trang bị để xem chi tiết."
		equip_btn.disabled = true
		unequip_btn.disabled = true
		upgrade_btn.disabled = true
		return
		
	var it = ItemDatabase.get_item(selected_item_id)
	var owns = PlayerData.inventory.has(selected_item_id)
	var lvl = PlayerData.inventory.get(selected_item_id, 1)
	var is_equipped = (PlayerData.loadout.get(current_tab_id) == selected_item_id)
	
	var col_hex = ItemDatabase.RARITY_COLORS.get(it.rarity, Color.WHITE).to_html()
	var is_implemented = ItemDatabase.is_item_implemented(selected_item_id)
	
	var bbcode = "[font_size=20][color=#%s]%s[/color][/font_size]\n" % [col_hex, it.name]
	bbcode += "Loại: %s | Phẩm chất: [color=#%s]%s[/color]\n\n" % [it.type.capitalize(), col_hex, it.rarity]
	bbcode += "%s\n\n" % it.desc
	if not is_implemented:
		bbcode += "[color=#FFA500]Trạng thái: Đang phát triển[/color]\n\n"
	
	bbcode += "[font_size=16][color=#FFFF00]CHỈ SỐ (Lv.%d)[/color][/font_size]\n" % lvl
	
	# Chỉ số
	var stats = it.stats.keys()
	var current_eq_id = PlayerData.loadout.get(current_tab_id, "")
	
	for s in stats:
		var val = ItemDatabase.get_stat(it.id, s, lvl)
		var cmp_str = ""
		
		# Tính so sánh nếu người chơi đang chọn item khác với item đã trang bị
		if current_eq_id != "" and current_eq_id != it.id and ItemDatabase.get_item(current_eq_id).stats.has(s):
			var eq_lvl = PlayerData.inventory.get(current_eq_id, 1)
			var eq_val = ItemDatabase.get_stat(current_eq_id, s, eq_lvl)
			var diff = val - eq_val
			# Đối với cooldown và fire_rate, nhỏ hơn là tốt hơn (màu xanh)
			var good_dir = 1.0
			if s in ["cooldown", "fire_rate"]: good_dir = -1.0
			
			if diff * good_dir > 0:
				cmp_str = " [color=#00FF00](+%0.2f)[/color]" % abs(diff)
			elif diff * good_dir < 0:
				cmp_str = " [color=#FF0000](-%0.2f)[/color]" % abs(diff)
				
		bbcode += "- %s: %0.2f%s\n" % [s.capitalize(), val, cmp_str]
	
	# Unlock / Upgrade info
	bbcode += "\n"
	if not owns:
		bbcode += "[color=#FF5555]Chưa sở hữu.[/color]\nGiá mua: [color=#FFD700]💰 %d[/color]\n" % it.base_cost
	else:
		if lvl < it.max_level:
			var cost = ItemDatabase.get_upgrade_cost(it.id, lvl)
			bbcode += "Cấp tiếp theo: Lv.%d\nPhí nâng cấp: [color=#FFD700]💰 %d[/color]\n" % [lvl + 1, cost]
		else:
			bbcode += "[color=#55FF55]ĐÃ TỐI ĐA (MAX LEVEL)[/color]\n"
	
	item_info_label.text = bbcode
	
	# Buttons logic
	equip_btn.disabled = not owns or is_equipped
	unequip_btn.disabled = not owns or not is_equipped
	upgrade_btn.disabled = false
	if not owns:
		upgrade_btn.text = "🛒 MUA"
		if PlayerData.coins < it.base_cost: upgrade_btn.disabled = true
	else:
		upgrade_btn.text = "⭐ NÂNG CẤP"
		if lvl >= it.max_level: upgrade_btn.disabled = true
		elif PlayerData.coins < ItemDatabase.get_upgrade_cost(it.id, lvl): upgrade_btn.disabled = true

func _on_equip_pressed():
	if selected_item_id != "":
		PlayerData.loadout[current_tab_id] = selected_item_id
		PlayerData.save_data()
		Audio.play("equip") # Giả định có SFX này hoặc thay bằng button_click
		_pop_anim(equip_btn)
		_refresh_ui()

func _on_unequip_pressed():
	PlayerData.loadout[current_tab_id] = ""
	PlayerData.save_data()
	Audio.play("equip")
	_pop_anim(unequip_btn)
	_refresh_ui()

func _on_upgrade_pressed():
	var it = ItemDatabase.get_item(selected_item_id)
	var owns = PlayerData.inventory.has(selected_item_id)
	var cost = 0
	if not owns:
		cost = it.base_cost
	else:
		var lvl = PlayerData.inventory.get(selected_item_id, 1)
		cost = ItemDatabase.get_upgrade_cost(selected_item_id, lvl)
	
	var msg_node = confirm_popup.get_node("Msg")
	if owns:
		msg_node.text = "Nâng cấp %s lên Lv.%d với %d coins?" % [it.name, PlayerData.inventory[selected_item_id] + 1, cost]
	else:
		msg_node.text = "Mua %s với %d coins?" % [it.name, cost]
		
	var btn_ok = confirm_popup.get_node("BtnOK")
	# Xóa kết nối cũ
	var conns = btn_ok.pressed.get_connections()
	for c in conns:
		btn_ok.pressed.disconnect(c.callable)
		
	btn_ok.pressed.connect(func():
		if PlayerData.spend_coins(cost):
			if not owns:
				PlayerData.inventory[selected_item_id] = 1
			else:
				PlayerData.inventory[selected_item_id] += 1
			PlayerData.save_data()
			Audio.play("upgrade") # Giả định âm thanh
			_pop_anim(upgrade_btn)
			confirm_popup.hide()
			_refresh_ui()
	)
	
	confirm_popup.show()
	_pop_anim(confirm_popup)

func _on_back_pressed():
	Audio.play("button_click")
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")

# Utilities
func _style_btn(btn: Button, bg_col: Color, bdr_col: Color):
	var s = StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = bdr_col
	s.border_width_bottom = 3
	s.set_corner_radius_all(4)
	var sh = s.duplicate(); sh.bg_color = bg_col.lightened(0.2)
	var sp = s.duplicate(); sp.border_width_bottom = 0; sp.bg_color = bg_col.darkened(0.2)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sp)

func _style_panel(pnl: Panel, bg_col: Color, bdr_col: Color):
	var s = StyleBoxFlat.new()
	s.bg_color = bg_col
	s.border_color = bdr_col
	s.border_width_left = 2; s.border_width_right = 2
	s.border_width_top = 2; s.border_width_bottom = 2
	s.set_corner_radius_all(6)
	pnl.add_theme_stylebox_override("panel", s)

func _style_slot(btn: Button, rarity_col: Color = Color(0.3, 0.4, 0.3)):
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.15, 0.1)
	s.border_color = rarity_col
	s.set_border_width_all(2)
	btn.add_theme_stylebox_override("normal", s)

func _pop_anim(node: Control):
	var s = node.scale
	var tw = create_tween()
	tw.tween_property(node, "scale", s * 1.1, 0.1)
	tw.tween_property(node, "scale", s, 0.1)
