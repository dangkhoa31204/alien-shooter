extends Node
class_name HighScore
# highscore.gd — Tiện ích lưu/đọc top 10 điểm cao nhất

const SAVE_PATH := "user://highscores.json"
const MAX_ENTRIES := 10

# Trả về Array[Dictionary] — mỗi entry có: score, wave, date
static func load_scores() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return []
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if parsed is Array:
		return parsed
	return []

static func reset_scores() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string("[]")
		f.close()

static func save_score(score: int, wave: int) -> void:
	var entries: Array = load_scores()
	entries.append({
		"score": score,
		"wave":  wave,
		"date":  Time.get_datetime_string_from_system(false, false).substr(0, 10)
	})
	# Sắp xếp giảm dần theo điểm
	entries.sort_custom(func(a, b): return a["score"] > b["score"])
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(entries))
		f.close()
