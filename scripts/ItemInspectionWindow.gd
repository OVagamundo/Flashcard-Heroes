class_name ItemInspectionWindow
extends InspectionWindow

const _InputUtils = preload("res://scripts/InputUtils.gd")
const C = preload("res://scripts/Constants.gd")

@onready var name_label: Label = %NameLabel
@onready var description_label: RichTextLabel = %DescriptionLabel
@onready var recipe_container: HBoxContainer = %RecipeContainer
@onready var separator: HSeparator = %HSeparator
@onready var internal_background: ColorRect = $InternalBackground

var _source_view: Control
var _instance: GachaBallInstance
var _location: LocationIdentifier
var _inspected_item_uuid: String

func _ready() -> void:
	super._ready()
	SignalBus.battle_inventory_changed.connect(_on_inventory_changed)
	SignalBus.unit_inventory_changed.connect(_on_inventory_changed)
	SignalBus.run_data_changed.connect(_on_inventory_changed)
	SignalBus.unit_stat_changed.connect(_on_unit_stat_changed)

	for child in [description_label, name_label, recipe_container, separator]:
		if is_instance_valid(child):
			child.custom_minimum_size = Vector2.ZERO
	
	enforce_display_only()


func populate(context: Dictionary) -> void:
	_source_view = context.get("source_view")
	_instance = context.get("instance")
	_location = context.get("location")

	if not is_instance_valid(_source_view) or not is_instance_valid(_instance):
		WindowManager.request_close_inspection_window(self , &"INVALID_CONTEXT")
		return

	var item_def = _instance.get_definition()
	if not is_instance_valid(item_def):
		WindowManager.request_close_inspection_window(self , &"INVALID_DEFINITION")
		return

	_inspected_item_uuid = _instance.ball_uuid
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
	name_label.add_theme_font_size_override("font_size", 32)
	
	var title_color = Color(0, 0.4, 0.8, 1) # Default blue
	if item_def is GachaBallDefinition:
		match item_def.tier:
			1: title_color = Color.YELLOW
			2: title_color = Color.MAGENTA
			3: title_color = Color.CYAN
	name_label.add_theme_color_override("font_color", title_color)

	var trait_id := _get_linked_trait_id(item_def)
	var full_text := ""
	
	if not trait_id.is_empty():
		full_text = _build_trait_trinket_description(trait_id)
		description_label.set_meta("effect_definition", null)
		
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
		
		# Build abilities section: list all abilities with name and localized description
		var abilities_block := ""
		var abilities_lines: Array[String] = []
		for entry in _instance.get_active_ability_entries(_get_all_instances_db()):
			var ability: AbilityDefinition = entry.get("ability_def")
			if not is_instance_valid(ability):
				continue
			var ability_name := tr(ability.name_key) if "name_key" in ability else ""
			if "name_key" in ability and ability_name == ability.name_key and ability.name_key.begins_with("ability."):
				ability_name = ""
			var ability_desc := tr(ability.description_key) if "description_key" in ability else ""
			if "description_key" in ability and ability_desc == ability.description_key and ability.description_key.begins_with("ability."):
				ability_desc = ""
			if is_instance_valid(_instance):
				ability_desc = ability_desc.replace("(PWR)", str(_instance.current_pwr) + " (PWR)")
				ability_desc = ability_desc.replace("(HP)", str(_instance.current_hp) + " (HP)")
				if ability.id == &"ability_echoing_orb_scale":
					var current_bonus = 0
					var all_db = _get_all_instances_db()
					if not _instance.equipped_on_uuid.is_empty():
						var holder = all_db.get(_instance.equipped_on_uuid)
						if is_instance_valid(holder):
							current_bonus = holder.get_status_effect_amount(StringName("echoing_orb_scaling_" + _instance.ball_uuid))
					if current_bonus == 0:
						var count = 0
						for uuid in all_db:
							var inst = all_db[uuid]
							if is_instance_valid(inst) and inst.definition_id == &"item_t2_d":
								count += 1
						current_bonus = maxi(1, count) * 2
					var suffix = " (Currently %+d PWR)" % current_bonus if TranslationServer.get_locale().begins_with("en") else " (Atualmente %+d PWR)" % current_bonus
					ability_desc += " [color=#4ade80]%s[/color]" % suffix
			
			if not ability_name.is_empty() or not ability_desc.is_empty():
				abilities_lines.append("[b]%s[/b]: %s" % [ability_name, ability_desc])
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
	description_label.text = final_text
	
	_update_recipe_display(item_def)

	# Manage separator visibility based on recipe container
	if is_instance_valid(separator):
		separator.visible = recipe_container.visible

	# Force window to shrink to its minimal content size after layout settles
	_reset_window_size()

func _on_inventory_changed() -> void:
	if not is_instance_valid(self):
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
	if is_instance_valid(_instance):
		if unit_uuid == _instance.equipped_on_uuid or unit_uuid == _inspected_item_uuid:
			_on_inventory_changed()

func _reset_window_size() -> void:
	# With WindowManager now enforcing width before population, we can reset instantly
	if is_instance_valid(self):
		if is_instance_valid(recipe_container) and not recipe_container.visible:
			recipe_container.custom_minimum_size = Vector2.ZERO
		
		# Enforce shrinking on EVERY container in the hierarchy
		size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var margin_container = get_node_or_null("MarginContainer")
		if margin_container:
			margin_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var vbox = get_node_or_null("MarginContainer/VBoxContainer")
		if vbox:
			vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			
		custom_minimum_size = Vector2(480, 0)
		size = Vector2.ZERO # Force immediate recalculation of minimum size
		reset_size()
		enforce_display_only()

func _get_all_instances_db() -> Dictionary:
	if GameManager.is_in_battle:
		var bm = get_tree().get_first_node_in_group("battle_manager")
		return bm.get_all_instances() if is_instance_valid(bm) else {}
	return GameManager.run_state.run_instances if is_instance_valid(GameManager.run_state) else {}

func _get_linked_trait_id(item_def: Resource) -> String:
	if not is_instance_valid(item_def):
		return ""
	if "linked_trait_id" in item_def and item_def.linked_trait_id != &"":
		return String(item_def.linked_trait_id)
	

	for trait_name in C.TRAIT_SORT_ORDER:
		var trait_def: Dictionary = C.TRAIT_DEFINITIONS.get(trait_name, {})
		if trait_def.get("trinket_id", &"") == item_def.id:
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
		var color_tag := "[color=#FFFF00]" if is_active else "[color=#888888]"
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
	if is_instance_valid(_location) and _location.container == C.BATTLE_CONTAINER_TAGS.ENEMY_TRINKETS:
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


func _update_recipe_display(item_def: Resource) -> void:
	if not is_instance_valid(recipe_container):
		return
	
	for child in recipe_container.get_children():
		child.queue_free()
	
	if not item_def is GachaBallDefinition:
		recipe_container.visible = false
		return
	
	var recipe: MergeRecipe = Database.get_recipe_for_result(item_def.id)
	if not is_instance_valid(recipe):
		recipe_container.visible = false
		return
	
	var def_a = Database.get_definition(recipe.ingredient_a_id)
	var def_b = Database.get_definition(recipe.ingredient_b_id)
	
	if not is_instance_valid(def_a) or not is_instance_valid(def_b):
		recipe_container.visible = false
		return
	
	var _make_icon = func(def: Resource) -> TextureRect:
		var tex = TextureRect.new()
		if def and def.icon:
			tex.texture = def.icon
			tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex.custom_minimum_size = Vector2(96, 96)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = MOUSE_FILTER_IGNORE
		return tex
	
	var _make_label = func(txt: String) -> Control:
		var container = CenterContainer.new()
		container.custom_minimum_size = Vector2(32, 96)
		container.mouse_filter = MOUSE_FILTER_IGNORE
		
		var lbl = Label.new()
		lbl.text = txt
		lbl.add_theme_font_override("font", Database.get_current_locale_font())
		lbl.add_theme_font_size_override("font_size", 32)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.mouse_filter = MOUSE_FILTER_IGNORE
		
		container.add_child(lbl)
		return container
	
	recipe_container.add_child(_make_icon.call(def_a))
	recipe_container.add_child(_make_label.call("+"))
	recipe_container.add_child(_make_icon.call(def_b))
	recipe_container.visible = true

func get_child_window_specs() -> Array[Dictionary]:
	var specs: Array[Dictionary] = []
	var text_to_search: String = ""
	if is_instance_valid(description_label):
		text_to_search += description_label.text + " "
	
	var keywords = DescriptionParser.find_keywords(text_to_search)
	var seen_effects: Dictionary = {}
	for kw in keywords:
		if not seen_effects.has(kw):
			seen_effects[kw] = true
			var name_key = "STATUS_" + kw.to_upper()
			var desc_key = "STATUS_" + kw.to_upper() + "_DESC"
			specs.append({
				"window_type": &"EffectInspection",
				"populate_context": {
					"effect_definition": {
						"name_key": name_key,
						"description_key": desc_key
					},
					"is_inside_unit_inspection": true,
					"target_parent_window_id": get_instance_id()
				}
			})
	return specs

func get_location() -> LocationIdentifier:
	return _location

func _trigger_trait_tutorial() -> void:
	# Wait 1.0s before showing tutorial to avoid "quick pass" triggers as requested
	await AnimationConstants.create_pausable_timer(get_tree(), 1.0).timeout
	
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	TutorialManager.show_tutorial(&"traits", [
		{
			"text": tr("tutorial.traits"),
			"anchor_side": "AUTO_HORIZONTAL" # Attempt to place next to the inspection window without overlapping
		}
	], self)
