extends Control

# contra_level_select.gd — Vietnam Guerrilla Warfare Theme
# Redesigned UI: jungle palette, red star accents, military brass typography

# ── Colour Palette ──────────────────────────────────────────────────────────
const C_BG_DEEP    := Color(0.04, 0.07, 0.03)        # Đêm rừng
const C_BG_PANEL   := Color(0.07, 0.12, 0.05, 0.95)  # Panel tối
const C_MIL_GREEN  := Color(0.12, 0.20, 0.08)        # Xanh quân phục
const C_HOVER_GRN  := Color(0.18, 0.30, 0.12)        # Hover card
const C_FOLIAGE    := Color(0.22, 0.36, 0.14)        # Tán lá
const C_GOLD       := Color(0.84, 0.72, 0.22)        # Đồng brass
const C_GOLD_DIM   := Color(0.52, 0.44, 0.15)        # Đồng mờ
const C_RED_STAR   := Color(0.82, 0.14, 0.14)        # Sao đỏ
const C_RED_DIM    := Color(0.50, 0.10, 0.10)        # Sao đỏ mờ
const C_BAMBOO     := Color(0.70, 0.62, 0.30)        # Tre vàng
const C_PARCHMENT  := Color(0.94, 0.90, 0.74)        # Giấy cũ
const C_TEXT_DIM   := Color(0.58, 0.54, 0.40)        # Chữ mờ
const C_LOCKED_BG  := Color(0.08, 0.10, 0.07)        # Nền khoá
const C_LOCKED_TXT := Color(0.38, 0.36, 0.30)        # Chữ khoá

const DIFF_COLORS := [
	Color(0.28, 0.80, 0.32),   # Dễ – xanh lá
	Color(0.90, 0.80, 0.14),   # Trung bình – vàng
	Color(0.96, 0.52, 0.10),   # Khó – cam
	Color(0.92, 0.20, 0.18),   # Rất khó – đỏ
	Color(0.80, 0.08, 0.45),   # Tử thần – đỏ tím
]

var stage_data: Array = [
	{
		"num"   : "MÀN 1",
		"title" : "RỪNG SÂU",
		"desc"  : "Đại đội Mỹ tuần tra\ndày đặc dưới tán rừng\nnhiệt đới.",
		"diff"  : "DỄ",
		"icon"  : "I",
	},
	{
		"num"   : "MÀN 2",
		"title" : "ĐỊA ĐẠO CỦ CHI",
		"desc"  : "Địa hình hẹp và tối.\nLính ẩn nấp khắp nơi\ntrong địa đạo.",
		"diff"  : "TRUNG BÌNH",
		"icon"  : "II",
	},
	{
		"num"   : "MÀN 3",
		"title" : "ĐƯỜNG TRƯỜNG SƠN",
		"desc"  : "Máy bay B-52 ném bom\nliên tục. Địa hình\nkhắc nghiệt.",
		"diff"  : "KHÓ",
		"icon"  : "III",
	},
	{
		"num"   : "MÀN 4",
		"title" : "CĂN CỨ ĐỊA",
		"desc"  : "Đồn bốt kiên cố.\nHỏa lực pháo đài\ncực kỳ mạnh.",
		"diff"  : "RẤT KHÓ",
		"icon"  : "IV",
	},
	{
		"num"   : "MÀN 5",
		"title" : "TỔNG TẤN CÔNG",
		"desc"  : "Chiến dịch Hồ Chí\nMinh lịch sử. Giải\nphóng tổ quốc.",
		"diff"  : "TỬ THẦN",
		"icon"  : "V",
	},
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.load_data()
	_build_ui()

# ════════════════════════════════════════════════════════════════════════════
func _build_ui() -> void:
	var vp := get_viewport_rect().size
	_make_background(vp)
	_make_title_area(vp)
	_make_cards(vp)
	# _make_controls_panel(vp) # Moved to Main Menu
	_make_equip_button(vp)
	_make_back_button(vp)

# ── Background ───────────────────────────────────────────────────────────────
func _make_background(vp: Vector2) -> void:
	# Base fill
	var bg := ColorRect.new()
	bg.size = vp
	bg.color = C_BG_DEEP
	add_child(bg)

	# Subtle mid-tint strip (gives depth)
	var mid := ColorRect.new()
	mid.position = Vector2(0, vp.y * 0.18)
	mid.size     = Vector2(vp.x, vp.y * 0.64)
	mid.color    = Color(0.06, 0.10, 0.04, 0.45)
	add_child(mid)

	# Red border frame – 4 thin bars
	for bar_rect in [
		Rect2(0,          0,           vp.x, 3),
		Rect2(0,          vp.y - 3,   vp.x, 3),
		Rect2(0,          0,           3,    vp.y),
		Rect2(vp.x - 3,  0,           3,    vp.y),
	]:
		var bar := ColorRect.new()
		bar.position = bar_rect.position
		bar.size     = bar_rect.size
		bar.color    = C_RED_STAR
		add_child(bar)

	# Gold inner frame (offset 6 px)
	for bar_rect in [
		Rect2(6,          6,           vp.x - 12,  1),
		Rect2(6,          vp.y - 7,   vp.x - 12,  1),
		Rect2(6,          6,           1,           vp.y - 12),
		Rect2(vp.x - 7,  6,           1,           vp.y - 12),
	]:
		var bar := ColorRect.new()
		bar.position = bar_rect.position
		bar.size     = bar_rect.size
		bar.color    = C_GOLD_DIM
		add_child(bar)

	# Divider under title section
	var div := ColorRect.new()
	div.position = Vector2(40, 118)
	div.size     = Vector2(vp.x - 80, 1)
	div.color    = C_GOLD_DIM
	add_child(div)

	# Divider above bottom bar
	var div2 := ColorRect.new()
	div2.position = Vector2(40, vp.y - 62)
	div2.size     = Vector2(vp.x - 80, 1)
	div2.color    = C_GOLD_DIM
	add_child(div2)

# ── Title area ───────────────────────────────────────────────────────────────
func _make_title_area(vp: Vector2) -> void:
	# Left red star
	_lbl("★", Vector2(vp.x * 0.5 - 230, 14), Vector2(48, 52), 28, C_RED_STAR)
	# Right red star
	_lbl("★", Vector2(vp.x * 0.5 + 182, 14), Vector2(48, 52), 28, C_RED_STAR)

	# Main title
	var title := _lbl(
		"CHỌN CHIẾN DỊCH LỊCH SỬ",
		Vector2(0, 16), Vector2(vp.x, 54),
		36, C_GOLD
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)

	# Subtitle
	var sub := _lbl(
		"CHIẾN TRANH DU KÍCH VIỆT NAM  ·  GIẢI PHÓNG TỔ QUỐC",
		Vector2(0, 68), Vector2(vp.x, 22),
		12, C_TEXT_DIM
	)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Ornament
	var orn := _lbl("— ✦ ⊹ ✦ —", Vector2(0, 90), Vector2(vp.x, 22), 14, C_GOLD_DIM)
	orn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

# ── Level cards (5 in a horizontal row) ─────────────────────────────────────
func _make_cards(vp: Vector2) -> void:
	var unlocked := PlayerData.get_unlocked_stage()

	const COLS   := 5
	const CARD_W := 185.0
	const CARD_H := 370.0
	const GAP    := 18.0

	var total_w := CARD_W * COLS + GAP * (COLS - 1)
	var sx      := (vp.x - total_w) * 0.5
	var sy      := 130.0

	for i in range(5):
		var cx := sx + i * (CARD_W + GAP)
		_make_card(i, Vector2(cx, sy), Vector2(CARD_W, CARD_H), unlocked)

func _make_card(idx: int, pos: Vector2, sz: Vector2, unlocked: int) -> void:
	var data: Dictionary = stage_data[idx]
	var stage_num := idx + 1
	var locked    := stage_num > unlocked
	var diff_col: Color = DIFF_COLORS[idx]

	# ── Card panel ────────────────────────────────────────────────────────────
	var panel := Panel.new()
	panel.position = pos
	panel.size     = sz

	var sbox := StyleBoxFlat.new()
	sbox.set_corner_radius_all(8)
	sbox.border_width_left   = 2
	sbox.border_width_right  = 2
	sbox.border_width_top    = 2
	sbox.border_width_bottom = 2
	sbox.bg_color     = C_LOCKED_BG  if locked else C_MIL_GREEN
	sbox.border_color = Color(0.22, 0.26, 0.18, 0.7)  if locked else C_GOLD_DIM
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	# Accent top-bar per card (colour of difficulty)
	if not locked:
		var accent := ColorRect.new()
		accent.position = Vector2(pos.x + 2, pos.y + 2)
		accent.size     = Vector2(sz.x - 4, 4)
		accent.color    = diff_col
		add_child(accent)

	# ── Roman numeral badge ───────────────────────────────────────────────────
	var badge_bg := ColorRect.new()
	badge_bg.position = Vector2(pos.x + sz.x * 0.5 - 22, pos.y + 14)
	badge_bg.size     = Vector2(44, 30)
	badge_bg.color    = C_RED_STAR  if not locked else Color(0.20, 0.20, 0.18)
	add_child(badge_bg)

	var badge_lbl := _lbl(
		data["icon"],
		Vector2(pos.x + sz.x * 0.5 - 22, pos.y + 14),
		Vector2(44, 30), 13, Color.WHITE
	)
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ── LOCKED STATE ──────────────────────────────────────────────────────────
	if locked:
		_lbl("🔒",  Vector2(pos.x, pos.y + 100), Vector2(sz.x, 50), 34, C_LOCKED_TXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var lk := _lbl(
			"CHƯA MỞ KHÓA\n\nHoàn thành màn %d\nđể mở khóa màn này" % idx,
			Vector2(pos.x + 8, pos.y + 158), Vector2(sz.x - 16, 100),
			10, C_LOCKED_TXT
		)
		lk.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
		lk.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
		return

	# ── UNLOCKED STATE ────────────────────────────────────────────────────────

	# Mission label ("MÀN X")
	var num_lbl := _lbl(
		data["num"],
		Vector2(pos.x, pos.y + 56), Vector2(sz.x, 18),
		10, C_BAMBOO
	)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Mission title
	var title_lbl := _lbl(
		data["title"],
		Vector2(pos.x + 6, pos.y + 72), Vector2(sz.x - 12, 42),
		15, C_PARCHMENT
	)
	title_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title_lbl.add_theme_constant_override("shadow_offset_x", 1)
	title_lbl.add_theme_constant_override("shadow_offset_y", 1)

	# Thin gold divider
	var div := ColorRect.new()
	div.position = Vector2(pos.x + 20, pos.y + 116)
	div.size     = Vector2(sz.x - 40, 1)
	div.color    = C_GOLD_DIM
	add_child(div)

	# Description
	var desc_lbl := _lbl(
		data["desc"],
		Vector2(pos.x + 8, pos.y + 122), Vector2(sz.x - 16, 66),
		10, C_TEXT_DIM
	)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART

	# ── Difficulty section ────────────────────────────────────────────────────
	var diff_y := pos.y + 198.0

	# Diff bg strip
	var diff_bg := ColorRect.new()
	diff_bg.position = Vector2(pos.x + 12, diff_y)
	diff_bg.size     = Vector2(sz.x - 24, 24)
	diff_bg.color    = Color(diff_col.r, diff_col.g, diff_col.b, 0.14)
	add_child(diff_bg)

	# Top border of diff strip
	var diff_line := ColorRect.new()
	diff_line.position = Vector2(pos.x + 12, diff_y)
	diff_line.size     = Vector2(sz.x - 24, 1)
	diff_line.color    = diff_col
	add_child(diff_line)

	# "ĐỘ KHÓ:" prefix
	_lbl("ĐỘ KHÓ:", Vector2(pos.x + 16, diff_y + 6), Vector2(52, 14), 9, C_TEXT_DIM)

	# Difficulty value
	_lbl(data["diff"], Vector2(pos.x + 70, diff_y + 6), Vector2(sz.x - 86, 14), 9, diff_col)

	# ── Star rating (1–5) ─────────────────────────────────────────────────────
	var star_y := diff_y + 34.0
	var filled := stage_num
	var stars  := ""
	for s in range(5):
		stars += ("★" if s < filled else "☆")
	var star_lbl := _lbl(stars, Vector2(pos.x, star_y), Vector2(sz.x, 20), 14, diff_col)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ── Thin separator before button ─────────────────────────────────────────
	var sep := ColorRect.new()
	sep.position = Vector2(pos.x + 20, star_y + 30)
	sep.size     = Vector2(sz.x - 40, 1)
	sep.color    = C_GOLD_DIM
	add_child(sep)

	# ── "THAM CHIẾN" button ───────────────────────────────────────────────────
	var btn_y  := star_y + 40.0
	var btn_mh := sz.y - (btn_y - pos.y) - 14.0

	var btn := Button.new()
	btn.position                  = Vector2(pos.x + 12, btn_y)
	btn.size                      = Vector2(sz.x - 24, maxf(btn_mh, 38))
	btn.text                      = "▶  RA TRẬN"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bs_n := StyleBoxFlat.new()
	bs_n.bg_color = C_FOLIAGE
	bs_n.border_color = C_GOLD_DIM
	bs_n.border_width_left = 1; bs_n.border_width_right = 1
	bs_n.border_width_top  = 1; bs_n.border_width_bottom = 1
	bs_n.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", bs_n)

	var bs_h := bs_n.duplicate()
	bs_h.bg_color     = C_GOLD
	bs_h.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover",   bs_h)
	btn.add_theme_stylebox_override("pressed", bs_h)

	btn.add_theme_font_size_override("font_size",        12)
	btn.add_theme_color_override("font_color",           C_PARCHMENT)
	btn.add_theme_color_override("font_focus_color",     C_PARCHMENT)
	btn.add_theme_color_override("font_hover_color",     C_BG_DEEP)
	btn.add_theme_color_override("font_pressed_color",   C_BG_DEEP)
	btn.pressed.connect(_on_level_pressed.bind(stage_num))
	add_child(btn)

# ── Controls reference panel (bottom-left) ───────────────────────────────────
func _make_controls_panel(vp: Vector2) -> void:
	const PW  := 240.0
	const PH  := 198.0
	var   px  := 14.0
	var   py  := vp.y - PH - 10.0

	var panel := Panel.new()
	panel.position = Vector2(px, py)
	panel.size     = Vector2(PW, PH)
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = C_BG_PANEL
	sbox.border_color = C_GOLD_DIM
	sbox.border_width_left = 1; sbox.border_width_right  = 1
	sbox.border_width_top  = 1; sbox.border_width_bottom = 1
	sbox.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", sbox)
	add_child(panel)

	# Panel title
	_lbl("⚙  ĐIỀU KHIỂN", Vector2(px + 10, py + 8), Vector2(PW - 20, 18), 12, C_GOLD)

	# Separator
	var sep := ColorRect.new()
	sep.position = Vector2(px + 8, py + 27)
	sep.size     = Vector2(PW - 16, 1)
	sep.color    = C_GOLD_DIM
	add_child(sep)

	var rows: Array = [
		["◀ ▶",            "Di chuyển"],
		["SPACE",           "Nhảy / Nhảy kép"],
		["S",               "Bắn súng"],
		["↑ / ↓",          "Ngắm lên / Ngồi"],
		["↓ + SHIFT",       "Lộn vòng lướt"],
		["A  (B40)",        "Bắn hỏa tiễn"],
		["X",               "Tên lửa phòng không"],
		["F",               "Đánh cận chiến"],
		["F1",              "Cheat Menu"],
	]
	for k in range(rows.size()):
		var row: Array = rows[k]
		var ky  := py + 34 + k * 20
		_lbl(row[0], Vector2(px + 8,   ky), Vector2(100, 18), 10, C_BAMBOO)
		_lbl(row[1], Vector2(px + 112, ky), Vector2(PW - 120, 18), 10, C_TEXT_DIM)

# ── Back button (bottom-right) ───────────────────────────────────────────────
func _make_equip_button(vp: Vector2) -> void:
	const BW := 170.0
	const BH := 38.0
	var   bx := vp.x - BW - 14.0
	var   by := vp.y - BH - 12.0

	var btn := Button.new()
	btn.position                  = Vector2(bx, by)
	btn.size                      = Vector2(BW, BH)
	btn.text                      = "TRANG BI"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bs_n := StyleBoxFlat.new()
	bs_n.bg_color     = Color(0.10, 0.14, 0.08, 0.94)
	bs_n.border_color = C_GOLD_DIM
	bs_n.border_width_left = 1; bs_n.border_width_right  = 1
	bs_n.border_width_top  = 1; bs_n.border_width_bottom = 1
	bs_n.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", bs_n)

	var bs_h := bs_n.duplicate()
	bs_h.bg_color     = C_GOLD
	bs_h.border_color = C_GOLD
	btn.add_theme_stylebox_override("hover",   bs_h)
	btn.add_theme_stylebox_override("pressed", bs_h)

	btn.add_theme_font_size_override("font_size",       12)
	btn.add_theme_color_override("font_color",          C_PARCHMENT)
	btn.add_theme_color_override("font_hover_color",    C_BG_DEEP)
	btn.add_theme_color_override("font_pressed_color",  C_BG_DEEP)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/loadout_screen.tscn"))
	add_child(btn)

func _make_back_button(vp: Vector2) -> void:
	const BW := 210.0
	const BH := 38.0
	var   bx := 14.0
	var   by := vp.y - BH - 12.0

	var btn := Button.new()
	btn.position                  = Vector2(bx, by)
	btn.size                      = Vector2(BW, BH)
	btn.text                      = "◀  QUAY LẠI TRANG CHỦ"
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var bs_n := StyleBoxFlat.new()
	bs_n.bg_color     = Color(0.12, 0.08, 0.07, 0.92)
	bs_n.border_color = C_RED_DIM
	bs_n.border_width_left = 1; bs_n.border_width_right  = 1
	bs_n.border_width_top  = 1; bs_n.border_width_bottom = 1
	bs_n.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", bs_n)

	var bs_h := bs_n.duplicate()
	bs_h.bg_color     = C_RED_STAR
	bs_h.border_color = C_RED_STAR
	btn.add_theme_stylebox_override("hover",   bs_h)
	btn.add_theme_stylebox_override("pressed", bs_h)

	btn.add_theme_font_size_override("font_size",       12)
	btn.add_theme_color_override("font_color",          Color(0.88, 0.72, 0.72))
	btn.add_theme_color_override("font_hover_color",    Color.WHITE)
	btn.add_theme_color_override("font_pressed_color",  Color.WHITE)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	add_child(btn)

# ── Helper: create Label and add_child ───────────────────────────────────────
func _lbl(
	text: String, pos: Vector2, sz: Vector2,
	font_size: int, color: Color
) -> Label:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.size     = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l

func _on_level_pressed(num: int) -> void:
	PlayerData.current_selected_stage = num
	get_tree().change_scene_to_file("res://scenes/contra_main.tscn")
