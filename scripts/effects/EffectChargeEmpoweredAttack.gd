# res://scripts/effects/EffectChargeEmpoweredAttack.gd
@tool
class_name EffectChargeEmpoweredAttack
extends EffectDefinition

## Charges an Empowered Attack on the unit or item holder to be consumed on its next attack.
## Parameters:
##   mode: "STATIC_PER_2_TOKENS" | "STATIC_PER_M1_CORRECT" | "BURN_PER_CORRECT" | "BURN_PER_2_TOKENS" | "BONUS_DAMAGE_SPEND_1_IF_3_TOKENS" | "BURN_PER_2_CORRECT" | "BONUS_DAMAGE_PER_2_TOKENS"
##   scale_by_level: bool (default true)

const C = preload("res://scripts/Constants.gd")

func execute(source_uuid: String, _targets: Array[String], battle_manager: Node, context: TriggerContext) -> EffectResult:
	var result := EffectResult.new()
	var source_inst: GachaBallInstance = battle_manager.get_instance_by_uuid(source_uuid)
	if not is_instance_valid(source_inst):
		return EffectResult.empty()
	
	var target_unit: GachaBallInstance = source_inst
	var source_def: GachaBallDefinition = source_inst.get_definition()
	if is_instance_valid(source_def) and source_def.category == &"ITEM":
		if not source_inst.equipped_on_uuid.is_empty():
			target_unit = battle_manager.get_instance_by_uuid(source_inst.equipped_on_uuid)
	
	if not is_instance_valid(target_unit) or target_unit.current_hp <= 0:
		return EffectResult.empty()
	
	var level: int = source_inst.level
	var mode: String = parameters.get("mode", "")
	
	match mode:
		"STATIC_PER_2_TOKENS":
			var tokens: int = battle_manager.get_gacha_tokens()
			var static_stacks: int = int(tokens / 2) * level
			if static_stacks > 0:
				target_unit.charged_empowered_attack["static_stacks"] = int(target_unit.charged_empowered_attack.get("static_stacks", 0)) + static_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Static)!" % [target_unit.definition_id, static_stacks]
				}))
		"BURN_PER_2_TOKENS":
			var tokens: int = battle_manager.get_gacha_tokens()
			var burn_stacks: int = int(tokens / 2) * level
			if burn_stacks > 0:
				target_unit.charged_empowered_attack["burn_stacks"] = int(target_unit.charged_empowered_attack.get("burn_stacks", 0)) + burn_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Burn)!" % [target_unit.definition_id, burn_stacks]
				}))
		"STATIC_PER_TOKEN":
			var tokens: int = battle_manager.get_gacha_tokens()
			var static_stacks: int = tokens * level
			if static_stacks > 0:
				target_unit.charged_empowered_attack["static_stacks"] = int(target_unit.charged_empowered_attack.get("static_stacks", 0)) + static_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Static)!" % [target_unit.definition_id, static_stacks]
				}))
		"BURN_PER_TOKEN":
			var tokens: int = battle_manager.get_gacha_tokens()
			var burn_stacks: int = tokens * level
			if burn_stacks > 0:
				target_unit.charged_empowered_attack["burn_stacks"] = int(target_unit.charged_empowered_attack.get("burn_stacks", 0)) + burn_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Burn)!" % [target_unit.definition_id, burn_stacks]
				}))
		"SPEND_1_STATIC_PER_TOKEN_HELD":
			var tokens: int = battle_manager.get_gacha_tokens()
			if tokens >= 1:
				var spent: bool = battle_manager.spend_gacha_tokens(1, source_uuid)
				if spent:
					var static_stacks: int = tokens * level
					target_unit.charged_empowered_attack["static_stacks"] = int(target_unit.charged_empowered_attack.get("static_stacks", 0)) + static_stacks
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
						"text": "%s spends 1 Token to charge an Empowered Attack (+%d Static)!" % [target_unit.definition_id, static_stacks]
					}))
		"SPEND_1_BURN_PER_TOKEN_HELD", "SPEND_1_PRE_BATTLE_BURN_PER_TOKEN_HELD":
			var tokens: int = battle_manager.get_gacha_tokens()
			if tokens >= 1:
				var spent: bool = battle_manager.spend_gacha_tokens(1, source_uuid)
				if spent:
					var burn_stacks: int = tokens * level
					target_unit.charged_empowered_attack["burn_stacks"] = int(target_unit.charged_empowered_attack.get("burn_stacks", 0)) + burn_stacks
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
						"text": "%s spends 1 Token to charge an Empowered Attack (+%d Burn)!" % [target_unit.definition_id, burn_stacks]
					}))
		"SPEND_1_BONUS_DAMAGE_PER_TOKEN_HELD":
			var tokens: int = battle_manager.get_gacha_tokens()
			if tokens >= 1:
				var spent: bool = battle_manager.spend_gacha_tokens(1, source_uuid)
				if spent:
					var bonus_dmg: int = tokens * level
					target_unit.charged_empowered_attack["bonus_damage"] = int(target_unit.charged_empowered_attack.get("bonus_damage", 0)) + bonus_dmg
					result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
						"text": "%s spends 1 Token to charge an Empowered Attack (+%d Bonus Damage)!" % [target_unit.definition_id, bonus_dmg]
					}))
		"STATIC_PER_M1_CORRECT":
			var results: Dictionary = battle_manager.get_last_minigame_results()
			var m1_correct: int = int(results.get("mastery_1_correct", 0))
			var static_stacks: int = m1_correct * level
			if static_stacks > 0:
				target_unit.charged_empowered_attack["static_stacks"] = int(target_unit.charged_empowered_attack.get("static_stacks", 0)) + static_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Static)!" % [target_unit.definition_id, static_stacks]
				}))
		"BURN_PER_CORRECT":
			var results: Dictionary = battle_manager.get_last_minigame_results()
			var correct: int = int(results.get("correct_answers", 0))
			var burn_stacks: int = correct * level
			if burn_stacks > 0:
				target_unit.charged_empowered_attack["burn_stacks"] = int(target_unit.charged_empowered_attack.get("burn_stacks", 0)) + burn_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Burn)!" % [target_unit.definition_id, burn_stacks]
				}))
		"BONUS_DAMAGE_SPEND_1_IF_3_TOKENS":
			var tokens: int = battle_manager.get_gacha_tokens()
			if tokens >= 3:
				var bonus_dmg: int = tokens
				target_unit.charged_empowered_attack["bonus_damage"] = int(target_unit.charged_empowered_attack.get("bonus_damage", 0)) + bonus_dmg
				target_unit.charged_empowered_attack["spend_tokens"] = int(target_unit.charged_empowered_attack.get("spend_tokens", 0)) + 1
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Bonus Damage, spend 1 Token)!" % [target_unit.definition_id, bonus_dmg]
				}))
		"BURN_PER_2_CORRECT":
			var results: Dictionary = battle_manager.get_last_minigame_results()
			var correct: int = int(results.get("correct_answers", 0))
			var burn_stacks: int = int(correct / 2)
			if burn_stacks > 0:
				target_unit.charged_empowered_attack["burn_stacks"] = int(target_unit.charged_empowered_attack.get("burn_stacks", 0)) + burn_stacks
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Burn)!" % [target_unit.definition_id, burn_stacks]
				}))
		"BONUS_DAMAGE_PER_2_TOKENS":
			var tokens: int = battle_manager.get_gacha_tokens()
			var pairs: int = int(tokens / 2)
			var bonus_dmg: int = pairs * level
			var spend_tokens: int = pairs * level
			if bonus_dmg > 0:
				target_unit.charged_empowered_attack["bonus_damage"] = int(target_unit.charged_empowered_attack.get("bonus_damage", 0)) + bonus_dmg
				target_unit.charged_empowered_attack["spend_tokens"] = int(target_unit.charged_empowered_attack.get("spend_tokens", 0)) + mini(spend_tokens, tokens)
				result.add_event(CombatEvent.new(CombatEvent.Type.LOG_MESSAGE, {
					"text": "%s charges an Empowered Attack (+%d Bonus Damage, spend %d Tokens)!" % [target_unit.definition_id, bonus_dmg, mini(spend_tokens, tokens)]
				}))
	
	result.state_applied = true
	return result
