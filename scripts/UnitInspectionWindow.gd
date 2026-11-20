class_name UnitInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")
const C = preload("res://scripts/Constants.gd")
const TraitTags = preload("res://scripts/ui/TraitTags.gd")
const LEVEL_1_STARS_TEXTURE: Texture2D = preload("res://assets/PixelArt/ui/textures/unit_level_1_stars.png")
const LEVEL_2_STARS_TEXTURE: Texture2D = preload("res://assets/PixelArt/ui/textures/unit_level_2_stars.png")
const LEVEL_3_STARS_TEXTURE: Texture2D = preload("res://assets/PixelArt/ui/textures/unit_level_3_stars.png")

@onready var name_label: Label = %NameLabel
@onready var level_stars_icon: TextureRect = %LevelStarsIcon
@onready var trait_tags_container: TraitTags = %TraitTagsContainer
@onready var attack_row: RichTextLabel = %AttackRow
@onready var view_container: CenterContainer = %ViewContainer
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var bottom_description_label: RichTextLabel = %BottomDescriptionLabel
@onready var equipped_container: VBoxContainer = %EquippedContainer
@onready var equipped_header_label: Label = %EquippedHeaderLabel
@onready var equipped_items_list: VBoxContainer = %EquippedItemsList
@onready var trait_icons_container: HBoxContainer = %TraitIconsContainer
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _inspected_unit_uuid: String
var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _is_enemy_context: bool = false
var _is_preview: bool = false
var _is_vcr_snapshot: bool = false
var _snapshot_instances_db: Dictionary = {}
var _explicit_recipe_id: StringName = &""
var _window_group_id: int = 1 # Inspection window group

func _ready() -> void:
	super._ready()
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_unit_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)
	
	# Zero out internal minimums so they don't force a height from old .tscn values
	for child in [%DescriptionLabel, %BottomDescriptionLabel, %NameLabel, %TraitTagsContainer, %EquippedContainer, %TraitIconsContainer, %RecipeContainer, %HSeparator, %AttackRow]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	if is_instance_valid(description_label):
		description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	if is_instance_valid(bottom_description_label):
		bottom_description_label.add_theme_font_override("normal_font", Database.get_current_locale_font())
		bottom_description_label.add_theme_font_override("bold_font", Database.get_current_locale_font())
	if is_instance_valid(attack_row):
		attack_row.add_theme_font_override("normal_font", Database.get_current_locale_font())
		attack_row.add_theme_font_override("bold_font", Database.get_current_locale_font())
	
	enforce_display_only()

func _exit_tree() -> void:
	if SignalBus.is_connected("battle_inventory_changed", _on_inventory_changed):
		SignalBus.battle_inventory_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_inventory_changed", _on_unit_inventory_changed):
		SignalBus.unit_inventory_changed.disconnect(_on_unit_inventory_changed)
	if SignalBus.is_connected("run_data_changed", _on_inventory_changed):
		SignalBus.run_data_changed.disconnect(_on_inventory_changed)
	if SignalBus.is_connected("unit_stat_changed", _on_unit_stat_changed):
		SignalBus.unit_stat_changed.disconnect(_on_unit_stat_changed)

func _gui_input(event: InputEvent) -> void:
	# Local background-click handling: prune only this window's descendants.
	if _InputUtils.is_primary_pointer_press(event):
		WindowManager.handle_inspection_background_click(self)
		get_viewport().set_input_as_handled()

func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")
	_is_enemy_context = context.get("is_enemy_context", false)
	_is_preview = context.get("is_preview", false)
	_is_vcr_snapshot = context.get("is_vcr_snapshot", false)
	_snapshot_instances_db = context.get("snapshot_instances_db", {})
	_explicit_recipe_id = context.get("recipe_id", &"")

	if not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	if not _is_preview and not is_instance_valid(_source_view):
		WindowManager.request_close_inspection_window(self, &"INVALID_CONTEXT")
		return

	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		WindowManager.request_close_inspection_window(self, &"INVALID_DEFINITION")
		return

	_inspected_unit_uuid = _instance.ball_uuid


	name_label.text = tr(unit_definition.display_name_key)
	name_label.add_theme_font_override("font", Database.get_current_locale_font())
	name_label.add_theme_font_size_override("font_size", 26)
	_update_level_star_display()
	
	var title_color: Color = Color("#0F172A") # High-contrast charcoal default
	match unit_definition.tier:
		1: title_color = Color("#854D0E") # Deep Bronze / Amber
		2: title_color = Color("#701A75") # Deep Crimson Violet / Purple
		3: title_color = Color("#1E3A8A") # Deep Royal Navy / Azure
	name_label.add_theme_color_override("font_color", title_color)
	_update_attack_row()
	_update_description()

	# --- Core UI Population Logic ---
	_update_equipped_items_display()
	_update_trait_display()
	_update_unit_view()
	_update_recipe_display()

	# Manage separator visibility based on any visible footers (hidden to eliminate grey line crossing stats)
	if is_instance_valid(separator):
		separator.visible = false
		separator.custom_minimum_size = Vector2.ZERO

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()
	_schedule_deferred_shrink()
	enforce_display_only()

func _update_level_star_display() -> void:
	assert(_instance.level >= 1 and _instance.level <= 3, "UnitInspectionWindow: unit level must be between 1 and 3")
	match _instance.level:
		1:
			level_stars_icon.texture = LEVEL_1_STARS_TEXTURE
		2:
			level_stars_icon.texture = LEVEL_2_STARS_TEXTURE
		3:
			level_stars_icon.texture = LEVEL_3_STARS_TEXTURE
	level_stars_icon.visible = true

func _reset_window_size() -> void:
	_shrink_window_layout(
		0.0 if _is_preview else 360.0,
		false,
		[view_container, equipped_container, recipe_container, trait_icons_container, trait_tags_container, separator, bottom_description_label, attack_row]
	)

func _update_equipped_items_display() -> void:
	if not is_instance_valid(equipped_container):
		return
		
	for child in equipped_items_list.get_children():
		child.queue_free()
		
	if not is_instance_valid(_instance):
		equipped_container.visible = false
		equipped_container.custom_minimum_size = Vector2.ZERO
		return
		
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		equipped_container.visible = false
		equipped_container.custom_minimum_size = Vector2.ZERO
		return
		
	var all_instances_db := _get_all_instances_db()
	var equipped_count := 0
	var font = Database.get_current_locale_font()
	
	for i in range(unit_definition.item_slot_count):
		var item_uuid = _instance.get_equipped_item_uuid(i)
		if item_uuid.is_empty() or not all_instances_db.has(item_uuid):
			continue
			
		var item_inst = all_instances_db[item_uuid]
		if not is_instance_valid(item_inst):
			continue
			
		var item_def = item_inst.get_definition()
		if not is_instance_valid(item_def):
			continue
			
		equipped_count += 1
		
		# Build item title (name + stats)
		var item_name = tr(item_def.display_name_key) if "display_name_key" in item_def and not item_def.display_name_key.is_empty() else tr(item_def.id)
		var stat_parts: Array[String] = []
		if "bonus_pwr" in item_def and item_def.bonus_pwr > 0:
			stat_parts.append("+%d PWR" % item_def.bonus_pwr)
		if "bonus_hp" in item_def and item_def.bonus_hp > 0:
			stat_parts.append("+%d HP" % item_def.bonus_hp)
		var stat_suffix = (" (%s)" % ", ".join(stat_parts)) if not stat_parts.is_empty() else ""
		
		var title_label = RichTextLabel.new()
		title_label.bbcode_enabled = true
		title_label.fit_content = true
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_font_override("normal_font", font)
		title_label.add_theme_font_override("bold_font", font)
		title_label.add_theme_font_size_override("normal_font_size", 20)
		title_label.add_theme_font_size_override("bold_font_size", 20)
		title_label.text = "[color=#92400E][b]%s[/b][/color][color=#15803D]%s[/color]" % [item_name, stat_suffix]
		equipped_items_list.add_child(title_label)
		
		# Build item abilities description
		var abilities_lines: Array[String] = []
		var seen_ability_descriptions: Dictionary[String, bool] = {}
		for entry in item_inst.get_active_ability_entries(all_instances_db):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			var ab_desc := tr(ability.description_key) if "description_key" in ability else ""
			if "description_key" in ability and ab_desc == ability.description_key and ability.description_key.begins_with("ability."):
				ab_desc = ""
			if not ab_desc.is_empty():
				ab_desc = ab_desc.replace("(PWR)", str(item_inst.current_pwr) + " (PWR)")
				ab_desc = ab_desc.replace("(HP)", str(item_inst.current_hp) + " (HP)")
				var description_signature: String = ab_desc.strip_edges()
				if not seen_ability_descriptions.has(description_signature):
					seen_ability_descriptions[description_signature] = true
					abilities_lines.append(ab_desc)
				
		var desc_text = "\n".join(abilities_lines).strip_edges()
		if desc_text.is_empty() and "description_key" in item_def:
			desc_text = tr(item_def.description_key)
			
		if not desc_text.is_empty():
			var parsed_desc = DescriptionParser.parse(desc_text)
			var desc_label = RichTextLabel.new()
			desc_label.bbcode_enabled = true
			desc_label.fit_content = true
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc_label.add_theme_font_override("normal_font", font)
			desc_label.add_theme_font_override("bold_font", font)
			desc_label.add_theme_font_size_override("normal_font_size", 18)
			desc_label.add_theme_font_size_override("bold_font_size", 18)
			desc_label.add_theme_constant_override("line_separation", 2)
			desc_label.add_theme_color_override("default_color", Color(0.15, 0.15, 0.15, 1.0))
			desc_label.text = parsed_desc
			equipped_items_list.add_child(desc_label)

	equipped_container.visible = equipped_count > 0
	if not equipped_container.visible:
		equipped_container.custom_minimum_size = Vector2.ZERO
	if is_instance_valid(equipped_header_label):
		equipped_header_label.text = tr("ui.equipped_items") if equipped_count > 1 else tr("ui.equipped_item")

	
func _update_attack_row() -> void:
	if not is_instance_valid(attack_row) or not is_instance_valid(_instance):
		if is_instance_valid(attack_row):
			attack_row.visible = false
		return
	
	var font = Database.get_current_locale_font()
	attack_row.add_theme_font_override("normal_font", font)
	attack_row.add_theme_font_override("bold_font", font)
	attack_row.add_theme_font_size_override("normal_font_size", 20)
	attack_row.add_theme_font_size_override("bold_font_size", 20)
	attack_row.add_theme_constant_override("line_separation", 3)
	
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		attack_row.visible = false
		return
	
	# Check if there is an attack override
	var override_ability: AbilityDefinition = null
	var all_instances_db := _get_all_instances_db()
	for entry in _instance.get_active_ability_entries(all_instances_db):
		var ability_def: AbilityDefinition = entry.get("ability_def")
		if is_instance_valid(ability_def) and ability_def.replaces_basic_attack:
			override_ability = ability_def
			break
	
	if is_instance_valid(override_ability):
		var attack_prefix = tr("ui.attack_override")
		var desc = tr(override_ability.description_key)
		var kws = DescriptionParser.find_keywords(desc)
		var tags: Array[String] = []
		if desc.to_lower().contains("melee") or desc.to_lower().contains("corpo a corpo") or desc.to_lower().contains("shockwave") or desc.to_lower().contains("onda de choque"):
			tags.append("MELEE")
		elif desc.to_lower().contains("ranged") or desc.to_lower().contains("distância") or desc.to_lower().contains("distancia"):
			tags.append("RANGED")
		for kw in kws:
			if not tags.has(kw) and kw != "MELEE" and kw != "RANGED":
				tags.append(kw)
		if tags.is_empty():
			tags.append("MELEE")
		
		var formatted_tags: Array[String] = []
		for t in tags:
			var info = DescriptionParser.get_keyword_info(t)
			var display_text = tr(info.get("name_key", t))
			var col = info.get("color", "#FFA726")
			formatted_tags.append("[b][color=%s]%s[/color][/b]" % [col, display_text])
		
		attack_row.text = "[b]%s[/b] %s" % [attack_prefix, " ".join(formatted_tags)]
		attack_row.visible = true
	else:
		var is_ranged := false
		if "ability_definitions" in unit_definition and unit_definition.ability_definitions != null:
			for ab in unit_definition.ability_definitions:
				if is_instance_valid(ab) and (ab.id == &"basic_attack_ranged_mirror" or String(ab.id).contains("ranged")):
					is_ranged = true
					break
		
		var attack_prefix = tr("ui.attack")
		if is_ranged:
			var info = DescriptionParser.get_keyword_info("RANGED")
			var display_text = tr(info.get("name_key", "RANGED"))
			var target_hint = tr("ui.target_mirror")
			attack_row.text = "[b]%s[/b] [b][color=%s]%s[/color][/b] [color=#666666]%s[/color]" % [attack_prefix, info.color, display_text, target_hint]
		else:
			var info = DescriptionParser.get_keyword_info("MELEE")
			var display_text = tr(info.get("name_key", "MELEE"))
			var target_hint = tr("ui.target_frontmost")
			attack_row.text = "[b]%s[/b] [b][color=%s]%s[/color][/b] [color=#666666]%s[/color]" % [attack_prefix, info.color, display_text, target_hint]
		attack_row.visible = true

func _update_description() -> void:
	if not is_instance_valid(_instance):
		return
	
	var unit_definition = _instance.get_definition()
	if not is_instance_valid(unit_definition):
		return
	
	var current_lvl: int = _instance.level if is_instance_valid(_instance) else 1

	# Build abilities section: list all abilities with name and localized description
	var abilities_lines: Array[String] = []
	var seen_ability_ids: Dictionary = {}
	var all_instances_db := _get_all_instances_db()
	
	for entry in _instance.get_active_ability_entries(all_instances_db):
		var ability_def: AbilityDefinition = entry.get("ability_def")
		if not ability_def or ability_def.id == &"basic_attack":
			continue
		
		# Units with equipped items don't show item abilities in the unit window,
		# since the item's own inspection window is opened at the same time alongside.
		if entry.get("source_type") == &"EQUIPMENT":
			continue
		
		if seen_ability_ids.has(ability_def.id):
			continue
		seen_ability_ids[ability_def.id] = true
		
		var ability_desc = tr(ability_def.description_key)
		if ability_desc == ability_def.description_key and ability_def.description_key.begins_with("ability."):
			ability_desc = ""
		if not ability_desc.is_empty():
			ability_desc = DescriptionParser.resolve_level_scaling(ability_desc, current_lvl)
		if is_instance_valid(_instance):
			ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
			ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
			if ability_def.id in [&"ability_slime_cell_scale", &"ability_doppleganger_scale"]:
				var source_uuid: String = String(entry.get("source_uuid", ""))
				var current_bonus: int = AuraEvaluator.get_displayed_aura_pwr(_instance, ability_def.id, source_uuid, all_instances_db)
				var suffix: String = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
				ability_desc += " [color=#4ade80]%s[/color]" % suffix
		
		if not ability_desc.is_empty():
			abilities_lines.append(ability_desc)

	var abilities_block := "\n".join(abilities_lines)
	
	var full_text := ""
	var unit_desc := tr(unit_definition.description_key) if "description_key" in unit_definition else ""
	if not unit_desc.is_empty() and unit_desc != unit_definition.description_key:
		unit_desc = DescriptionParser.resolve_level_scaling(unit_desc, current_lvl)
		if abilities_block.is_empty():
			full_text = unit_desc
	
	if not abilities_block.is_empty():
		if not full_text.is_empty():
			full_text += "\n\n"
		full_text += abilities_block

	if not full_text.is_empty():
		full_text = DescriptionParser.parse(full_text)

	var final_text = full_text.strip_edges()
	var regex = RegEx.new()
	regex.compile("\\n\\s*\\n+")
	final_text = regex.sub(final_text, "\n", true)
	
	var font = Database.get_current_locale_font()
	description_label.add_theme_font_override("normal_font", font)
	description_label.add_theme_font_override("bold_font", font)
	description_label.add_theme_font_size_override("normal_font_size", 22)
	description_label.add_theme_font_size_override("bold_font_size", 22)
	description_label.add_theme_constant_override("line_separation", 3)
	description_label.add_theme_constant_override("p_separation", 6)
	description_label.text = final_text
	description_label.visible = not final_text.is_empty()
	description_label.set_meta("definition", unit_definition)
	description_label.set_meta("effect_definition", unit_definition)
	
	if is_instance_valid(bottom_description_label):
		bottom_description_label.text = ""
		bottom_description_label.visible = false
		bottom_description_label.custom_minimum_size = Vector2.ZERO
## Granular stat change handler - updates description when any stat changes
func _on_unit_stat_changed(unit_uuid: String, _stat_name: StringName, _old_value: int, _new_value: int) -> void:
	if _is_preview or _is_vcr_snapshot:
		return
	if unit_uuid == _inspected_unit_uuid:
		# Update the instance reference and refresh the description
		var all_instances: Dictionary = _get_all_instances_db()
		var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
		if is_instance_valid(current_instance):
			_instance = current_instance
			_update_level_star_display()
			_update_description()
			_update_unit_view()
			_reset_window_size()

func _on_inventory_changed() -> void:
	if _is_preview or _is_vcr_snapshot:
		return
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances: Dictionary = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_INVENTORY_CHANGE")
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_level_star_display()
	_update_description()
	_update_unit_view()
	_update_equipped_items_display()
	_update_trait_display()
	_update_recipe_display()
	_reset_window_size()

func _on_unit_inventory_changed(unit_uuid: String) -> void:
	if _is_preview or _is_vcr_snapshot:
		return
	
	# Only update if the changed unit is the one we're inspecting
	if unit_uuid != _inspected_unit_uuid:
		return
	
	# Check if the inspected unit still exists. If not, the window should close.
	var all_instances = _get_all_instances_db()
	var current_instance: GachaBallInstance = all_instances.get(_inspected_unit_uuid)
	if not is_instance_valid(current_instance):
		WindowManager.request_close_inspection_window(self, &"INSTANCE_MISSING_AFTER_UNIT_INV_CHANGE")
		return
	
	# The unit still exists, so we just need to refresh the item grid.
	_instance = current_instance # Ensure we have the latest data
	_update_level_star_display()
	_update_description()
	_update_equipped_items_display()
	_update_trait_display()
	_update_recipe_display()
	_reset_window_size()

func _get_all_instances_db() -> Dictionary:
	if _is_vcr_snapshot:
		return _snapshot_instances_db
	var result: Dictionary
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		result = bm.get_all_instances() if is_instance_valid(bm) else {}
	else:
		result = GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}
	
	if _is_preview and is_instance_valid(_instance):
		result = result.duplicate()
		result[_instance.ball_uuid] = _instance
	return result

func get_glossary_terms() -> Array[String]:
	var terms: Array[String] = []
	if not is_instance_valid(_instance):
		return terms
	
	var text_to_search: String = ""
	if is_instance_valid(description_label):
		text_to_search += description_label.text + " "
	if is_instance_valid(bottom_description_label) and bottom_description_label.visible:
		text_to_search += bottom_description_label.text + " "
	if is_instance_valid(attack_row) and attack_row.visible:
		text_to_search += attack_row.text + " "
	
	terms.append_array(DescriptionParser.find_keywords(text_to_search))
	
	# Ensure basic attack or attack override keywords are always present
	var unit_definition = _instance.get_definition()
	if is_instance_valid(unit_definition):
		var override_ability: AbilityDefinition = null
		var all_instances_db := _get_all_instances_db()
		for entry in _instance.get_active_ability_entries(all_instances_db):
			var ability_def: AbilityDefinition = entry.get("ability_def")
			if is_instance_valid(ability_def) and ability_def.replaces_basic_attack:
				override_ability = ability_def
				break
		
		if is_instance_valid(override_ability):
			var desc = tr(override_ability.description_key)
			for kw in DescriptionParser.find_keywords(desc):
				if not terms.has(kw):
					terms.append(kw)
			if desc.to_lower().contains("ranged") or desc.to_lower().contains("distância") or desc.to_lower().contains("distancia"):
				if not terms.has("RANGED"):
					terms.append("RANGED")
			else:
				if not terms.has("MELEE"):
					terms.append("MELEE")
		else:
			var is_ranged := false
			if "ability_definitions" in unit_definition and unit_definition.ability_definitions != null:
				for ab in unit_definition.ability_definitions:
					if is_instance_valid(ab) and (ab.id == &"basic_attack_ranged_mirror" or String(ab.id).contains("ranged")):
						is_ranged = true
						break
			var atk_term = "RANGED" if is_ranged else "MELEE"
			if not terms.has(atk_term):
				terms.append(atk_term)
	
	# Active combat effects on the unit
	for status_key in DescriptionParser.KEYWORDS:
		var effect_id = StringName(status_key.to_lower())
		if _instance.get_status_effect_amount(effect_id) > 0:
			if not terms.has(status_key):
				terms.append(status_key)
	
	# Also collect terms from equipped items
	if is_instance_valid(unit_definition):
		var all_instances_db = _get_all_instances_db()
		for i in range(unit_definition.item_slot_count):
			var item_uuid = _instance.get_equipped_item_uuid(i)
			if not item_uuid.is_empty() and all_instances_db.has(item_uuid):
				var item_inst = all_instances_db[item_uuid]
				if is_instance_valid(item_inst):
					var it_def = item_inst.get_definition()
					if is_instance_valid(it_def) and "description_key" in it_def:
						for kw in DescriptionParser.find_keywords(tr(it_def.description_key)):
							if not terms.has(kw):
								terms.append(kw)
					for entry in item_inst.get_active_ability_entries(all_instances_db):
						var ab = entry.get("ability_def")
						if is_instance_valid(ab) and "description_key" in ab:
							var ab_desc = tr(ab.description_key)
							for kw in DescriptionParser.find_keywords(ab_desc):
								if not terms.has(kw):
									terms.append(kw)
	
	return terms

func get_child_window_specs() -> Array[Dictionary]:
	return []

func get_location() -> LocationIdentifier:
	return _location

## Calculate trait counts for the inspected unit (including emblems)
func _calculate_unit_trait_counts() -> Dictionary:
	var counts: Dictionary = {"FIRE": 0, "EARTH": 0, "WATER": 0, "AIR": 0}
	
	if not is_instance_valid(_instance):
		return counts
	
	var all_instances_db = _get_all_instances_db()
	var soul_counts = _instance.get_trait_soul_counts(all_instances_db)
	
	for soul_type in ["FIRE", "EARTH", "WATER", "AIR"]:
		counts[soul_type] += soul_counts[soul_type]
	
	return counts

## Populate the ViewContainer to show the resulting unit's view at 2x scale (battle board size) during merge preview.
func _update_unit_view() -> void:
	_populate_preview_slot_view(view_container, _instance, _location, _get_all_instances_db(), _is_preview, &"PlayerShelf")

## Populate the RecipeContainer to show the merge ingredients for this unit.
func _update_recipe_display() -> void:
	var unit_def: Resource = _instance.get_definition() if is_instance_valid(_instance) else null
	_populate_recipe_container(recipe_container, unit_def, _explicit_recipe_id, _is_preview)

## Update the trait tags display at the top
func _update_trait_display() -> void:
	if is_instance_valid(trait_icons_container):
		for child in trait_icons_container.get_children():
			trait_icons_container.remove_child(child)
			child.queue_free()
		trait_icons_container.visible = false

	trait_tags_container.populate(_instance, _get_all_instances_db())
