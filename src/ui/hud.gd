extends CanvasLayer
## In-game UI. Top bar for time/speed/mode; a build panel (visible in Build mode)
## with tool buttons and a catalog-driven palette. Talks to Game via its methods.

var game  # Game
var _clock_label: Label
var _status_label: Label
var _mode_button: Button
var _build_panel: PanelContainer
var _palette: VBoxContainer
var _palette_title: Label
var _hint_label: Label

func setup(g) -> void:
	game = g
	_build_top_bar()
	_build_build_panel()
	_build_hint()
	_set_build_visible(false)
	on_mode_changed(game.mode)

func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_bottom = 44
	add_child(panel)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	panel.add_child(bar)

	_clock_label = _label("Day 1  7:00 AM")
	bar.add_child(_clock_label)
	bar.add_child(_vsep())

	bar.add_child(_button("Pause", func(): game.set_speed(0.0)))
	bar.add_child(_button("1x", func(): game.set_speed(1.0)))
	bar.add_child(_button("2x", func(): game.set_speed(2.0)))
	bar.add_child(_button("3x", func(): game.set_speed(4.0)))
	bar.add_child(_vsep())

	# Zoom buttons — work without a scroll wheel (laptop trackpad friendly).
	bar.add_child(_button("Zoom -", func(): game.rig.zoom_by(2.0)))
	bar.add_child(_button("Zoom +", func(): game.rig.zoom_by(-2.0)))
	bar.add_child(_vsep())

	_mode_button = _button("Build Mode", _toggle_mode)
	_mode_button.tooltip_text = "Toggle Build / Live mode (B or Tab)"
	bar.add_child(_mode_button)
	bar.add_child(_button("Save", func(): game.save_game()))
	bar.add_child(_button("Load", func(): game.load_game()))
	bar.add_child(_vsep())

	_status_label = _label("")
	bar.add_child(_status_label)

func _build_build_panel() -> void:
	_build_panel = PanelContainer.new()
	_build_panel.anchor_top = 0.0
	_build_panel.offset_top = 52
	_build_panel.offset_left = 8
	_build_panel.custom_minimum_size = Vector2(220, 460)
	add_child(_build_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	_build_panel.add_child(root)

	var tools := HBoxContainer.new()
	root.add_child(tools)
	tools.add_child(_button("Floor", func(): _pick_tool(Game.BuildTool.FLOOR, "Floors")))
	tools.add_child(_button("Wall", func(): _pick_tool(Game.BuildTool.WALL, "Walls")))
	tools.add_child(_button("Furn.", func(): _pick_tool(Game.BuildTool.FURNITURE, "Furniture")))
	tools.add_child(_button("Demo", func(): _pick_tool(Game.BuildTool.DEMOLISH, "Demolish")))

	root.add_child(_label("R: rotate furniture", 12))
	_palette_title = _label("Furniture")
	root.add_child(_palette_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(204, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_palette = VBoxContainer.new()
	_palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_palette)

## A persistent control hint pinned to the bottom-left, so it's always clear
## how to enter build mode / move the camera without a manual.
func _build_hint() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 8
	panel.offset_bottom = -8
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.modulate.a = 0.85
	add_child(panel)
	_hint_label = _label("", 13)
	panel.add_child(_hint_label)

func _toggle_mode() -> void:
	game.set_mode(Game.Mode.LIVE if game.mode == Game.Mode.BUILD else Game.Mode.BUILD)

## Called by Game whenever the mode changes (single source of truth).
func on_mode_changed(mode: int) -> void:
	var building := mode == Game.Mode.BUILD
	_mode_button.text = "Live Mode" if building else "Build Mode"
	_set_build_visible(building)
	if building:
		_pick_tool(Game.BuildTool.FURNITURE, "Furniture")
	if _hint_label:
		if building:
			_hint_label.text = "BUILD MODE  •  pick a tool + item, left-click to place  •  R rotate  •  Esc/B exit"
		else:
			_hint_label.text = "Move: WASD/arrows  •  Zoom: E/Q or = / -  •  Orbit: right-drag  •  Build: click \"Build Mode\" or press B"

func _set_build_visible(v: bool) -> void:
	_build_panel.visible = v

func _pick_tool(t: int, title: String) -> void:
	game.set_tool(t)
	_palette_title.text = title
	_populate_palette(t)

func _populate_palette(t: int) -> void:
	for c in _palette.get_children():
		c.queue_free()
	match t:
		Game.BuildTool.FURNITURE:
			for def in Catalog.all_furniture():
				var id: String = def.id
				_palette.add_child(_button("%s  ($%d)" % [def.name, def.price],
					func(): game.select_furniture(id)))
		Game.BuildTool.FLOOR:
			for def in Catalog.floors.values():
				var id: String = def.id
				_palette.add_child(_button(def.name, func(): game.selected_floor = id))
		Game.BuildTool.WALL:
			for def in Catalog.walls.values():
				var id: String = def.id
				_palette.add_child(_button(def.name, func(): game.selected_wall = id))
		Game.BuildTool.DEMOLISH:
			_palette.add_child(_label("Click furniture or tiles\nto remove them.", 12))

func refresh() -> void:
	if game == null:
		return
	_clock_label.text = game.clock.clock_string()
	var parts: Array[String] = []
	for s in game.sims:
		if s.agent:
			parts.append("%s %d%%" % [s.agent.sim_name, int(s.agent.needs.mood())])
	_status_label.text = "   ".join(parts)

## --- tiny widget helpers ----------------------------------------------------

func _label(text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	return l

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b

func _vsep() -> VSeparator:
	return VSeparator.new()
