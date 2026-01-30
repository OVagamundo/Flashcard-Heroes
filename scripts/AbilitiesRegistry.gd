# res://scripts/AbilitiesRegistry.gd
class_name AbilitiesRegistry
extends RefCounted

## Central source of truth for all abilities
## Use this file to understand what each ability does and how it triggers.
## This registry documents the complete ability system for easy reference.

## Trigger Types Reference:
## - on_attack: Unit performs its turn action attack (NOT retaliate/extra attack)
## - on_damage_dealt: After this unit deals attack damage (any source)
## - on_hurt: After this unit receives attack damage
## - on_before_damage: Before this unit receives attack damage
## - on_death: This unit dies
## - on_ally_death: A teammate dies (not self)
## - on_kill: This unit kills an enemy
## - on_turn_start: Turn begins
## - on_turn_end: Turn ends
## - on_battle_start: Battle begins
## - passive_intercept: Special BattleManager-handled passive (e.g., Guardian)

const ABILITIES: Dictionary = {
	# ==================== UNIT ABILITIES ====================
	
	"basic_attack": {
		"owner": "All units",
		"trigger": "TURN_ACTION",
		"effect": "Deal PWR damage to front enemy",
	},
	
	"unit_tier1a_passive_heal": {
		"owner": "Apprentice (T1A)",
		"trigger": "on_hurt",
		"condition": "DAMAGE_WAS_NON_LETHAL",
		"effect": "Heal self for PWR",
		"notes": "Only heals if surviving the damage",
	},
	
	"unit_tier1b_counter_on_hurt": {
		"owner": "Squire (T1B)",
		"trigger": "on_hurt",
		"condition": "DAMAGE_WAS_RECEIVED",
		"effect": "Attack the attacker for PWR damage",
		"execute_on_lethal": true,
		"notes": "Counter-attacks even when taking lethal damage",
	},
	
	"unit_tier2a_defensive_stance": {
		"owner": "Guardian (T2A)",
		"trigger": "on_before_damage",
		"condition": null,
		"effect": "Gain +2 HP before receiving attack damage",
		"notes": "Triggers for main attack AND splash damage (Shockwave)",
	},
	
	"unit_tier2b_shockwave": {
		"owner": "Berserker (T2B)",
		"trigger": "on_attack",
		"condition": null,
		"effect": "Deal 50% PWR damage to enemies behind the main target",
		"notes": "Only triggers on turn action attack, NOT on retaliate/extra attack",
	},
	
	"unit_tier2c_ally_death_buff": {
		"owner": "Knight (T2C)",
		"trigger": "on_ally_death",
		"condition": null,
		"effect": "Gain +2 HP and +2 PWR when an ally dies",
	},
	
	"unit_tier3a_mirror_strike": {
		"owner": "Shadow Striker (T3A)",
		"trigger": "on_attack",
		"condition": null,
		"effect": "Also attack the enemy in the mirror position",
		"notes": "Only triggers on turn action attack",
	},
	
	"unit_tier3b_guardian_sacrifice": {
		"owner": "Guardian Sentinel (T3B)",
		"trigger": "passive_intercept",
		"condition": null,
		"effect": "Intercept lethal damage meant for an ally",
		"notes": "Handled directly by BattleManager, not through normal ability flow",
	},
	
	"unit_tier3c_soul_summon": {
		"owner": "Soul Keeper (T3C)",
		"trigger": "on_death",
		"condition": null,
		"effect": "Resurrect the first ally that died this battle",
	},
	
	"unit_tier3d_resilient_aura": {
		"owner": "Resilient Aura (T3D)",
		"trigger": "on_hurt",
		"condition": null,
		"effect": "Grant +1 HP and +1 PWR to all allies when damaged",
		"execute_on_lethal": true,
	},
	
	"hero_timekeeper_gold_on_kill": {
		"owner": "Timekeeper (Hero)",
		"trigger": "on_kill",
		"condition": null,
		"effect": "Gain gold when killing an enemy",
	},
	
	"hero_bounty_hunter_ally_death_buff": {
		"owner": "Bounty Hunter (Hero)",
		"trigger": "on_ally_death",
		"condition": null,
		"effect": "Gain +1 HP and +1 PWR when an ally dies",
	},
	
	# ==================== ITEM ABILITIES ====================
	
	"item_tier1a_turn_start_heal": {
		"owner": "Koi's Blessing (T1A)",
		"trigger": "on_turn_start",
		"condition": null,
		"effect": "Heal holder for +2 HP at turn start",
	},
	
	"item_tier1b_extra_attack": {
		"owner": "Tiger's Spirit (T1B)",
		"trigger": "on_attack",
		"condition": "COMPOSITE: IS_TURN_INITIATED_ATTACK + TARGET_HP_GREATER_THAN_SELF_HP",
		"effect": "Re-trigger all on_attack abilities, then perform a basic attack",
		"notes": "NON-STACKING: Only executes once per turn. Shockwave/Mirror Strike trigger again!",
	},
	
	"item_tier2b_bloodlust": {
		"owner": "Bloodlust Ring (T2B)",
		"trigger": "on_kill",
		"condition": null,
		"effect": "Grant holder an extra turn action",
	},
	
	"item_tier2c_passive_heal": {
		"owner": "Phoenix Feather (T2C)",
		"trigger": "on_hurt",
		"condition": "DAMAGE_WAS_NON_LETHAL",
		"effect": "Heal holder for +2 HP and +1 PWR when damaged",
	},
	
	"item_tier3a_on_hurt_heal": {
		"owner": "Heart Stone (T3A)",
		"trigger": "on_hurt",
		"condition": null,
		"effect": "Heal 2 random allies for +2 HP when holder takes damage",
	},
	
	"item_tier3b_on_attack_buff": {
		"owner": "Power Amulet (T3B)",
		"trigger": "on_attack",
		"condition": null,
		"effect": "Grant 2 random allies +2 PWR when holder attacks",
		"notes": "Only triggers on turn action attack",
	},
	
	"item_tier3c_on_attack_lifesteal": {
		"owner": "Lifesteal Ring (T3C)",
		"trigger": "on_damage_dealt",
		"condition": null,
		"effect": "Heal holder for damage dealt (lifesteal)",
		"notes": "Triggers on ANY attack damage dealt (including splash)",
	},
	
	"item_tier3d_retaliate_random": {
		"owner": "Retaliation Charm (T3D)",
		"trigger": "on_hurt",
		"condition": "COMPOSITE: DAMAGE_WAS_RECEIVED + TRIGGER_CAUSE=ATTACK",
		"effect": "Attack a random enemy for holder's PWR when holder takes attack damage",
	},
	
	"ability_item_t2_c_summon": {
		"owner": "Phoenix Egg (T2C02)",
		"trigger": "on_death",
		"condition": null,
		"effect": "Summon a Squire when holder dies",
	},
	
	# ==================== TRINKET ABILITIES ====================
	
	"ability_trinket_aegis": {
		"owner": "Aegis Charm (Trinket)",
		"trigger": "on_hurt",
		"condition": null, # Effect internally checks for lethal
		"effect": "Once per turn: prevent lethal damage, set HP to 1",
		"notes": "Effect checks lethal condition internally via EffectPreventLethal",
	},
	
	"ability_trinket_soul_echo": {
		"owner": "Soul Echo (Trinket)",
		"trigger": "on_ally_death",
		"condition": null,
		"effect": "Resurrect the first killed ally (once per battle)",
		"notes": "Effect tracks resurrection state internally",
	},
	
	"ability_trinket_vengeance": {
		"owner": "Vengeance (Trinket)",
		"trigger": "on_ally_death",
		"condition": null,
		"effect": "Grant +1 PWR to a random ally when an ally dies",
	},
	
}

## Get information about an ability
static func get_ability_info(ability_id: StringName) -> Dictionary:
	return ABILITIES.get(String(ability_id), {})

## Get a human-readable description of an ability
static func describe(ability_id: StringName) -> String:
	var info = get_ability_info(ability_id)
	if info.is_empty():
		return "Unknown ability: %s" % ability_id
	
	var trigger = info.get("trigger", "?")
	var effect = info.get("effect", "?")
	var condition = info.get("condition", null)
	
	var desc = "[%s] %s" % [trigger, effect]
	if condition:
		desc += " (if %s)" % condition
	return desc

## Print all abilities for debugging
static func print_all() -> void:
	print("=== ABILITIES REGISTRY ===")
	for ability_id in ABILITIES:
		print("  %s: %s" % [ability_id, describe(ability_id)])
	print("=========================")
