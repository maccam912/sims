class_name Needs
extends RefCounted
## A Sim's motives. Each value is 0..100 where 100 = fully satisfied and
## 0 = desperate. Decays over game-time; raised by interactions.
##
## Pure data + math, no nodes — fully unit-testable.

## Canonical need keys. Mods may advertise gains against any of these.
const KEYS := ["hunger", "energy", "social", "fun", "hygiene", "bladder", "comfort"]

## Default decay in need-points per in-game minute. Tuned so an idle Sim
## drifts toward needing care over a day without bottoming out instantly.
const DEFAULT_DECAY := {
	"hunger": 0.10,
	"energy": 0.07,
	"social": 0.05,
	"fun": 0.06,
	"hygiene": 0.05,
	"bladder": 0.12,
	"comfort": 0.08,
}

var values: Dictionary = {}
var decay: Dictionary = {}

func _init(initial: float = 80.0) -> void:
	for k in KEYS:
		values[k] = clampf(initial, 0.0, 100.0)
		decay[k] = float(DEFAULT_DECAY.get(k, 0.05))

func get_value(key: String) -> float:
	return float(values.get(key, 100.0))

func set_value(key: String, v: float) -> void:
	if values.has(key):
		values[key] = clampf(v, 0.0, 100.0)

## Apply natural decay for the given number of in-game minutes.
func decay_over(minutes: float) -> void:
	for k in KEYS:
		values[k] = clampf(values[k] - decay[k] * minutes, 0.0, 100.0)

## Apply a set of per-minute gains (an interaction's effect) for `minutes`.
## gains is { need_key: points_per_minute }.
func apply_gains(gains: Dictionary, minutes: float) -> void:
	for k in gains:
		if values.has(k):
			values[k] = clampf(values[k] + float(gains[k]) * minutes, 0.0, 100.0)

## Lowest need value — handy for "what's most urgent" and mood.
func lowest() -> float:
	var lo := 100.0
	for k in KEYS:
		lo = minf(lo, values[k])
	return lo

## Overall wellbeing 0..100 (simple average; could be weighted later).
func mood() -> float:
	var sum := 0.0
	for k in KEYS:
		sum += values[k]
	return sum / float(KEYS.size())

func snapshot() -> Dictionary:
	return values.duplicate()
