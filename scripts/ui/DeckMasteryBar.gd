extends Control

const LOCKED_COLOR: Color = Color(0.36, 0.37, 0.38)
const STUDY_FONT = preload("res://assets/fonts/static/NotoSansJP-Black.ttf")
const KOREAN_FONT = preload("res://assets/fonts/NotoSansKR-VariableFont_wght.ttf")
const THAI_FONT = preload("res://assets/fonts/NotoSansThai-VariableFont_wdth_wght.ttf")
const BAR_TOP: float = 35.0
const BAR_HEIGHT: float = 12.0
const MARKER_SIZE: float = 32.0
const MARKER_SPACING: float = 4.0
const FACEOFF_OVERLAP: float = 10.0

var _run: RunState
var _card_ids: Array[StringName] = []
var _levels: Array[int] = []
var _markers: Dictionary[int, Rect2] = {}
var _inspector: PanelContainer
var _details: HBoxContainer
var _carousel_panel_style: StyleBoxEmpty = StyleBoxEmpty.new()
var _boss_panel_style: StyleBoxFlat = StyleBoxFlat.new()
var _shown_card: int = -1
var _shown_boss: int = 0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_exited.connect(_close_inspector)
	_inspector = PanelContainer.new()
	_inspector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inspector.z_index = 5
	_boss_panel_style.bg_color = Color(0.12, 0.16, 0.19, 0.97)
	_boss_panel_style.content_margin_left = 14
	_boss_panel_style.content_margin_right = 14
	_boss_panel_style.content_margin_top = 8
	_boss_panel_style.content_margin_bottom = 8
	add_child(_inspector)
	_details = HBoxContainer.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_theme_constant_override("separation", 14)
	_inspector.add_child(_details)
	_inspector.hide()

func populate(run: RunState) -> void:
	_run = run
	_card_ids.clear()
	_levels.clear()
	if run != null:
		var active: Dictionary[StringName, int] = {}
		for id: StringName in run.active_deck_ids:
			active[id] = run.flashcard_progress[id].mastery_level
		for level: int in range(FlashcardProgress.MASTERY_MAX, -1, -1):
			for id: StringName in run.ordered_deck_pool:
				if active.get(id, 0) == level:
					_card_ids.append(id)
					_levels.append(level)
	_close_inspector()
	queue_redraw()

func _draw() -> void:
	_markers.clear()
	if _card_ids.is_empty():
		return
	var step: float = size.x / _card_ids.size()
	var gap: float = minf(2.0, step * 0.14)
	for index: int in range(_levels.size()):
		draw_rect(Rect2(index * step, BAR_TOP, step - gap, BAR_HEIGHT), _card_color(index))

	var mastered_count: int = _run.get_mastered_card_count()
	var unlocked_right: float = _run.active_deck_ids.size() * step - gap
	var encounter_boss_level: int = _run.get_encounter_boss_level()
	var next_boss_level: int = _run.bosses_defeated + 1
	var hero_right: float = 0.0
	var marker_min_left: float = 0.0
	if _run.hero_instance != null:
		var hero: GachaBallDefinition = _run.hero_instance.get_definition()
		var hero_rect: Rect2 = _marker_rect(mastered_count, step, gap)
		draw_texture_rect(hero.icon, hero_rect, false)
		hero_right = hero_rect.end.x
		marker_min_left = hero_right + MARKER_SPACING
	for level: int in range(1, _run.get_boss_count() + 1):
		var threshold: int = _run.get_boss_mastery_threshold(level)
		var rect: Rect2 = _marker_rect(threshold, step, gap)
		if level <= _run.bosses_defeated:
			var center: Vector2 = rect.get_center()
			draw_line(center - Vector2(7, 7), center + Vector2(7, 7), Color(0.94, 0.2, 0.22), 4.0)
			draw_line(center + Vector2(-7, 7), center + Vector2(7, -7), Color(0.94, 0.2, 0.22), 4.0)
		elif _run.revealed_boss_ids.has(level):
			var is_next_boss: bool = level == next_boss_level
			var is_faceoff: bool = level == encounter_boss_level or (is_next_boss and mastered_count >= threshold)
			if hero_right > 0.0 and is_faceoff:
				rect.position.x = hero_right - FACEOFF_OVERLAP
			elif hero_right > 0.0 and is_next_boss:
				var previous_threshold: int = _run.get_boss_mastery_threshold(level - 1)
				var required_mastery: int = maxi(1, threshold - previous_threshold)
				var approach: float = clampf(float(mastered_count - previous_threshold) / required_mastery, 0.0, 1.0)
				var starting_left: float = maxf(unlocked_right, marker_min_left)
				rect.position.x = lerpf(starting_left, hero_right, approach)
			else:
				rect.position.x = maxf(rect.position.x, marker_min_left)
			marker_min_left = rect.end.x + MARKER_SPACING
			var boss: GachaBallDefinition = Database.get_definition(_run.revealed_boss_ids[level]) as GachaBallDefinition
			draw_set_transform(Vector2(rect.end.x, rect.position.y), 0.0, Vector2(-1.0, 1.0))
			draw_texture_rect(boss.icon, Rect2(Vector2.ZERO, rect.size), false)
			draw_set_transform(Vector2.ZERO)
			_markers[level] = rect

func _card_color(index: int) -> Color:
	var level: int = _levels[index]
	return FlashcardProgress.MASTERY_COLORS[level] if level > 0 else LOCKED_COLOR

func _marker_rect(card_count: int, step: float, gap: float) -> Rect2:
	var center_x: float = 0.0
	if card_count > 0:
		center_x = (card_count - 1) * step + (step - gap) * 0.5
	return Rect2(center_x - MARKER_SIZE * 0.5, BAR_TOP - MARKER_SIZE, MARKER_SIZE, MARKER_SIZE)

func _boss_marker_at(point: Vector2) -> int:
	for level: int in _markers:
		if _markers[level].has_point(point):
			return level
	return 0

func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) or _boss_marker_at(point) > 0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_inspect_at(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_inspect_at(event.position)
		else:
			_close_inspector()
	elif event is InputEventMouseButton and event.pressed:
		_inspect_at(event.position)
	accept_event()

func _inspect_at(point: Vector2) -> void:
	if _card_ids.is_empty():
		_close_inspector()
		return
	var boss_level: int = _boss_marker_at(point)
	if boss_level > 0:
		if boss_level != _shown_boss:
			_show_boss(boss_level, point.x)
		return
	if point.y < BAR_TOP or not Rect2(Vector2.ZERO, size).has_point(point):
		_close_inspector()
		return
	var index: int = mini(int(point.x * _card_ids.size() / size.x), _card_ids.size() - 1)
	if index == _shown_card:
		return
	_close_inspector()
	_shown_card = index
	for neighbor: int in range(maxi(0, index - 1), mini(index + 2, _card_ids.size())):
		_add_card_preview(neighbor, neighbor == index)
	_open_inspector(point.x)

func _add_card_preview(index: int, is_selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = _card_color(index)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size.x = 104.0 if is_selected else 80.0
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", style)
	_details.add_child(card)

	var id: StringName = _card_ids[index]
	var label := Label.new()
	label.text = Database.get_flashcard_definition(id)["question"]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _study_font(id))
	label.add_theme_font_size_override("font_size", 44 if is_selected else 26)
	label.add_theme_color_override("font_color", Color(0.15, 0.17, 0.22))
	label.add_theme_color_override("font_outline_color", Color(0.98, 0.96, 0.92))
	label.add_theme_constant_override("outline_size", 4)
	card.add_child(label)

func _show_boss(level: int, x: float) -> void:
	_close_inspector()
	_shown_boss = level
	var id: StringName = _run.revealed_boss_ids[level]
	var boss: GachaBallDefinition = Database.get_definition(id) as GachaBallDefinition
	var banner: TrinketDefinition = Database.get_definition(BannerDraftingRegistry.get_banner_for_entity(id)) as TrinketDefinition
	_add_inspection_entry(boss.icon, tr(boss.display_name_key))
	_add_inspection_entry(banner.battlefield_banner_texture, tr(banner.name_key))
	_open_inspector(x)

func _add_inspection_entry(icon: Texture2D, title: String) -> void:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_details.add_child(column)
	var image := TextureRect.new()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.custom_minimum_size = Vector2(52, 52)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = icon
	column.add_child(image)
	var caption := Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)

func _open_inspector(x: float) -> void:
	var panel_style: StyleBox = _boss_panel_style if _shown_boss > 0 else _carousel_panel_style
	_inspector.add_theme_stylebox_override("panel", panel_style)
	var width: float = _inspector.get_combined_minimum_size().x
	_inspector.size = Vector2.ZERO
	_inspector.position = Vector2(clampf(x - width * 0.5, 0.0, maxf(0.0, size.x - width)), BAR_TOP + BAR_HEIGHT + 5.0)
	_inspector.show()

func _close_inspector() -> void:
	_shown_card = -1
	_shown_boss = 0
	_inspector.hide()
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()

func _study_font(id: StringName) -> Font:
	if id.begins_with("KOR_"):
		return KOREAN_FONT
	if id.begins_with("THAI_"):
		return THAI_FONT
	return STUDY_FONT
