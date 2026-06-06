class_name SimAgent
extends RefCounted
## A Sim's mind and motives, independent of its 3D body. The Sim node owns one
## of these, feeds it elapsed game-time, asks it what to do, and moves the body
## to carry it out. Kept node-free so behaviour is deterministically testable.

enum State { IDLE, MOVING, INTERACTING }

var sim_name: String = "Sim"
var needs: Needs
var state: int = State.IDLE
var current: Dictionary = {}      ## chosen interaction option
var interaction_elapsed: float = 0.0
var rng := RandomNumberGenerator.new()

func _init(name_: String = "Sim", seed_: int = 0) -> void:
	sim_name = name_
	needs = Needs.new()
	if seed_ != 0:
		rng.seed = seed_

## Natural decay; call every simulation step with elapsed in-game minutes.
func decay(minutes: float) -> void:
	needs.decay_over(minutes)

## Build the list of interaction options available on the lot.
## resolve is a Callable(def_id) -> FurnitureDef (so we don't depend on the
## Catalog autoload here, keeping this testable).
func gather_options(lot: Lot, resolve: Callable) -> Array:
	var options: Array = []
	for rec in lot.furniture:
		var def: FurnitureDef = resolve.call(rec["def_id"])
		if def == null or not def.has_interactions():
			continue
		var world := Grid.tile_to_world(rec["origin"])
		for inter in def.interactions:
			var opt := inter.to_option(rec["uid"], world)
			opt["furniture"] = rec
			options.append(opt)
	return options

## Pick the most appealing option given current needs. Returns it (and sets
## state to MOVING) or {} if nothing is worth doing.
func choose_action(options: Array, sim_pos: Vector3, temperature := 8.0) -> Dictionary:
	var choice := UtilityAI.choose(needs, options, sim_pos, rng, temperature)
	if choice.is_empty():
		state = State.IDLE
		current = {}
		return {}
	current = choice
	state = State.MOVING
	interaction_elapsed = 0.0
	return choice

## Called by the body once it reaches the interaction slot.
func begin_interaction() -> void:
	state = State.INTERACTING
	interaction_elapsed = 0.0

## Advance the active interaction. Returns true when it's finished.
func tick_interaction(minutes: float) -> bool:
	if state != State.INTERACTING or current.is_empty():
		return true
	needs.apply_gains(current.get("gains", {}), minutes)
	interaction_elapsed += minutes
	if interaction_elapsed >= float(current.get("duration", 60.0)):
		state = State.IDLE
		current = {}
		return true
	return false

func status_text() -> String:
	match state:
		State.MOVING:
			return "%s: heading to %s" % [sim_name, current.get("name", "?")]
		State.INTERACTING:
			return "%s: %s" % [sim_name, current.get("name", "?")]
		_:
			return "%s: idle" % sim_name
