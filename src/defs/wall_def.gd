class_name WallDef
extends RefCounted
## A wall material/finish applied to wall segments. Generic variant = a colour.

const TYPE := "wall"

var id: String = ""
var name: String = ""
var price: int = 2
var color: Color = Color(0.9, 0.88, 0.82)
var texture_path: String = ""
var pack_id: String = "core"

static func from_dict(d: Dictionary, pack_dir: String, pack_id := "core") -> WallDef:
	var w := WallDef.new()
	w.id = str(d.get("id", ""))
	if w.id == "":
		push_error("WallDef missing 'id' in pack '%s'" % pack_id)
		return null
	w.pack_id = pack_id
	w.name = str(d.get("name", w.id.capitalize()))
	w.price = int(d.get("price", 2))
	if d.has("color"):
		w.color = Color(str(d["color"]))
	var t := str(d.get("texture", ""))
	if t != "":
		w.texture_path = FurnitureDef._resolve_path(t, pack_dir)
	return w
