@tool
class_name InteractionContext extends Resource

## The instance ID of the specific node that was clicked (for robust reference handling)
@export var source_view_instance_id: int

## The type of input event ("SINGLE_CLICK", "DOUBLE_CLICK")
@export var event_type: StringName

## The game-logic location of the entity
@export var location: LocationIdentifier

## The UUID of the GachaBallInstance represented, if any
@export var entity_uuid: String

## The kind of thing clicked ("UNIT", "ITEM", "EMPTY_SLOT", "WINDOW_BACKGROUND", "UI_LINK", "GLOBAL_BACKGROUND")
@export var entity_type: StringName

## The TDD-defined interaction rules for this context ("FULLY_INTERACTIVE", "SELECTION_ONLY", "INSPECTION_ONLY")
@export var interaction_mode: StringName

## A unique ID for the chain of inspection windows this element belongs to (0 if on the main board)
@export var window_group_id: int = 0 