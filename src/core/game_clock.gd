class_name GameClock
extends RefCounted
## Pure, deterministic game-time model. No nodes, no engine ticks.
## Drive it by calling advance(real_delta_seconds); everything else is read-only.
##
## Decoupled from the scene tree so it can be unit-tested headlessly.

## How many in-game minutes pass per real-time second at speed multiplier 1.0.
const MINUTES_PER_REAL_SECOND := 1.0
const MINUTES_PER_DAY := 24 * 60

var total_minutes: float = 0.0  ## minutes elapsed since the start of day 0
var speed: float = 1.0          ## 0 = paused, 1 = normal, 2/3 = fast

## Advance time. real_delta is the wall-clock delta in seconds.
func advance(real_delta: float) -> void:
	if speed <= 0.0:
		return
	total_minutes += real_delta * MINUTES_PER_REAL_SECOND * speed

func set_paused(paused: bool) -> void:
	speed = 0.0 if paused else 1.0

func is_paused() -> bool:
	return speed <= 0.0

func day() -> int:
	return int(total_minutes / MINUTES_PER_DAY)

func minute_of_day() -> float:
	return fposmod(total_minutes, float(MINUTES_PER_DAY))

func hour() -> int:
	return int(minute_of_day() / 60.0)

func minute() -> int:
	return int(fposmod(minute_of_day(), 60.0))

## Returns true during typical sleeping hours (used as a soft AI hint).
func is_night() -> bool:
	var h := hour()
	return h >= 22 or h < 7

func clock_string() -> String:
	var h := hour()
	var m := minute()
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "Day %d  %d:%02d %s" % [day() + 1, h12, m, ampm]
