@tool
class_name EffectSummonUnitOnDeath
extends EffectDefinition

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], _battle_manager: Node, context: TriggerContext) -> EffectResult:
	assert(source_uuid == context.knocked_out_uuid, "EffectSummonUnitOnDeath: source must match the knocked-out unit")
	assert(is_instance_valid(context.knocked_out_location), "EffectSummonUnitOnDeath: knockout location is required")
	assert(parameters.has("level"), "EffectSummonUnitOnDeath: summon level is required")
	var summon_level: int = int(parameters["level"])
	assert(summon_level >= 1 and summon_level <= 3, "EffectSummonUnitOnDeath: summon level must be 1, 2, or 3")
	assert(parameters.has("unit_id") != parameters.has("tier"), "EffectSummonUnitOnDeath: define either unit_id or tier")

	var summon_unit_id: StringName
	if parameters.has("unit_id"):
		summon_unit_id = StringName(parameters["unit_id"])
		assert(Database.units.has(summon_unit_id), "EffectSummonUnitOnDeath: summon unit %s is not registered" % String(summon_unit_id))
	else:
		var target_tier: int = int(parameters["tier"])
		var is_player: bool = BattleHelpers.is_player_team_context(context, context.knocked_out_location)
		var tier_units: Array[GachaBallDefinition] = Database.get_eligible_summon_units(target_tier, is_player)
		assert(not tier_units.is_empty(), "EffectSummonUnitOnDeath: no eligible Tier %d units for is_player=%s" % [target_tier, is_player])
		summon_unit_id = RNGManager.combat_rng.pick_random(tier_units).id

	var result := EffectResult.new()
	result.summon_request = {
		"summon_unit_id": summon_unit_id,
		"holder_uuid": context.knocked_out_uuid,
		"holder_location": context.knocked_out_location,
		"level": summon_level,
		"spawn_source_uuid": context.knocked_out_uuid,
		"spawn_source_location": context.knocked_out_location
	}
	return result
