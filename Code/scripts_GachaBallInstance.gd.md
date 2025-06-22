<!-- Original: scripts/GachaBallInstance.gd -->

```gdscript
# res://scripts/GachaBallInstance.gd
class_name GachaBallInstance
extends Resource

## A unique, individual instance of a GachaBall.

## The ID of the GachaBallDefinition this instance is based on.
var definition_id: StringName

## A universally unique identifier for this specific instance.
var ball_uuid: String

## The UUID of the permanent instance this battle copy was created from.
## Remains an empty string for permanent instances in the RunInventory.
var origin_uuid: String = ""

## An array of UUIDs for the items equipped in this instance's slots.
var equipped_item_uuids: Array[String]

## Current location of this instance.
var location_state: int = LocationState.UNDEFINED

## Location states for the instance
enum LocationState {
    UNDEFINED = -1,
    RUN_INVENTORY = 0,
    IN_BATTLE_INVENTORY = 1,
    BATTLE_BOARD = 2,
    IN_BATTLE_DISCARD_PILE = 3,
    MERGE_PREVIEW = 4,
    INSPECT_VIEW = 5,
    IN_PLAYER_BENCH = 6,
    IN_PLAYER_LINEUP = 7
}

## Sets up the instance based on a GachaBallDefinition.
## This must be called immediately after creating a new instance.
func initialize(definition: GachaBallDefinition):
    if not definition:
        printerr("GachaBallInstance.initialize() was called with a null definition.")
        return

    self.definition_id = definition.id
    # The UUIDUtils autoload is required for this to work.
    self.ball_uuid = UUIDUtils.generate_uuid(definition.id)
    self.location_state = LocationState.RUN_INVENTORY
    
    # Resize the item array to match the definition and fill with empty strings.
    equipped_item_uuids.resize(definition.item_slot_count)
    for i in range(equipped_item_uuids.size()):
        equipped_item_uuids[i] = ""

## Creates a temporary, deep copy of this instance for a battle session.
func create_battle_copy() -> GachaBallInstance:
    var copy = self.duplicate(true) as GachaBallInstance
    
    # Generate a new, unique UUID for the battle copy.
    copy.ball_uuid = UUIDUtils.generate_uuid(self.definition_id)
    
    # Link the copy back to its permanent origin.
    copy.origin_uuid = self.ball_uuid
    
    # Set the initial battle state.
    copy.location_state = LocationState.IN_BATTLE_INVENTORY
    
    return copy

```