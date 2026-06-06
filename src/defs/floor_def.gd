class_name FloorDef
extends RefCounted
## A floor material that can be painted onto tiles. The "generic variant" of a
## floor is just a colour (optionally a texture); modders add more by JSON.

const TYPE := "floor"

var id: String = ""
var name: String = ""
var price: int = 1
var color: Color = Color(0.6, 0.6, 0.6)
var texture_path: String = ""
var pack_id: String = "core"

static func from_dict(d: Dictionary, pack_dir: String, pack_id := "core") -> FloorDef:
	var f := FloorDef.new()
	f.id = str(d.get("id", ""))
	if f.id == "":
		push_error("FloorDef missing 'id' in pack '%s'" % pack_id)
		return null
	f.pack_id = pack_id
	f.name = str(d.get("name", f.id.capitalize()))
	f.price = int(d.get("price", 1))
	if d.has("color"):
		f.color = Color(str(d["color"]))
	var t := str(d.get("texture", ""))
	if t != "":
		f.texture_path = FurnitureDef._resolve_path(t, pack_dir)
	return f
