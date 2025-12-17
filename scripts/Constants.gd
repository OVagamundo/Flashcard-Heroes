# res://scripts/Constants.gd
extends Node

# --- Location Container Tags ---
# Conceptual location for items equipped on a unit
const CONTAINER_EQUIPPED_ITEM = &"equipped_item"
# Run State Containers
const CONTAINER_PLAYER_LINEUP = &"PlayerLineup"
const CONTAINER_PLAYER_BENCH = &"PlayerBench"
const CONTAINER_ITEM_INVENTORY = &"ItemInventory"
# Battle State Containers
const CONTAINER_ENEMY_LINEUP = &"EnemyLineup"
const CONTAINER_DISCARD_PILE = &"DiscardPile"
# Temporary/UI Containers
const CONTAINER_REWARDS = &"Rewards"
const CONTAINER_SHOP = &"Shop"

# --- Entity & Category Types ---
const CATEGORY_UNIT = &"UNIT"
const CATEGORY_ITEM = &"ITEM"
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

# Death-related triggers
const TRIGGER_ON_DEATH = &"on_death" # This unit dies
const TRIGGER_ON_ALLY_DEATH = &"on_ally_death" # A teammate dies
const TRIGGER_ON_KILL = &"on_kill" # This unit kills an enemy

# Turn-related triggers
const TRIGGER_ON_TURN_START = &"on_turn_start" # Turn begins
const TRIGGER_ON_TURN_END = &"on_turn_end" # Turn ends
const TRIGGER_ON_BATTLE_START = &"on_battle_start" # Battle begins

# Special triggers
const TRIGGER_PASSIVE_INTERCEPT = &"passive_intercept" # BattleManager-handled passive (Guardian)

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

# --- Ability System Condition Types ---
const COND_TEAM_SIZE_LESS_THAN_ENEMY = &"TEAM_SIZE_LESS_THAN_ENEMY"
const COND_SLOT_AHEAD_IS_EMPTY = &"SLOT_AHEAD_IS_EMPTY"
const COND_TARGET_HP_GREATER_THAN_SELF_HP = &"TARGET_HP_GREATER_THAN_SELF_HP"
const COND_DAMAGE_WAS_NON_LETHAL = &"DAMAGE_WAS_NON_LETHAL"
const COND_DAMAGE_WAS_RECEIVED = &"DAMAGE_WAS_RECEIVED"
const COND_IS_TURN_INITIATED_ATTACK = &"IS_TURN_INITIATED_ATTACK"
const COND_COMPOSITE = &"COMPOSITE"
const COND_TRIGGER_CAUSE_MATCH = &"TRIGGER_CAUSE_MATCH"

# --- Trigger Context Causes ---
# Who/What initiated the event chain?
const CAUSE_TURN = &"CAUSE_TURN" # The game loop (e.g. Turn Start attack)
const CAUSE_ABILITY = &"CAUSE_ABILITY" # An ability effect (e.g. Extra Attack, Retaliation)
const CAUSE_ATTACK = &"CAUSE_ATTACK" # Direct result of an attack (e.g. Combat Damage)
const CAUSE_STATUS_EFFECT = &"CAUSE_STATUS" # Passive effect (e.g. Poison damage)
const CAUSE_COST = &"CAUSE_COST" # Self-inflicted cost (e.g. Sacrifice HP)
const CAUSE_GAME_OVER = &"CAUSE_GAME_OVER" # Cleanup phase
const CAUSE_SETUP = &"CAUSE_SETUP" # Battle initialization
const CAUSE_REPLACEMENT = &"CAUSE_REPLACEMENT" # Unit being replaced by summon

# --- Window Types (for WindowManager) ---
const WINDOW_INVENTORY = &"Inventory"
const WINDOW_DISCARD_PILE = &"DiscardPile"
const WINDOW_CHOICE = &"ChoiceWindow"
const WINDOW_UNIT_INSPECTION = &"UnitInspection"
const WINDOW_ITEM_INSPECTION = &"ItemInspection"
const WINDOW_EFFECT_INSPECTION = &"EffectInspection"
const WINDOW_END_BATTLE = &"EndBattlePopup"
const WINDOW_FLASHCARD = &"FlashcardMinigame"
const WINDOW_RESULTS = &"ResultsPopup"
