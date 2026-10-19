# res://scripts/Constants.gd
extends Node

# --- Location Container Tags ---
# Conceptual location for items equipped on a unit
const CONTAINER_EQUIPPED_ITEM = &"equipped_item"

const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_BENCH = &"PlayerBench",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_BENCH = &"EnemyBench",
	BATTLE_DISCARD_PILE = &"DiscardPile",
	ENEMY_TRINKETS = &"EnemyTrinkets",
	PLAYER_TRINKETS = &"PlayerTrinkets",
}

# Run State Containers
const CONTAINER_PLAYER_LINEUP = &"PlayerLineup"
const CONTAINER_PLAYER_BENCH = &"PlayerBench"
# Battle State Containers
const CONTAINER_ENEMY_LINEUP = &"EnemyLineup"
const CONTAINER_DISCARD_PILE = &"DiscardPile"
# Temporary/UI Containers
const CONTAINER_REWARDS = &"Rewards"
const CONTAINER_SHOP = &"Shop"

# --- Combat & Damage ---
enum DamageType {
	MELEE,    # Mitigated by Armor, Triggers Spikes, Triggers on_hurt, Triggers on_damage_dealt
	RANGED,   # Mitigated by Armor, NO Spikes, Triggers on_hurt, Triggers on_damage_dealt
	TRINKET,  # Mitigated by Armor, NO Spikes, Triggers self/ally on_hurt, NO counter-attacks, NO on_damage_dealt
	KAMIKAZE, # Mitigated by Armor, NO Spikes, Triggers self/ally on_hurt, NO targeted retaliation, NO on_damage_dealt
	BURN,     # NO Armor, NO Spikes, NO on_hurt, NO on_damage_dealt
	SPIKES,   # Mitigated by Armor, NO Spikes, NO on_hurt, NO on_damage_dealt
	STATIC    # Mitigated by Armor, NO Spikes, NO on_hurt, NO on_damage_dealt
}

# --- Semantic Action Types ---
const ACTION_DAMAGE = &"DAMAGE"
const ACTION_DEBUFF = &"DEBUFF"
const ACTION_HEAL = &"HEAL"
const ACTION_BUFF = &"BUFF"

# --- Entity & Category Types ---
const CATEGORY_UNIT = &"UNIT"
const CATEGORY_ITEM = &"ITEM"
const CATEGORY_CONSUMABLE = &"CONSUMABLE"
const ENTITY_TYPE_EMPTY_SLOT = &"EMPTY_SLOT"
const ENTITY_TYPE_WINDOW_BACKGROUND = &"WINDOW_BACKGROUND"
const ENTITY_TYPE_GLOBAL_BACKGROUND = &"GLOBAL_BACKGROUND"
const ENTITY_TYPE_UI_LINK = &"UI_LINK"

# --- Interaction System (GIR) ---
# Interaction Modes
const INTERACTION_FULLY_INTERACTIVE = &"FULLY_INTERACTIVE"
const INTERACTION_SELECTION_ONLY = &"SELECTION_ONLY"
const INTERACTION_INSPECTION_ONLY = &"INSPECTION_ONLY"
# Event Types
const EVENT_SINGLE_CLICK = &"SINGLE_CLICK"
const EVENT_DOUBLE_CLICK = &"DOUBLE_CLICK"
const EVENT_DROP = &"DROP"
const EVENT_DRAG_ORIGIN = &"DRAG_ORIGIN"
# Functional Context Groups
const GROUP_BATTLE_BOARD = &"BattleBoard"
const GROUP_INVENTORY_GRID = &"InventoryGrid"
const GROUP_EQUIPPED_GRID = &"EquippedGrid"
const GROUP_SELECTION_ONLY = &"SelectionOnly"
const GROUP_INSPECTION_ONLY = &"InspectionOnly"

# --- Ability System Triggers (Unified) ---
# Attack-related triggers
const TRIGGER_ON_ATTACK = &"on_attack" # Unit performs any attack (use conditions to filter CAUSE)
const TRIGGER_ON_BEFORE_DAMAGE = &"on_before_damage" # Before receiving attack damage (Defensive Stance)
const TRIGGER_ON_HURT = &"on_hurt" # After receiving attack damage
const TRIGGER_ON_DAMAGE_DEALT = &"on_damage_dealt" # After dealing attack damage (Lifesteal)
const TRIGGER_ON_PRE_COMBAT = &"on_pre_combat" # Before combat snapshot (Tier 2 Unit)

# Death-related triggers
const TRIGGER_ON_DEATH = &"on_death" # This unit dies
const TRIGGER_ON_ALLY_DEATH = &"on_ally_death" # A teammate dies
const TRIGGER_ON_KILL = &"on_kill" # This unit kills an enemy
const TRIGGER_ON_UNIT_DEATH = &"on_unit_death" # Any unit in the battle dies

# Turn-related triggers
const TRIGGER_ON_TURN_START = &"on_turn_start" # Turn begins
const TRIGGER_ON_TURN_END = &"on_turn_end" # Turn ends
const TRIGGER_ON_BATTLE_START = &"on_battle_start" # Battle begins

# Special triggers
const TRIGGER_PASSIVE_INTERCEPT = &"passive_intercept" # BattleManager-handled passive (Guardian)
const TRIGGER_ON_ENEMY_SUMMON = &"on_enemy_summon" # When an enemy unit is summoned
const TRIGGER_ON_ALLY_SUMMON = &"on_ally_summon" # When an ally unit is summoned
const TRIGGER_ON_BOARD_ENTER = &"on_board_enter" # When this specific unit enters the board (drawn, summoned, merged, or battle start)
const TRIGGER_ON_DRAW = &"on_draw" # Unit/Item drawn from gacha (management phase)
const TRIGGER_ON_TOKEN_SPENT = &"on_token_spent" # When tokens are spent on a gacha draw (fires per token)
const TRIGGER_ON_MERGE = &"on_merge" # Any merge completed on the battle board (lineup/bench, unit/item)
const TRIGGER_ON_ALLY_HURT = &"on_ally_hurt" # Another ally on the same team receives damage (reactive trigger)
const TRIGGER_ON_HEALED = &"on_healed" # This unit's HP increased by a Heal action
const TRIGGER_ON_STAT_INCREASED = &"on_stat_increased" # This unit's HP or PWR increased by a Buff action
const TRIGGER_ON_STAT_DECREASED = &"on_stat_decreased" # This unit's HP or PWR decreased by a Debuff action

# --- Ability System Target Types ---
const TARGET_SELF = &"SELF"
const TARGET_HOLDER = &"HOLDER"
const TARGET_ATTACK_TARGET = &"ATTACK_TARGET"
const TARGET_TRIGGERING_ENTITY = &"TRIGGERING_ENTITY"
const TARGET_ATTACKER = &"ATTACKER"
const TARGET_FRONTMOST_ENEMY = &"FRONTMOST_ENEMY"
const TARGET_RANDOM_ENEMY = &"RANDOM_ENEMY"
const TARGET_RANDOM_ALLY = &"RANDOM_ALLY"
const TARGET_ALLY_BEHIND = &"ALLY_BEHIND"
const TARGET_ALLY_SLOT_AHEAD = &"ALLY_SLOT_AHEAD"
const TARGET_ADJACENT_ALLIES = &"ADJACENT_ALLIES"
const TARGET_ALL_ALLIES = &"ALL_ALLIES"
const TARGET_ALLIES_IN_FRONT = &"ALLIES_IN_FRONT"
const TARGET_ALLIES_BEHIND = &"ALLIES_BEHIND"
const TARGET_HIGHEST_HP_ENEMY = &"HIGHEST_HP_ENEMY"

# --- Ability System Condition Types ---
const COND_TEAM_SIZE_LESS_THAN_ENEMY = &"TEAM_SIZE_LESS_THAN_ENEMY"
const COND_SLOT_AHEAD_IS_EMPTY = &"SLOT_AHEAD_IS_EMPTY"
const COND_TARGET_HP_GREATER_THAN_SELF_HP = &"TARGET_HP_GREATER_THAN_SELF_HP"
const COND_DAMAGE_WAS_NON_LETHAL = &"DAMAGE_WAS_NON_LETHAL"
const COND_DAMAGE_WAS_RECEIVED = &"DAMAGE_WAS_RECEIVED"
const COND_IS_TURN_INITIATED_ATTACK = &"IS_TURN_INITIATED_ATTACK"
const COND_COMPOSITE = &"COMPOSITE"
const COND_TRIGGER_CAUSE_MATCH = &"TRIGGER_CAUSE_MATCH"
const COND_DYING_UNIT_IS_DUST = &"DYING_UNIT_IS_DUST"

# --- Trigger Context Causes ---
# Who/What initiated the event chain?
const CAUSE_TURN = &"CAUSE_TURN" # The game loop (e.g. Turn Start attack)
const CAUSE_ABILITY = &"CAUSE_ABILITY" # An ability effect (e.g. Extra Attack, Retaliation)
const CAUSE_ATTACK = &"CAUSE_ATTACK" # Direct result of an attack (e.g. Combat Damage)
const CAUSE_STATUS_EFFECT = &"CAUSE_STATUS" # Passive effect (e.g. Poison damage)
const CAUSE_TRINKET = &"CAUSE_TRINKET" # Direct damage originating from a Trinket
const CAUSE_KAMIKAZE = &"CAUSE_KAMIKAZE" # Sacrifice attack without active attacker (e.g. Death's Bargain)
const CAUSE_COST = &"CAUSE_COST" # Self-inflicted cost (e.g. Sacrifice HP)
const CAUSE_GAME_OVER = &"CAUSE_GAME_OVER" # Cleanup phase
const CAUSE_SETUP = &"CAUSE_SETUP" # Battle initialization
const CAUSE_REPLACEMENT = &"CAUSE_REPLACEMENT" # Unit being replaced by summon

const PRIORITY_EXTRA_ACTION = -100
const PRIORITY_TRAIT_START_EFFECTS = -10
const PRIORITY_TRAIT_BURN = 100 # Trait burn application

# --- UI Sizing ---
const SLOT_SIZE_BASE: int = 96
const SLOT_SIZE_2X: int = 192
const UNIT_SPRITE_SIZE: int = 128
const SLOT_CENTER_OFFSET: int = 32 # (192-128)/2
const PLAYER_TRINKET_CAP: int = 20
const ENEMY_TRINKET_CAP: int = 5

# --- Ability System Priority Bands ---
# Priority determines the resolution order of abilities triggering simultaneously.
# Higher numbers resolve first.
# 
# [300] GUARDIAN_INTERCEPT: Must resolve before damage is dealt to the original target.
# [210] TRINKET_SUMMON: E.g., Soul Echo resurrection. Resolves before on-death spawns.
# [100] RESILIENT_AURA: Defensive reactions. Resolves before retaliation.
#  [50] COUNTER_ATTACK: Retaliation logic. Resolves before standard effects.
#  [10] MODIFIERS: Minor timing tweaks (e.g., Defensive Stance before Standard).
#   [0] STANDARD: The default for 90% of abilities (damage, heal, buff).
# [-50] BOSS_SUMMON: E.g., Necromancer skeleton. Resolves after standard deaths.
#[-100] EXTRA_ACTION: E.g., granting an extra turn. Must be lowest priority.

const PRIORITY_GUARDIAN_INTERCEPT = 300
const PRIORITY_ITEM_TRANSFER = 220
const PRIORITY_DEATH_DAMAGE = 215
const PRIORITY_TRINKET_SUMMON = 210
const PRIORITY_UNIT_SUMMON = 205
const PRIORITY_ITEM_SUMMON = 200
const PRIORITY_RESILIENT_AURA = 100
const PRIORITY_ON_HURT_HEAL = 100
const PRIORITY_ON_ATTACK_BUFF = 100
const PRIORITY_AMBUSH_PREDATOR = 100
const PRIORITY_SUMMON_BLESSING = 110 # Higher than Ambush Predator so ally buff applies first
const PRIORITY_COUNTER_ATTACK = 50
const PRIORITY_MODIFIERS = 10
const PRIORITY_DEFENSIVE_STANCE = 10
const PRIORITY_SHOCKWAVE = 10
const PRIORITY_MIRROR_STRIKE = 10
const PRIORITY_STANDARD = 0
const PRIORITY_LIFESTEAL = 0
const PRIORITY_TURN_START_HEAL = 0
const PRIORITY_PASSIVE_HEAL = 0
const PRIORITY_ALLY_DEATH_BUFF = 0
const PRIORITY_BOSS_SUMMON = -50


# --- Window Types (for WindowManager) ---
const WINDOW_INVENTORY = &"Inventory"
const WINDOW_DISCARD_PILE = &"DiscardPile"
const WINDOW_CHOICE = &"ChoiceWindow"
const WINDOW_UNIT_INSPECTION = &"UnitInspection"
const WINDOW_ITEM_INSPECTION = &"ItemInspection"
const WINDOW_TRAIT_INSPECTION = &"TraitInspection" # NEW
const WINDOW_EFFECT_INSPECTION = &"EffectInspection"
const WINDOW_END_BATTLE = &"EndBattlePopup"
const WINDOW_FLASHCARD = &"FlashcardMinigame"
const WINDOW_RESULTS = &"ResultsPopup"

const TRAIT_SORT_ORDER: Array[String] = [
	"FIRE", "EARTH", "WATER", "AIR",
	"TANK", "FIGHTER", "SUPPORT", "SPECIALIST",
	"FOOD", "MECHA", "ANIMAL", "PLANT", "TOY", "APPLIANCE", "COSTUME"
]

const CLASS_TRAITS: Array[StringName] = [&"Tank", &"Fighter", &"Support", &"Specialist"]
const VISUAL_TRAITS: Array[StringName] = [&"Food", &"Mecha", &"Animal", &"Plant", &"Toy", &"Appliance", &"Costume"]

# --- Trait Definitions ---
const TRAIT_DEFINITIONS = {
	"FIRE": {
		"display_name_key": "trait.fire.name",
		"trinket_id": &"trinket_trait_fire",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Fire.png",
		"levels": [
			{"min": 3, "desc_key": "trait.fire.3"},
			{"min": 6, "desc_key": "trait.fire.6"},
			{"min": 12, "desc_key": "trait.fire.12"},
			{"min": 20, "desc_key": "trait.fire.20"},
			{"min": 32, "desc_key": "trait.fire.32"}
		]
	},
	"EARTH": {
		"display_name_key": "trait.earth.name",
		"trinket_id": &"trinket_trait_earth",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Earth.png",
		"levels": [
			{"min": 3, "desc_key": "trait.earth.3"},
			{"min": 6, "desc_key": "trait.earth.6"},
			{"min": 12, "desc_key": "trait.earth.12"},
			{"min": 20, "desc_key": "trait.earth.20"},
			{"min": 32, "desc_key": "trait.earth.32"}
		]
	},
	"WATER": {
		"display_name_key": "trait.water.name",
		"trinket_id": &"trinket_trait_water",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Water.png",
		"levels": [
			{"min": 3, "desc_key": "trait.water.3"},
			{"min": 6, "desc_key": "trait.water.6"},
			{"min": 12, "desc_key": "trait.water.12"},
			{"min": 20, "desc_key": "trait.water.20"},
			{"min": 32, "desc_key": "trait.water.32"}
		]
	},
	"AIR": {
		"display_name_key": "trait.air.name",
		"trinket_id": &"trinket_trait_air",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Air.png",
		"levels": [
			{"min": 3, "desc_key": "trait.air.3"},
			{"min": 6, "desc_key": "trait.air.6"},
			{"min": 12, "desc_key": "trait.air.12"},
			{"min": 20, "desc_key": "trait.air.20"},
			{"min": 32, "desc_key": "trait.air.32"}
		]
	},
	"TANK": {
		"display_name_key": "trait.tank.name",
		"trinket_id": &"trinket_trait_tank",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Tank.png",
		"levels": [
			{"min": 2, "desc_key": "trait.tank.2"},
			{"min": 3, "desc_key": "trait.tank.3"},
			{"min": 4, "desc_key": "trait.tank.4"},
			{"min": 5, "desc_key": "trait.tank.5"}
		]
	},
	"FIGHTER": {
		"display_name_key": "trait.fighter.name",
		"trinket_id": &"trinket_trait_fighter",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Fighter.png",
		"levels": [
			{"min": 2, "desc_key": "trait.fighter.2"},
			{"min": 3, "desc_key": "trait.fighter.3"},
			{"min": 4, "desc_key": "trait.fighter.4"},
			{"min": 5, "desc_key": "trait.fighter.5"}
		]
	},
	"SUPPORT": {
		"display_name_key": "trait.support.name",
		"trinket_id": &"trinket_trait_support",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Support.png",
		"levels": [
			{"min": 2, "desc_key": "trait.support.2"},
			{"min": 3, "desc_key": "trait.support.3"},
			{"min": 4, "desc_key": "trait.support.4"},
			{"min": 5, "desc_key": "trait.support.5"}
		]
	},
	"SPECIALIST": {
		"display_name_key": "trait.specialist.name",
		"trinket_id": &"trinket_trait_specialist",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Specialist.png",
		"levels": [
			{"min": 2, "desc_key": "trait.specialist.2"},
			{"min": 3, "desc_key": "trait.specialist.3"},
			{"min": 4, "desc_key": "trait.specialist.4"},
			{"min": 5, "desc_key": "trait.specialist.5"}
		]
	},
	"FOOD": {
		"display_name_key": "trait.food.name",
		"trinket_id": &"trinket_trait_food",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Food.png",
		"levels": [
			{"min": 2, "desc_key": "trait.food.2"},
			{"min": 3, "desc_key": "trait.food.3"},
			{"min": 4, "desc_key": "trait.food.4"},
			{"min": 5, "desc_key": "trait.food.5"}
		]
	},
	"MECHA": {
		"display_name_key": "trait.mecha.name",
		"trinket_id": &"trinket_trait_mecha",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Mecha.png",
		"levels": [
			{"min": 2, "desc_key": "trait.mecha.2"},
			{"min": 3, "desc_key": "trait.mecha.3"},
			{"min": 4, "desc_key": "trait.mecha.4"},
			{"min": 5, "desc_key": "trait.mecha.5"}
		]
	},
	"ANIMAL": {
		"display_name_key": "trait.animal.name",
		"trinket_id": &"trinket_trait_animal",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Animal.png",
		"levels": [
			{"min": 2, "desc_key": "trait.animal.2"},
			{"min": 3, "desc_key": "trait.animal.3"},
			{"min": 4, "desc_key": "trait.animal.4"},
			{"min": 5, "desc_key": "trait.animal.5"}
		]
	},
	"PLANT": {
		"display_name_key": "trait.plant.name",
		"trinket_id": &"trinket_trait_plant",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Plant.png",
		"levels": [
			{"min": 2, "desc_key": "trait.plant.2"},
			{"min": 3, "desc_key": "trait.plant.3"},
			{"min": 4, "desc_key": "trait.plant.4"},
			{"min": 5, "desc_key": "trait.plant.5"}
		]
	},
	"TOY": {
		"display_name_key": "trait.toy.name",
		"trinket_id": &"trinket_trait_toy",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Toy.png",
		"levels": [
			{"min": 2, "desc_key": "trait.toy.2"},
			{"min": 3, "desc_key": "trait.toy.3"},
			{"min": 4, "desc_key": "trait.toy.4"},
			{"min": 5, "desc_key": "trait.toy.5"}
		]
	},
	"APPLIANCE": {
		"display_name_key": "trait.appliance.name",
		"trinket_id": &"trinket_trait_appliance",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Appliance.png",
		"levels": [
			{"min": 2, "desc_key": "trait.appliance.2"},
			{"min": 3, "desc_key": "trait.appliance.3"},
			{"min": 4, "desc_key": "trait.appliance.4"},
			{"min": 5, "desc_key": "trait.appliance.5"}
		]
	},
	"COSTUME": {
		"display_name_key": "trait.costume.name",
		"trinket_id": &"trinket_trait_costume",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/Trait_Costume.png",
		"levels": [
			{"min": 2, "desc_key": "trait.costume.2"},
			{"min": 3, "desc_key": "trait.costume.3"},
			{"min": 4, "desc_key": "trait.costume.4"},
			{"min": 5, "desc_key": "trait.costume.5"}
		]
	}
}

