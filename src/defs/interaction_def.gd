class_name InteractionDef
extends RefCounted
## One interaction advertised by a piece of furniture (e.g. "Sleep" on a bed).
## Authored as JSON inside a furniture def's "interactions" array.

var id: String = ""
var name: String = ""
var gains: Dictionary = {}      ## need_key -> points per in-game minute
var duration: float = 60.0      ## in-game minutes the interaction runs
var slot: Vector2 = Vector2.ZERO ## offset (tiles) from origin where the Sim stands

static func from_dict(d: Dictionary) -> InteractionDef:
	var i := InteractionDef.new()
	i.id = str(d.get("id", ""))
	i.name = str(d.get("name", i.id.capitalize()))
	i.duration = float(d.get("duration", 60.0))
	var g: Dictionary = d.get("gains", {})
	for k in g:
		if k in Needs.KEYS:
			i.gains[k] = float(g[k])
		else:
			push_warning("InteractionDef '%s' advertises unknown need '%s'" % [i.id, k])
	var s = d.get("slot", null)
	if s is Array and s.size() == 2:
		i.slot = Vector2(float(s[0]), float(s[1]))
	return i

## Shape consumed by UtilityAI.score_option / choose.
func to_option(object_id: int, world_pos: Vector3) -> Dictionary:
	return {
		"object_id": object_id,
		"interaction_id": id,
		"name": name,
		"gains": gains,
		"duration": duration,
		"position": world_pos,
	}
