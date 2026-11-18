# res://scripts/Constants.gd
extends Node

# --- Location Container Tags ---
# Conceptual location for items equipped on a unit
const CONTAINER_EQUIPPED_ITEM = &"equipped_item"

const BATTLE_CONTAINER_TAGS = {
	PLAYER_LINEUP = &"PlayerLineup",
	PLAYER_SHELF = &"PlayerShelf",
	ENEMY_LINEUP = &"EnemyLineup",
	ENEMY_SHELF = &"EnemyShelf",
	BATTLE_DISCARD_PILE = &"DiscardPile",
	ENEMY_GRAVEYARD = &"EnemyGraveyard",
	ENEMY_TRINKETS = &"EnemyTrinkets",
	ENEMY_BANNER = &"EnemyBanner",
	PLAYER_TRINKETS = &"PlayerTrinkets",
}

# Run State Containers
const CONTAINER_PLAYER_LINEUP = &"PlayerLineup"
const CONTAINER_PLAYER_SHELF = &"PlayerShelf"
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

# --- Buff Subgroups (Glossary Taxonomy) ---
const BUFF_SUBGROUP_DISCRETE: StringName = &"DISCRETE"
const BUFF_SUBGROUP_CONDITIONAL: StringName = &"CONDITIONAL"
const BUFF_SUBGROUP_PERMANENT: StringName = &"PERMANENT"

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

# --- Canonical Constitutional Triggers (Action Constitution v1.0) ---
const TRIGGER_WHEN_KNOCKED_OUT: StringName = &"when_knocked_out"
const TRIGGER_WHEN_ALLY_KNOCKED_OUT: StringName = &"when_ally_knocked_out"
const TRIGGER_WHEN_ANY_UNIT_KNOCKED_OUT: StringName = &"when_any_unit_knocked_out"
const TRIGGER_BEFORE_BEING_KNOCKED_OUT: StringName = &"before_being_knocked_out"
const TRIGGER_PREVENT_KNOCKOUT: StringName = &"prevent_knockout"
const TRIGGER_ON_KNOCKOUT_BLOW: StringName = &"on_knockout_blow"

const TRIGGER_WHEN_ATTACKING: StringName = &"when_attacking"
const TRIGGER_ON_ATTACK_IMPACT: StringName = &"on_attack_impact"
const TRIGGER_BEFORE_TAKING_DAMAGE: StringName = &"before_taking_damage"
const TRIGGER_WHEN_TAKING_DAMAGE: StringName = &"when_taking_damage"
const TRIGGER_WHEN_TAKING_MELEE_DAMAGE: StringName = &"when_taking_melee_damage"
const TRIGGER_WHEN_TAKING_RANGED_DAMAGE: StringName = &"when_taking_ranged_damage"
const TRIGGER_WHEN_TAKING_STATUS_DAMAGE: StringName = &"when_taking_status_damage"
const TRIGGER_ON_DAMAGE_DEALT: StringName = &"on_damage_dealt"
const TRIGGER_WHEN_ALLY_TAKES_DAMAGE: StringName = &"when_ally_takes_damage"
const TRIGGER_INTERCEPT_ATTACK: StringName = &"intercept_attack"
const TRIGGER_BEFORE_TURN_ACTION: StringName = &"before_turn_action"

const TRIGGER_AT_BATTLE_START: StringName = &"at_battle_start"
const TRIGGER_BEFORE_MINIGAME: StringName = &"before_minigame"
const TRIGGER_AT_MINIGAME_END: StringName = &"at_minigame_end"
const TRIGGER_PRE_COMBAT: StringName = &"pre_combat"
const TRIGGER_AT_TURN_START: StringName = &"at_turn_start"
const TRIGGER_AT_TURN_END: StringName = &"at_turn_end"

const TRIGGER_WHEN_ALLY_SUMMONED: StringName = &"when_ally_summoned"
const TRIGGER_WHEN_ENEMY_SUMMONED: StringName = &"when_enemy_summoned"
const TRIGGER_ON_ENTER_BOARD: StringName = &"on_enter_board"
const TRIGGER_ON_BOARD_STATE_CHANGED: StringName = &"on_board_state_changed"

const TRIGGER_ON_GACHA_DRAW: StringName = &"on_gacha_draw"
const TRIGGER_ON_MERGE: StringName = &"on_merge"
const TRIGGER_WHEN_DUST_MINIONS_MERGE: StringName = &"when_dust_minions_merge"
const TRIGGER_ON_TOKEN_SPENT: StringName = &"on_token_spent"
const TRIGGER_ON_GACHA_TOKENS_CHANGED: StringName = &"on_gacha_tokens_changed"
const TRIGGER_ON_GOLD_EARNED: StringName = &"on_gold_earned"
const TRIGGER_ON_GOLD_SPENT: StringName = &"on_gold_spent"
const TRIGGER_ON_BOUNTY_CLAIMED: StringName = &"on_bounty_claimed"

const TRIGGER_WHEN_HEALED: StringName = &"when_healed"
const TRIGGER_ON_STAT_INCREASED: StringName = &"on_stat_increased"
const TRIGGER_ON_STAT_DECREASED: StringName = &"on_stat_decreased"

# --- Canonical Causes & Conditions ---
const CAUSE_PRE_KNOCKOUT_ATTACK: StringName = &"CAUSE_PRE_KNOCKOUT_ATTACK"
const CAUSE_ABILITY_RETRIGGER: StringName = &"CAUSE_ABILITY_RETRIGGER"
const COND_KNOCKED_OUT_UNIT_IS_DUST: StringName = &"KNOCKED_OUT_UNIT_IS_DUST"
const COND_DAMAGE_DID_NOT_KNOCK_OUT: StringName = &"DAMAGE_DID_NOT_KNOCK_OUT"

# --- Ability System Target Types ---
const TARGET_SELF = &"SELF"
const TARGET_HOLDER = &"HOLDER"
const TARGET_ATTACK_TARGET = &"ATTACK_TARGET"
const TARGET_TRIGGERING_ENTITY = &"TRIGGERING_ENTITY"
const TARGET_ATTACKER = &"ATTACKER"
const TARGET_FRONTMOST_ENEMY = &"FRONTMOST_ENEMY"
const TARGET_RANDOM_ENEMY = &"RANDOM_ENEMY"
const TARGET_RANDOM_ALLY = &"RANDOM_ALLY"
const TARGET_LOWEST_HP_ALLY = &"LOWEST_HP_ALLY"
const TARGET_RANDOM_UNMARKED_ENEMY = &"RANDOM_UNMARKED_ENEMY"
const TARGET_HERO_ALLY = &"HERO_ALLY"
const TARGET_ALLY_BEHIND = &"ALLY_BEHIND"
const TARGET_ALLY_SLOT_AHEAD = &"ALLY_SLOT_AHEAD"
const TARGET_ADJACENT_ALLIES = &"ADJACENT_ALLIES"
const TARGET_ALL_ALLIES = &"ALL_ALLIES"
const TARGET_ALLIES_IN_FRONT = &"ALLIES_IN_FRONT"
const TARGET_ALLIES_BEHIND = &"ALLIES_BEHIND"
const TARGET_ALLY_DIRECTLY_IN_FRONT = &"ALLY_DIRECTLY_IN_FRONT"
const TARGET_ALL_BOUNTIED_ENEMIES = &"ALL_BOUNTIED_ENEMIES"
const TARGET_HIGHEST_HP_ENEMY = &"HIGHEST_HP_ENEMY"
const TARGET_ATTACK_TARGET_AND_RANDOM_UNMARKED = &"ATTACK_TARGET_AND_RANDOM_UNMARKED"
const TARGET_ATTACK_TARGET_AND_ONE_ADJACENT = &"ATTACK_TARGET_AND_ONE_ADJACENT"
const TARGET_ATTACK_TARGET_AND_ADJACENT = &"ATTACK_TARGET_AND_ADJACENT"

# --- Ability System Condition Types ---
const COND_TEAM_SIZE_LESS_THAN_ENEMY = &"TEAM_SIZE_LESS_THAN_ENEMY"
const COND_SLOT_AHEAD_IS_EMPTY = &"SLOT_AHEAD_IS_EMPTY"
const COND_TARGET_HP_GREATER_THAN_SELF_HP = &"TARGET_HP_GREATER_THAN_SELF_HP"
const COND_DAMAGE_WAS_RECEIVED = &"DAMAGE_WAS_RECEIVED"
const COND_IS_TURN_INITIATED_ATTACK = &"IS_TURN_INITIATED_ATTACK"
const COND_COMPOSITE = &"COMPOSITE"
const COND_TRIGGER_CAUSE_MATCH = &"TRIGGER_CAUSE_MATCH"
const COND_MIN_TRAIT_COUNT = &"MIN_TRAIT_COUNT"
const COND_MIN_GOLD = &"MIN_GOLD"

# --- Trigger Context Causes ---
# Who/What initiated the event chain?
const CAUSE_TURN = &"CAUSE_TURN" # The game loop (e.g. Turn Start attack)
const CAUSE_ABILITY = &"CAUSE_ABILITY" # An ability effect (e.g. Extra Attack, Retaliation)
const CAUSE_ATTACK = &"CAUSE_ATTACK" # Direct result of an attack (e.g. Combat Damage)
const CAUSE_STATUS_EFFECT = &"CAUSE_STATUS" # Passive effect (e.g. Poison damage)
const CAUSE_TRINKET = &"CAUSE_TRINKET" # Direct damage originating from a Trinket
const CAUSE_COST = &"CAUSE_COST" # Self-inflicted cost (e.g. Sacrifice HP)
const CAUSE_GAME_OVER = &"CAUSE_GAME_OVER" # Cleanup phase
const CAUSE_SETUP = &"CAUSE_SETUP" # Battle initialization
const CAUSE_REPLACEMENT = &"CAUSE_REPLACEMENT" # Unit being replaced by summon

# --- UI Sizing ---
const SLOT_SIZE_BASE: int = 96
const GACHA_CAPSULE_DIAMETER: int = 96
const SLOT_SIZE_2X: int = 188
const UNIT_SPRITE_SIZE: int = 128
const SLOT_CENTER_OFFSET: int = 30 # (188-128)/2
const SLOT_UNIT_OFFSET_Y: int = 5 # 188 - 55 - 128 = 5: base sits in the middle of platform surface (55px from bottom edge)
const SHELF_SURFACE_Y: int = SLOT_UNIT_OFFSET_Y + UNIT_SPRITE_SIZE
const SHADOW_WIDTH_2X: int = 128 # Scaled 2x to match 128px unit
const SHADOW_HEIGHT_2X: int = 10 # Scaled 2x (native is 5px)
const SHADOW_OFFSET_Y: int = 128 # Vertical center at y = 133 (133 - 10/2 = 128)
const SHADOW_ALPHA: float = 0.5
const PLAYER_TRINKET_CAP: int = 9
const ENEMY_TRINKET_CAP: int = 9
const LINEUP_CAP: int = 5
const SHELF_CAP: int = 8
const PLAYER_SHELF_CAP: int = 8
const INITIAL_SHELF_SLOTS: int = 3
const SHELF_SLOT_TOKEN_COST: int = 1
const RUN_INVENTORY_CAP: int = 25

# --- Reaction Resolution Sub-Phases (Action Constitution Phase 3) ---
# SubPhase determines the execution order of abilities triggering simultaneously.
# Monotonically increasing: LOWER integer values resolve FIRST.
enum SubPhase {
	PRE_TURN_TRANSFORM = 5,
	PRE_DAMAGE_INTERCEPT = 10,
	KNOCKOUT_STAT_PASS = 12,
	PREVENT_KNOCKOUT_CHECK = 15,
	ITEM_TRANSFER = 20,
	PRE_KNOCKOUT = 25,
	KNOCKOUT_SUMMON_TRINKET = 30,
	KNOCKOUT_SUMMON_UNIT = 35,
	KNOCKOUT_SUMMON_ITEM = 40,
	ON_SUMMON_INSIGNIA = 50,
	ON_SUMMON_BLESSING = 55,
	ON_ATTACK_BUFF = 60,
	ON_DAMAGE_TAKEN = 61,
	ON_SUMMON_AMBUSH = 62,
	BOARD_STATE_SYNC = 64,
	ON_MERGE_PRIMARY = 70,
	RETALIATION = 75,
	TRINKET_MODIFIER = 80,
	PRE_DAMAGE_DEFENSE = 90,
	ON_ATTACK_MODIFIER = 95,
	PRE_COMBAT_PRIORITY = 98,
	STANDARD = 200,
	TRAIT_PHASE_EFFECT = 220,
	DOUBLE_STRIKE_FOLLOWUP = 245,
	END_OF_TURN_SUMMON = 250,
	GRANT_EXTRA_ACTION = 300,
}

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
	"TANK", "FIGHTER", "SUPPORT", "SPECIALIST", "MERCENARY", "NOVICE",
	"FOOD", "MECHA", "ANIMAL", "PLANT", "TOY", "APPLIANCE", "COSTUME"
]

const CLASS_TRAITS: Array[StringName] = [&"Tank", &"Fighter", &"Support", &"Specialist", &"Mercenary", &"Novice"]
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
	},
	"MERCENARY": {
		"display_name_key": "trait.mercenary.name",
		"trinket_id": &"trinket_trait_mercenary",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/MercenarySigil.png",
		"levels": [
			{"min": 2, "desc_key": "trait.mercenary.2"},
			{"min": 3, "desc_key": "trait.mercenary.3"},
			{"min": 4, "desc_key": "trait.mercenary.4"},
			{"min": 5, "desc_key": "trait.mercenary.5"}
		]
	},
	"NOVICE": {
		"display_name_key": "trait.novice.name",
		"trinket_id": &"trinket_trait_novice",
		"icon_path": "res://assets/PixelArt/sprites/trinkets/NoviceSigil.png",
		"levels": [
			{"min": 2, "desc_key": "trait.novice.2"},
			{"min": 3, "desc_key": "trait.novice.3"},
			{"min": 4, "desc_key": "trait.novice.4"},
			{"min": 5, "desc_key": "trait.novice.5"}
		]
	}
}

