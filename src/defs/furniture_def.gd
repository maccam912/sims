class_name FurnitureDef
extends RefCounted
## A placeable object. Authored as JSON; loaded by Catalog. Modders add new
## furniture by dropping a JSON file (and optionally a .glb) into a content pack.

const TYPE := "furniture"

var id: String = ""
var name: String = ""
var category: String = "misc"   ## comfort, kitchen, bathroom, electronics, decor, misc
var price: int = 0
var mesh_path: String = ""       ## res:// path to a .glb/.gltf, or "" for a placeholder
var size: Vector2i = Vector2i.ONE ## footprint in tiles (w, h) before rotation
var color: Color = Color(0.8, 0.8, 0.85) ## tint for placeholder box when mesh missing
var pack_id: String = "core"
var interactions: Array[InteractionDef] = []

## Parse from a JSON dict. pack_dir is used to resolve relative mesh paths.
## Returns null and pushes an error if the entry is invalid.
static func from_dict(d: Dictionary, pack_dir: String, pack_id := "core") -> FurnitureDef:
	var f := FurnitureDef.new()
	f.id = str(d.get("id", ""))
	if f.id == "":
		push_error("FurnitureDef missing 'id' in pack '%s'" % pack_id)
		return null
	f.pack_id = pack_id
	f.name = str(d.get("name", f.id.capitalize()))
	f.category = str(d.get("category", "misc"))
	f.price = int(d.get("price", 0))
	var sz = d.get("size", [1, 1])
	if sz is Array and sz.size() == 2:
		f.size = Vector2i(int(sz[0]), int(sz[1]))
	if d.has("color"):
		f.color = Color(str(d["color"]))
	var mp := str(d.get("mesh", ""))
	if mp != "":
		f.mesh_path = _resolve_path(mp, pack_dir)
	for raw in d.get("interactions", []):
		if raw is Dictionary:
			f.interactions.append(InteractionDef.from_dict(raw))
	return f

## Resolve a mesh path: absolute res://... is kept; otherwise relative to pack.
static func _resolve_path(p: String, pack_dir: String) -> String:
	if p.begins_with("res://") or p.begins_with("user://"):
		return p
	return pack_dir.path_join(p)

func has_interactions() -> bool:
	return not interactions.is_empty()
