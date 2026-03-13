extends Node
class_name ItemDatabase

# Rarity colors
const RARITY_COLORS = {
	"Common": Color(0.7, 0.7, 0.7),     # Xám
	"Rare": Color(0.2, 0.6, 1.0),       # Xanh dương
	"Epic": Color(0.7, 0.2, 0.9),       # Tím
	"Legendary": Color(1.0, 0.6, 0.1)   # Cam
}

# Các item đã có tác dụng thực tế trong gameplay hiện tại.
const IMPLEMENTED_ITEM_IDS = {
	"wpn_ak47": true,
	"wpn_m4a1": true,
	"skl_rpg": true,
	"skl_b40": true,
	"arm_kevlar": true,
	"arm_titan": true,
	"acc_boots": true,
	"spc_aa_missile": true
}

const ITEMS = {
	"wpn_ak47": {
		"id": "wpn_ak47", "name": "AK-47", "type": "main_weapon", "rarity": "Common",
		"max_level": 5, "base_cost": 100, "desc": "Súng trường tiêu chuẩn, sát thương khá.",
		"stats": {"damage": 14, "fire_rate": 0.15, "range": 500}
	},
	"wpn_m4a1": {
		"id": "wpn_m4a1", "name": "M4A1", "type": "main_weapon", "rarity": "Rare",
		"max_level": 5, "base_cost": 250, "desc": "Súng trường ổn định, tốc độ bắn cao.",
		"stats": {"damage": 18, "fire_rate": 0.12, "range": 600}
	},
	"wpn_laser": {
		"id": "wpn_laser", "name": "Laser Rifle", "type": "main_weapon", "rarity": "Epic",
		"max_level": 5, "base_cost": 600, "desc": "Bắn tia laser xuyên thấu, độ chính xác cao.",
		"stats": {"damage": 24, "fire_rate": 0.10, "range": 700}
	},
	"wpn_plasma": {
		"id": "wpn_plasma", "name": "Plasma Gun", "type": "main_weapon", "rarity": "Legendary",
		"max_level": 5, "base_cost": 1500, "desc": "Khẩu súng huyền thoại, hủy diệt diện rộng.",
		"stats": {"damage": 32, "fire_rate": 0.20, "range": 800}
	},
	
	"sub_pistol": {
		"id": "sub_pistol", "name": "Pistol", "type": "sub_weapon", "rarity": "Common",
		"max_level": 5, "base_cost": 50, "desc": "Súng lục nhẹ gọn, thay đạn nhanh.",
		"stats": {"damage": 5, "fire_rate": 0.3}
	},
	"sub_smg": {
		"id": "sub_smg", "name": "SMG", "type": "sub_weapon", "rarity": "Rare",
		"max_level": 5, "base_cost": 150, "desc": "Súng tiểu liên, xả đạn cực nhanh.",
		"stats": {"damage": 7, "fire_rate": 0.08}
	},
	"sub_melee": {
		"id": "sub_melee", "name": "Cận chiến", "type": "sub_weapon", "rarity": "Common",
		"max_level": 5, "base_cost": 90, "desc": "Đòn đánh cận chiến của lính Contra.",
		"stats": {"damage": 2, "cooldown": 0.6}
	},
	
	"skl_frag": {
		"id": "skl_frag", "name": "Frag Grenade", "type": "skill", "rarity": "Common",
		"max_level": 5, "base_cost": 80, "desc": "Lựu đạn nổ mảnh cơ bản.",
		"stats": {"cooldown": 5.0, "damage": 50}
	},
	"skl_rpg": {
		"id": "skl_rpg", "name": "RPG", "type": "skill", "rarity": "Epic",
		"max_level": 5, "base_cost": 500, "desc": "Phóng lựu đạn phá giáp cực mạnh.",
		"stats": {"cooldown": 8.0, "damage": 150}
	},
	"skl_b40": {
		"id": "skl_b40", "name": "B40", "type": "skill", "rarity": "Rare",
		"max_level": 5, "base_cost": 300, "desc": "B40 chống tăng, bắn bằng phím A trong trận.",
		"stats": {"cooldown": 10.0, "damage": 3}
	},
	
	"arm_kevlar": {
		"id": "arm_kevlar", "name": "Kevlar Vest", "type": "armor", "rarity": "Common",
		"max_level": 5, "base_cost": 120, "desc": "Áo giáp chống đạn cơ bản.",
		"stats": {"hp_bonus": 20}
	},
	"arm_titan": {
		"id": "arm_titan", "name": "Titan Armor", "type": "armor", "rarity": "Legendary",
		"max_level": 5, "base_cost": 2000, "desc": "Giáp siêu hợp kim titan.",
		"stats": {"hp_bonus": 45}
	},
	
	"acc_boots": {
		"id": "acc_boots", "name": "Combat Boots", "type": "accessory", "rarity": "Rare",
		"max_level": 5, "base_cost": 300, "desc": "Giày chiến đấu tăng tốc độ di chuyển.",
		"stats": {"speed_bonus": 20}
	},
	
	"spc_airstrike": {
		"id": "spc_airstrike", "name": "Airstrike", "type": "special", "rarity": "Epic",
		"max_level": 5, "base_cost": 1000, "desc": "Gọi cứu viện không kích thả bom.",
		"stats": {"cooldown": 20.0, "damage": 300}
	},
	"spc_aa_missile": {
		"id": "spc_aa_missile", "name": "AA Missile", "type": "special", "rarity": "Rare",
		"max_level": 5, "base_cost": 280, "desc": "Tên lửa phòng không khóa mục tiêu bay.",
		"stats": {"cooldown": 10.0, "damage": 3}
	}
}

static func get_item(id: String) -> Dictionary:
	if ITEMS.has(id): return ITEMS[id]
	return {}

static func get_all_items() -> Array:
	var arr = []
	for k in ITEMS.keys():
		arr.append(ITEMS[k])
	return arr

static func is_item_implemented(item_id: String) -> bool:
	return bool(IMPLEMENTED_ITEM_IDS.get(item_id, false))

static func get_upgrade_cost(id: String, current_level: int) -> int:
	var it = get_item(id)
	if it.is_empty(): return 0
	if current_level >= it.max_level: return 0
	# Công thức: base_cost * (1.5 ^ current_level)
	return int(it.base_cost * pow(1.5, current_level))

static func get_stat(item_id: String, stat_name: String, level: int = 1) -> float:
	var it = get_item(item_id)
	if it.is_empty() or not it.stats.has(stat_name): return 0.0
	
	var base = float(it.stats[stat_name])
	# Cooldown giảm mỗi level, Damage tăng mỗi level
	if stat_name == "cooldown":
		return base * pow(0.9, level - 1)
	elif stat_name == "fire_rate":
		return base * pow(0.95, level - 1)
	else:
		return base * (1.0 + (level - 1) * 0.2)
