@tool
class_name EncounterDefinition extends Resource

## Unique identifier for this encounter
@export var id: StringName

## Localization key for the encounter's name
@export var display_name_key: String

## Authoritative banner ID governing this encounter; stored outside enemy trinket slots.
@export var banner_trinket_id: StringName = &""

## Selected Boss or Elite unit ID (empty for Regular encounters)
@export var boss_or_elite_unit_id: StringName = &""

## Calendar day and Daily Budget (B) when this encounter was generated
@export var encounter_day: int = 1
@export var daily_budget: int = 3

## Array of enemy unit placements with format:
## {
##     "id": StringName,              # Unit definition ID
##     "position": int,               # Lineup slot index (0..4)
##     "level": int,                  # Unit level (1, 2, or 3)
##     "items": Array[StringName],    # Equipped item definition IDs (max 1)
##     "bonus_hp": int,               # Extra HP from Stat Overflow or Boss/Elite dynamic scaling
##     "bonus_pwr": int               # Extra PWR from Stat Overflow or Boss/Elite dynamic scaling
## }
@export var enemy_placements: Array[Dictionary] = []

## Default AI behavior for enemies
@export var ai_behavior: StringName

## Battlefield environment/theme
@export var environment: StringName

## Background image for the battle
@export var background: Texture2D

## Music track to play during battle
@export var music_track: StringName

## Whether this is a boss encounter
@export var is_boss: bool = false

## Guaranteed rewards for victory
@export var victory_rewards: Array[RewardDefinition]

## Possible additional rewards
@export var possible_rewards: Array[RewardDefinition]

## Enemy trinket IDs for this encounter (the banner has its own dedicated location).
@export var enemy_trinket_ids: Array[StringName] = []

## Slot effects for player lineup slots (size 5, entries can be &"burn", &"lightning", etc., or empty &"")
@export var player_slot_effects: Array[StringName] = [&"", &"", &"", &"", &""]

## Slot effects for enemy lineup slots (size 5, entries can be &"burn", &"lightning", etc., or empty &"")
@export var enemy_slot_effects: Array[StringName] = [&"", &"", &"", &"", &""]

