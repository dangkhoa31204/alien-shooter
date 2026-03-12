extends Node
class_name PlayerData

const SAVE_PATH := "user://player_data.json"

static var coins: int = 0


static var sound_enabled:   bool  = true
static var music_enabled:   bool  = true
static var volume:          float = 0.8   # 0.0 – 1.0
static var sfx_enabled:     bool  = true
static var sfx_volume:      float = 0.8   # 0.0 – 1.0 (effects)

# Contra Campaign Progress
static var contra_unlocked_stage: int = 1
static var current_selected_stage: int = 1

static func get_unlocked_stage() -> int:
	return contra_unlocked_stage

static func unlock_next_stage() -> void:
	if current_selected_stage == contra_unlocked_stage and contra_unlocked_stage < 5:
		contra_unlocked_stage += 1
		save_data()

static func add_coins(amount: int) -> void:
	coins += amount
	save_data()

static func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save_data()
	return true


static func reset_data() -> void:
	coins = 0
	contra_unlocked_stage = 1
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"coins": 0,
			"music_enabled": music_enabled, "sound_enabled": sound_enabled, "volume": volume,
			"sfx_enabled": sfx_enabled, "sfx_volume": sfx_volume,
			"contra_unlocked": 1,
		}))
		f.close()

static func save_data() -> void:
	var d := {
		"coins":            coins,
		"music_enabled":    music_enabled,
		"sound_enabled":    sound_enabled,
		"volume":           volume,
		"sfx_enabled":      sfx_enabled,
		"sfx_volume":       sfx_volume,
		"contra_unlocked":  contra_unlocked_stage,
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
	music_enabled    = bool(parsed.get("music_enabled",   true))
	sound_enabled    = bool(parsed.get("sound_enabled",   true))
	volume           = float(parsed.get("volume",          0.8))
	sfx_enabled      = bool(parsed.get("sfx_enabled",     true))
	sfx_volume       = float(parsed.get("sfx_volume",      0.8))
	contra_unlocked_stage = int(parsed.get("contra_unlocked", 1))
	apply_volume()

static func apply_volume() -> void:
	var db := linear_to_db(maxf(0.0001, volume))
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, db)
	# Apply SFX volume to SFX bus if exists
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		var sdb := linear_to_db(maxf(0.0001, sfx_volume))
		AudioServer.set_bus_volume_db(sfx_idx, sdb)
