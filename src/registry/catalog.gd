extends Node
## Autoload singleton. Scans content packs and builds the registry of all
## furniture / floors / walls available to build mode and the simulation.
##
## A "content pack" is a directory containing a `pack.json` manifest plus any
## number of `*.json` definition files (each with a "type" field). Packs are
## discovered under, in priority order:
##   res://content/   built-in game content (the "core" pack lives here)
##   res://mods/      mods shipped with the build / installed into the project
##   user://mods/     mods the player drops in at runtime
##
## Later packs can override earlier ones by reusing an id, so players can tweak
## core content. Loading is data-driven and decoupled, so it can be exercised
## from headless tests via load_all().

signal catalog_loaded

const ROOTS := ["res://content", "res://mods", "user://mods"]

var furniture: Dictionary = {}   ## id -> FurnitureDef
var floors: Dictionary = {}      ## id -> FloorDef
var walls: Dictionary = {}       ## id -> WallDef
var packs: Array[Dictionary] = []## manifest dicts of every pack found

func _ready() -> void:
	load_all()

## Clear and rebuild the entire registry. Returns the number of defs loaded.
func load_all() -> int:
	furniture.clear()
	floors.clear()
	walls.clear()
	packs.clear()
	var count := 0
	for root in ROOTS:
		count += _scan_root(root)
	catalog_loaded.emit()
	print("[Catalog] loaded %d defs from %d packs (%d furniture, %d floors, %d walls)"
		% [count, packs.size(), furniture.size(), floors.size(), walls.size()])
	return count

func _scan_root(root: String) -> int:
	var dir := DirAccess.open(root)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			count += _load_pack(root.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return count

func _load_pack(pack_dir: String) -> int:
	var manifest_path := pack_dir.path_join("pack.json")
	if not FileAccess.file_exists(manifest_path):
		return 0
	var manifest = _read_json(manifest_path)
	if manifest == null:
		return 0
	var pack_id := str(manifest.get("id", pack_dir.get_file()))
	manifest["_dir"] = pack_dir
	packs.append(manifest)
	var count := 0
	for json_path in _find_json_files(pack_dir):
		if json_path.get_file() == "pack.json":
			continue
		count += _load_def_file(json_path, pack_dir, pack_id)
	return count

## A def file may contain a single object or an array of objects.
func _load_def_file(path: String, pack_dir: String, pack_id: String) -> int:
	var data = _read_json(path)
	if data == null:
		return 0
	var entries: Array = data if data is Array else [data]
	var count := 0
	for e in entries:
		if e is Dictionary and _register(e, pack_dir, pack_id):
			count += 1
	return count

func _register(d: Dictionary, pack_dir: String, pack_id: String) -> bool:
	match str(d.get("type", "")):
		FurnitureDef.TYPE:
			var f := FurnitureDef.from_dict(d, pack_dir, pack_id)
			if f:
				furniture[f.id] = f
				return true
		FloorDef.TYPE:
			var fl := FloorDef.from_dict(d, pack_dir, pack_id)
			if fl:
				floors[fl.id] = fl
				return true
		WallDef.TYPE:
			var w := WallDef.from_dict(d, pack_dir, pack_id)
			if w:
				walls[w.id] = w
				return true
		_:
			push_warning("[Catalog] unknown def type in %s" % pack_dir)
	return false

func _find_json_files(dir_path: String, out: Array[String] = []) -> Array[String]:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := dir_path.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			_find_json_files(full, out)
		elif entry.ends_with(".json"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out

func _read_json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("[Catalog] cannot open %s" % path)
		return null
	var text := f.get_as_text()
	var result = JSON.parse_string(text)
	if result == null:
		push_error("[Catalog] invalid JSON in %s" % path)
	return result

## --- Convenience accessors --------------------------------------------------

func get_furniture(id: String) -> FurnitureDef:
	return furniture.get(id)

func get_floor(id: String) -> FloorDef:
	return floors.get(id)

func get_wall(id: String) -> WallDef:
	return walls.get(id)

func furniture_by_category(category: String) -> Array:
	var out: Array = []
	for f in furniture.values():
		if f.category == category:
			out.append(f)
	return out

func all_furniture() -> Array:
	return furniture.values()
