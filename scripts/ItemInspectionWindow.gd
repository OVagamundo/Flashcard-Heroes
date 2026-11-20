class_name ItemInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")
const C = preload("res://scripts/Constants.gd")

@onready var name_label: Label = %NameLabel
@onready var view_container: CenterContainer = %ViewContainer
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var bottom_description_label: RichTextLabel = %BottomDescriptionLabel
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _inspected_item_uuid: String
var _is_preview: bool = false
var _is_vcr_snapshot: bool = false
var _snapshot_instances_db: Dictionary = {}
var _explicit_recipe_id: StringName = &""

func _ready() -> void:
	super._ready()
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)

	for child in [description_label, bottom_description_label, name_label, recipe_container, separator]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	if is_instance_valid(description_label):
		description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	if is_instance_valid(bottom_description_label):
		bottom_description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		bottom_description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	
	enforce_display_only()


func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_preview = context.get("is_preview", false)
	_is_vcr_snapshot = context.get("is_vcr_snapshot", false)
	_snapshot_instances_db = context.get("snapshot_instances_db", {})
	_explicit_recipe_id = context.get("recipe_id", &"")

	if not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	if not _is_preview and not is_instance_valid(_source_view):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		WindowManager.request_close_inspection_window(self , &"INVALID_DEFINITION")
		return

	_inspected_item_uuid = _instance.ball_uuid
	_update_item_view()
	_update_description_and_stats(item_def)

func _update_description_and_stats(item_def: Resource) -> void:
	var name_key: String
	if item_def is GachaBallDefinition:
		name_key = item_def.display_name_key
	else:
		# TrinketDefinition uses name_key instead of display_name_key
		name_key = item_def.name_key
	
	name_label.text = tr(name_key)
	name_label.add_theme_font_override("font", Database.get_current_locale_font())
	name_label.add_theme_font_size_override("font_size", 26)
	
	var title_color := Color("#0F172A") # High-contrast charcoal default
	if item_def is GachaBallDefinition:
		match item_def.tier:
			1: title_color = Color("#854D0E") # Deep Bronze / Amber
			2: title_color = Color("#701A75") # Deep Crimson Violet / Purple
			3: title_color = Color("#1E3A8A") # Deep Royal Navy / Azure
	name_label.add_theme_color_override("font_color", title_color)

	var crest_trait_id: String = _get_crest_trait_id(item_def.id) if item_def is TrinketDefinition else ""
	var full_text := ""
	
	if not crest_trait_id.is_empty():
		var trait_ladder := _build_trait_trinket_description(crest_trait_id)
		description_label.set_meta("effect_definition", null)
		
		var base_desc := ""
		if "description_key" in item_def and not item_def.description_key.is_empty():
			var description_key: String = item_def.description_key
			var is_trait_threshold_summary: bool = description_key.begins_with("trinket.trait_") and description_key != "trinket.trait_novice.desc"
			if not is_trait_threshold_summary:
				var raw_desc: String = tr(description_key)
				base_desc = raw_desc
		
		if not base_desc.is_empty():
			full_text = base_desc + "\n\n" + trait_ladder
		else:
			full_text = trait_ladder
		
		# Trigger tutorial for traits (deferred to allow window to position itself)
		_trigger_trait_tutorial()
	else:
		# Base flavor description for trinkets (often contains passive effect info)
		var base_desc = ""
		if item_def.get("description_key") and item_def.description_key != "":
			base_desc = tr(item_def.description_key)
		elif item_def is TrinketDefinition:
			base_desc = tr(item_def.description_key)
		
		var effect_desc = ""
		if item_def is GachaBallDefinition:
			if item_def.bonus_hp > 0 and item_def.bonus_pwr > 0:
				effect_desc = tr("item.effect.both").replace("(HP)", str(item_def.bonus_hp)).replace("(PWR)", str(item_def.bonus_pwr))
			elif item_def.bonus_hp > 0:
				effect_desc = tr("item.effect.hp").replace("(HP)", str(item_def.bonus_hp))
			elif item_def.bonus_pwr > 0:
				effect_desc = tr("item.effect.pwr").replace("(PWR)", str(item_def.bonus_pwr))
		
		# Item and trinket abilities are shown as descriptions only.
		var abilities_block := ""
		var abilities_lines: Array[String] = []
		var seen_ability_descriptions: Dictionary = {}
		for entry in _instance.get_active_ability_entries(_get_all_instances_db()):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			var ability_desc := tr(ability.description_key) if "description_key" in ability else ""
			if "description_key" in ability and ability_desc == ability.description_key and ability.description_key.begins_with("ability."):
				ability_desc = ""
			if is_instance_valid(_instance):
				ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
				ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
				if ability.id == &"ability_slime_cell_scale":
					var all_db: Dictionary = _get_all_instances_db()
					var holder: GachaBallInstance = all_db.get(_instance.equipped_on_uuid) as GachaBallInstance if not _instance.equipped_on_uuid.is_empty() else null
					var current_bonus: int = AuraEvaluator.get_displayed_aura_pwr(holder, ability.id, _instance.ball_uuid, all_db) if is_instance_valid(holder) else AuraEvaluator.get_displayed_aura_pwr(_instance, ability.id, _instance.ball_uuid, all_db)
					var suffix: String = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
					ability_desc += " [color=#4ade80]%s[/color]" % suffix
			
			var description_signature := ability_desc.strip_edges()
			if not description_signature.is_empty() and not seen_ability_descriptions.has(description_signature):
				seen_ability_descriptions[description_signature] = true
				abilities_lines.append(ability_desc)
		abilities_block = "\n".join(abilities_lines)

		if not base_desc.is_empty() and abilities_block.is_empty():
			full_text += base_desc
		if not effect_desc.is_empty():
			if not full_text.is_empty(): full_text += "\n"
			full_text += effect_desc
		if not abilities_block.is_empty():
			if not full_text.is_empty():
				full_text += "\n"
			full_text += abilities_block
		
		# Store the full definition for the child window to use (if generic effect link is clicked, though we removed it)
		description_label.set_meta("effect_definition", item_def)

	if not full_text.is_empty():
		full_text = DescriptionParser.parse(full_text)

	var final_text = full_text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	
	var font = Database.get_current_locale_font()
	description_label.custom_minimum_size = Vector2.ZERO
	description_label.add_theme_font_override("normal_font", font)
	description_label.add_theme_font_override("bold_font", font)
	description_label.add_theme_font_size_override("normal_font_size", 22)
	description_label.add_theme_font_size_override("bold_font_size", 22)
	description_label.add_theme_constant_override("line_separation", 3)
	description_label.add_theme_constant_override("p_separation", 6)
	description_label.text = final_text
	description_label.visible = not final_text.is_empty()
	description_label.set_meta("effect_definition", item_def if not _is_trinket(item_def) else null)
	
	if is_instance_valid(bottom_description_label):
		bottom_description_label.text = ""
		bottom_description_label.visible = false
		bottom_description_label.custom_minimum_size = Vector2.ZERO
	
	_update_recipe_display(item_def)

	# Manage separator visibility based on recipe container (hidden to eliminate grey line)
	if is_instance_valid(separator):
		separator.visible = false
		separator.custom_minimum_size = Vector2.ZERO

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()
	_schedule_deferred_shrink()

func _on_inventory_changed() -> void:
	if _is_preview or _is_vcr_snapshot:
		return
	var all_instances: Dictionary = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_item_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_INVENTORY_CHANGE")
		return
	
	_instance = current_instance
	var item_def = _instance.get_definition()
	if is_instance_valid(item_def):
		_update_description_and_stats(item_def)

func _on_unit_stat_changed(unit_uuid: String, _stat_name: StringName, _old_value: int, _new_value: int) -> void:
	if _is_preview or _is_vcr_snapshot:
		return
	if is_instance_valid(_instance):
		if unit_uuid == _instance.equipped_on_uuid or unit_uuid == _inspected_item_uuid:
			_on_inventory_changed()

func _is_trinket(item_def: Resource) -> bool:
	return item_def is TrinketDefinition or (item_def is GachaBallDefinition and item_def.category == &"TRINKET")

func _reset_window_size() -> void:
	_shrink_window_layout(
		0.0 if _is_preview else 360.0,
		false,
		[recipe_container, separator, bottom_description_label, view_container]
	)
	enforce_display_only()

func _get_all_instances_db() -> Dictionary:
	if _is_vcr_snapshot:
		return _snapshot_instances_db
	var result: Dictionary = {}
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		result = bm.get_all_instances() if is_instance_valid(bm) else {}
	elif is_instance_valid(GameManager.run_state):
		result = GameManager.run_state.run_instances
	if _is_preview and is_instance_valid(_instance):
		result = result.duplicate()
		result[_instance.ball_uuid] = _instance
	return result

func _get_crest_trait_id(trinket_id: StringName) -> String:
	for trait_name: String in C.TRAIT_SORT_ORDER:
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS[trait_name]
		if trait_def["trinket_id"] == trinket_id:
			return trait_name
	return ""

func _build_trait_trinket_description(trait_id: String) -> String:
	var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_id, {})
	if trait_def.is_empty():
		return ""

	var current_count := _get_trait_count_for_context(trait_id)
	var lines: Array[String] = []
	for level in trait_def.get("levels", []):
		var min_req := int(level.get("min", 0))
		var is_active := current_count >= min_req
		var color_tag := "[color=#8B0000]" if is_active else "[color=#888888]"
		var prefix := "* " if is_active else "- "
		lines.append("%s%s%d: %s[/color]" % [color_tag, prefix, min_req, tr(level.get("desc_key", ""))])

	return "\n".join(lines)

func _get_trait_count_for_context(trait_id: String) -> int:
	if GameManager.is_in_battle:
		var battle_manager = get_tree().get_first_node_in_group("battle_manager")
		if is_instance_valid(battle_manager):
			var team := _get_trait_team_for_context()
			var active_traits: Dictionary = battle_manager.get_active_traits(team)
			return int(active_traits.get(trait_id, 0))
	return _get_run_trait_count(trait_id)

func _get_trait_team_for_context() -> String:
	if is_instance_valid(_location) and _location.container in [C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS, C.BATTLE_CONTAINER_TAGS.ENEMY_BANNER]:
		return "ENEMY"
	return "PLAYER"

func _get_run_trait_count(trait_id: String) -> int:
	if not is_instance_valid(GameManager.run_state):
		return 0

	var counts: Dictionary = {}
	for t in C.TRAIT_SORT_ORDER:
		counts[t] = 0

	var lineup = GameManager.run_state.get_container(RunState.RUN_CONTAINER_TAGS.PLAYER_LINEUP)
	if not is_instance_valid(lineup):
		return 0

	var all_inst = GameManager.run_state.get_all_instances()
	for unit_uuid in lineup.get_all_non_empty_uuids():
		var unit = GameManager.run_state.get_instance_by_uuid(unit_uuid)
		if not is_instance_valid(unit):
			continue
		var soul_counts = unit.get_trait_soul_counts(all_inst)
		for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
			if counts.has(soul_type):
				counts[soul_type] += soul_counts.get(soul_type, 0)
		for tag in unit.get_active_tags(all_inst):
			var upper = String(tag).to_upper()
			if counts.has(upper):
				counts[upper] += 1

	return int(counts.get(trait_id, 0))

func _accumulate_trait_tag(counts: Dictionary, tag: StringName) -> void:
	match tag:
		&"SOUL_FIRE":
			counts["FIRE"] = counts.get("FIRE", 0) + 1
		&"SOUL_EARTH":
			counts["EARTH"] = counts.get("EARTH", 0) + 1
		&"SOUL_WATER":
			counts["WATER"] = counts.get("WATER", 0) + 1
		&"SOUL_AIR":
			counts["AIR"] = counts.get("AIR", 0) + 1
		_:
			var upper = String(tag).to_upper()
			if counts.has(upper):
				counts[upper] = counts.get(upper, 0) + 1


## Populate the ViewContainer to show the resulting item's view at 2x scale (battle board size) during merge preview.
func _update_item_view() -> void:
	var item_def: Resource = _instance.get_definition() if is_instance_valid(_instance) else null
	var show_preview: bool = _is_preview and is_instance_valid(item_def) and not _is_trinket(item_def)
	_populate_preview_slot_view(view_container, _instance, _location, _get_all_instances_db(), show_preview, &"EquippedItem")

func _update_recipe_display(item_def: Resource) -> void:
	_populate_recipe_container(recipe_container, item_def, _explicit_recipe_id, _is_preview)

func get_glossary_terms() -> Array[String]:
	return _collect_glossary_terms_from_labels([description_label, bottom_description_label])

func get_child_window_specs() -> Array[Dictionary]:
	return []

func get_location() -> LocationIdentifier:
	return _location

func _trigger_trait_tutorial() -> void:
	if _is_preview or not is_inside_tree():
		return
	# Wait 1.0s before showing tutorial to avoid "quick pass" triggers as requested.
	# Node-bound Tween automatically cancels if this inspection window is freed.
	var tutorial_tween: Tween = create_tween()
	tutorial_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tutorial_tween.tween_interval(1.0)
	tutorial_tween.tween_callback(_show_trait_tutorial)

func _show_trait_tutorial() -> void:
	if not is_inside_tree():
		return
	TutorialManager.show_tutorial(&"traits", [
		{
			"text": "tutorial.traits",
			"anchor_side": "AUTO_HORIZONTAL",
			"pause_game": true
		}
	], description_label)
