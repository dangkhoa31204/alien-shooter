extends Node
class_name PlayerData

const SAVE_PATH := "user://player_data.json"

static var coins: int = 0

const SKINS: Array = [
	{ "id": 0, "name": "Blue",          "price": 0,    "color": Color(0.15, 0.65, 1.0), "passive": "Cân bằng" },
	{ "id": 1, "name": "Red Fighter",   "price": 300,  "color": Color(1.0,  0.22, 0.18), "passive": "Tốc bắn +33% / Vtốc đạn +130" },
	{ "id": 2, "name": "Gold",          "price": 600,  "color": Color(1.0,  0.85, 0.1),  "passive": "Luồng đạn +1 miễn phí" },
	{ "id": 3, "name": "Neon Dart",     "price": 500,  "color": Color(0.1,  1.0,  0.4),  "passive": "Tốc độ +35% / Tốc bắn +15%" },
	{ "id": 4, "name": "Purple Galaxy", "price": 1000, "color": Color(0.75, 0.2,  1.0),  "passive": "Sát thương +1 / LV đạn +1 / Máu 7" },
]

const STARTERS: Array = [
	{ "id": 0, "name": "Normal LV.1", "price": 0,   "bullet_type": 0, "bullet_level": 1 },
	{ "id": 1, "name": "Electric",    "price": 400, "bullet_type": 1, "bullet_level": 1 },
	{ "id": 2, "name": "Fire",        "price": 400, "bullet_type": 2, "bullet_level": 1 },
	{ "id": 3, "name": "Ice",         "price": 400, "bullet_type": 3, "bullet_level": 1 },
	{ "id": 4, "name": "Explosive",   "price": 700, "bullet_type": 4, "bullet_level": 1 },
	{ "id": 5, "name": "Ricochet",    "price": 700, "bullet_type": 5, "bullet_level": 1 },
	{ "id": 6, "name": "Normal LV.2", "price": 300, "bullet_type": 0, "bullet_level": 2 },
	{ "id": 7, "name": "Normal LV.3", "price": 700, "bullet_type": 0, "bullet_level": 3 },
]

static var owned_skins:    Array = [0]
static var owned_starters: Array = [0]
static var equipped_skin:    int = 0
static var equipped_starter: int = 0

static func add_coins(amount: int) -> void:
	coins += amount
	save_data()

static func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save_data()
	return true

static func buy_skin(id: int) -> bool:
	if id in owned_skins: return true
	var item: Dictionary = SKINS[id]
	if not spend_coins(item["price"]): return false
	owned_skins.append(id)
	save_data()
	return true

static func buy_starter(id: int) -> bool:
	if id in owned_starters: return true
	var item: Dictionary = STARTERS[id]
	if not spend_coins(item["price"]): return false
	owned_starters.append(id)
	save_data()
	return true

static func equip_skin(id: int) -> void:
	if not (id in owned_skins): return
	equipped_skin = id
	save_data()

static func equip_starter(id: int) -> void:
	if not (id in owned_starters): return
	equipped_starter = id
	save_data()

static func get_skin_color() -> Color:
	return SKINS[equipped_skin]["color"]

static func get_starter_bullet_type() -> int:
	return STARTERS[equipped_starter]["bullet_type"]

static func get_starter_bullet_level() -> int:
	return STARTERS[equipped_starter]["bullet_level"]

static func save_data() -> void:
	var d := {
		"coins":            coins,
		"owned_skins":      owned_skins,
		"owned_starters":   owned_starters,
		"equipped_skin":    equipped_skin,
		"equipped_starter": equipped_starter,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()

static func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null: return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary): return
	coins            = int(parsed.get("coins",            0))
	owned_skins      = parsed.get("owned_skins",      [0])
	owned_starters   = parsed.get("owned_starters",   [0])
	equipped_skin    = int(parsed.get("equipped_skin",    0))
	equipped_starter = int(parsed.get("equipped_starter", 0))
