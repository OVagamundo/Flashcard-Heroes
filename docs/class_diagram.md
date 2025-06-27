classDiagram
    direction LR

    %% --- 1. Data Layer (Resources) ---
    namespace Data {
        class Resource {
            <<Godot Base Class>>
        }

        class GachaBallDefinition {
            <<Resource>>
            +StringName id
            +String display_name_key
            +Texture2D icon
            +int tier
            +StringName category
            +int item_slot_count
        }

        class GachaBallInstance {
            <<Resource>>
            +StringName definition_id
            +String ball_uuid
            +String origin_uuid
            +Array~String~ equipped_item_uuids
            +int location_state
            +initialize(GachaBallDefinition) void
            +create_battle_copy() GachaBallInstance
        }

        class RunState {
            <<Resource>>
            +int gold
            +Dictionary run_inventory
            +start_new_run() void
        }

        class MergeRecipe {
            <<Resource>>
            +StringName ingredient_a_id
            +StringName ingredient_b_id
            +StringName result_id
        }

        Resource <|-- GachaBallDefinition
        Resource <|-- GachaBallInstance
        Resource <|-- RunState
        Resource <|-- MergeRecipe

        RunState "1" *-- "0..*" GachaBallInstance : run_inventory
        GachaBallInstance --> GachaBallDefinition : definition_id
    }

    %% --- 2. Autoloaded Singletons (Core Systems) ---
    namespace Singletons {
        class EventBus {
            <<Singleton>>
            +signal start_run_requested
            +signal inventory_action_requested
            +...
        }

        class Database {
            <<Singleton>>
            +Dictionary units
            +Dictionary items
            +Dictionary recipes
            +_load_resources_from_path()
        }

        class GameManager {
            <<Singleton>>
            +RunState run_state
            +bool is_inspecting_inventory
            +_on_start_run_requested()
            +_on_inventory_action_requested()
        }

        class MergeManager {
            <<Singleton>>
            +attempt_merge(inst_a, inst_b, inventory_dict) GachaBallInstance
            +find_recipe(id_a, id_b) MergeRecipe
        }

        class InteractionManager {
            <<Singleton>>
            +Control _selected_view
            +select_view(Control) void
            +clear_selection() void
        }
        
        class SceneManager {
            <<Singleton>>
            +_change_scene_to(path) void
        }
        
        class UUIDUtils {
            <<Singleton>>
            +generate_uuid(prefix) String
        }

        GameManager --> RunState : manages
        GameManager ..> EventBus : emits run_inventory_changed
        EventBus ..> GameManager : connects signals
        
        Database --> GachaBallDefinition : loads
        Database --> MergeRecipe : loads
        
        MergeManager ..> Database : uses
        MergeManager ..> GachaBallInstance : operates on
        
        InteractionManager ..> EventBus : emits view_selected
        EventBus ..> InteractionManager : connects signals
        
        SceneManager ..> EventBus : listens for scene changes
    }

    %% --- 3. Scenes and UI Components ---
    namespace Scenes_And_UI {
        class Node { <<Godot Base Class>> }
        class Control { <<Godot Base Class>> }
        class PanelContainer { <<Godot Base Class>> }
        Control <|-- PanelContainer
        Node <|-- Control

        class GachaBallView {
            <<Scene>>
            +GachaBallInstance instance_data
            +set_instance_data(data) void
            +_gui_input(event)
            +_get_drag_data()
        }
        
        class BattleManager {
            <<Script>>
            +Dictionary _battle_inventory
            +Array _discard_pile
            +_setup_battle() void
            +_on_inventory_action_requested()
        }
        
        class Main {
            <<Scene>>
            +_load_content(scene) void
            +_on_battle_start_requested()
        }
        
        class Title {
            <<Scene>>
            +_on_start_run_button_pressed() void
        }
        
        class InspectInventoryView {
            <<Scene>>
            +_populate_grid() void
        }
        
        class DropTarget {
            <<Script>>
            +_can_drop_data() bool
            +_drop_data() void
        }

        PanelContainer <|-- GachaBallView
        PanelContainer <|-- DropTarget

        Title ..> EventBus : emits start_run_requested
        
        Main ..> EventBus : listens for signals
        Main ..> SceneManager : (implicitly via EventBus)
        Main *-- BattleManager : (loads Battle.tscn)
        Main *-- InspectInventoryView : (instantiates as modal)
        
        BattleManager ..> GameManager : uses run_state
        BattleManager ..> MergeManager : uses
        BattleManager "1" *-- "0..*" GachaBallView : instantiates
        
        GachaBallView --> GachaBallInstance : displays
        GachaBallView ..> InteractionManager : uses
        GachaBallView ..> EventBus : emits inventory_action_requested
        
        InspectInventoryView ..> GameManager : uses run_state
        InspectInventoryView "1" *-- "0..*" GachaBallView : instantiates
    }