extends RefCounted
## Loads mission packs (campaign/*.json) and stores progress in user://campaign_progress.json.

const PACKS := [
	{"id": "main", "path": "res://campaign/main.json"},
	{"id": "red", "path": "res://campaign/red.json"},
	{"id": "bonus", "path": "res://campaign/bonus.json"},
]

static func pack_path(id: String) -> String:
	for p in PACKS:
		if p["id"] == id:
			return p["path"]
	return ""

## Returns {id, title, blurb, chapters:[{title,intro,missions:[...]}], flat:[{chapter:int, mission:{...}}]}
static func load_pack(id: String) -> Dictionary:
	var path := pack_path(id)
	if path == "" or not FileAccess.file_exists(path):
		push_error("campaign pack not found: %s" % id)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("campaign pack is not valid JSON: %s" % id)
		return {}
	var flat: Array = []
	for ci in range(parsed["chapters"].size()):
		for m in parsed["chapters"][ci]["missions"]:
			flat.append({"chapter": ci, "mission": m})
	parsed["flat"] = flat
	return parsed

static func list_packs() -> Array:
	var out: Array = []
	for p in PACKS:
		var pk := load_pack(p["id"])
		if not pk.is_empty():
			out.append(pk)
	return out

const PROGRESS_FILE := "user://campaign_progress.json"

static func load_progress() -> Dictionary:
	if not FileAccess.file_exists(PROGRESS_FILE):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_FILE))
	return parsed if parsed is Dictionary else {}

static func save_progress(progress: Dictionary) -> void:
	var f := FileAccess.open(PROGRESS_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(progress))

static func is_done(progress: Dictionary, pack_id: String, mission_id: int) -> bool:
	return progress.get(pack_id, []).has(mission_id)

static func mark_done(progress: Dictionary, pack_id: String, mission_id: int) -> void:
	var lst: Array = progress.get(pack_id, [])
	if not lst.has(mission_id):
		lst.append(mission_id)
	progress[pack_id] = lst

## A mission is playable when it is the first one or the previous mission is done.
static func is_unlocked(progress: Dictionary, pack_id: String, mission_id: int, unlock_all: bool = false) -> bool:
	return unlock_all or mission_id <= 1 or is_done(progress, pack_id, mission_id - 1)
