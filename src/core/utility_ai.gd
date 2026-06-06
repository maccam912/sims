class_name UtilityAI
extends RefCounted
## Sims-style "advertisement" decision making. Objects in the world advertise
## interactions; each interaction advertises how much it will raise needs.
## A Sim scores every available interaction against its current needs and picks
## the most appealing one (with optional randomness).
##
## Pure functions, no nodes — the heart of the sim and the most-tested module.

## Marginal desire for a need at its current value. Low needs are urgent, so
## desire rises steeply as the value drops (convex curve).
static func desire(need_value: float) -> float:
	var deficit := clampf((100.0 - need_value) / 100.0, 0.0, 1.0)
	return deficit * deficit  # 0..1, quadratic

## Score a single interaction for a Sim.
## option = {
##   "gains": { need_key: points_per_minute },
##   "position": Vector3 (optional, for travel penalty),
##   "duration": float minutes (optional, default 60),
## }
## needs is a Needs instance. sim_pos is the Sim's world position.
static func score_option(needs: Needs, option: Dictionary, sim_pos := Vector3.ZERO) -> float:
	var gains: Dictionary = option.get("gains", {})
	var duration: float = float(option.get("duration", 60.0))
	var total := 0.0
	for k in gains:
		var per_min := float(gains[k])
		if per_min <= 0.0:
			continue
		# Projected raise, clamped so we don't reward overfilling a full need.
		var cur := needs.get_value(k)
		var headroom := 100.0 - cur
		var projected := minf(per_min * duration, headroom)
		total += desire(cur) * projected
	# Travel penalty: distant objects are slightly less appealing.
	if option.has("position"):
		var dist: float = sim_pos.distance_to(option["position"])
		total -= dist * 0.5
	return total

## Pick the best option. With temperature > 0, choose probabilistically among
## the top options (softmax) using the supplied RNG for determinism in tests.
## Returns the chosen option Dictionary, or {} if none.
static func choose(needs: Needs, options: Array, sim_pos := Vector3.ZERO,
		rng: RandomNumberGenerator = null, temperature := 0.0) -> Dictionary:
	if options.is_empty():
		return {}
	var scored: Array = []
	var best_score := -INF
	for opt in options:
		var s := score_option(needs, opt, sim_pos)
		scored.append({"opt": opt, "score": s})
		best_score = maxf(best_score, s)
	if best_score <= 0.0:
		# Nothing is appealing right now (all needs near full).
		return {}
	if temperature <= 0.0 or rng == null:
		for e in scored:
			if e["score"] == best_score:
				return e["opt"]
		return scored[0]["opt"]
	# Softmax sampling, scaled by best_score for numerical stability.
	var weights: Array = []
	var sum := 0.0
	for e in scored:
		var w: float = exp((e["score"] - best_score) / maxf(temperature, 0.001))
		weights.append(w)
		sum += w
	var r := rng.randf() * sum
	var acc := 0.0
	for i in scored.size():
		acc += weights[i]
		if r <= acc:
			return scored[i]["opt"]
	return scored.back()["opt"]
