classDiagram
    direction LR

    class GameManager {
        <<Autoload>>
        +RunInventory: Dictionary
        +battle_setup_data: Dictionary
        +handle_start_run_requested()
        +handle_battle_start_requested()
        +handle_permanent_merge_request(source_uuid, target_uuid)
    }

    class BattleManager {
        <<Node Script>>
        -battle_inventory: Dictionary
        -discard_pile: Array
        -player_lineup_data: Array
        -player_bench_data: Array
        -item_inventory_data: Array
        -uuid_to_instance_map: Dictionary
        +initialize(data: Dictionary)
        +handle_draw_gacha_request(tier)
        +handle_interaction_request(sourceView, targetView)
        +handle_reshuffle_request()
        -_perform_move(sourceView, targetView)
        -_perform_equip(sourceView, targetView)
        -_perform_swap(sourceView, targetView)
        -_perform_merge(sourceView, targetView)
        -_reshuffle_tier_from_discard(tier)
    }

    class InteractionManager {
        <<Autoload>>
        -selected_view: GachaBallView
        +handle_view_interaction(view, event)
        +clear_selection()
        +trigger_invalid_action_feedback(view)
    }

    class SceneManager {
        <<Autoload>>
        +change_scene_to_file(path)
        +load_scene_in_container(path, container)
    }

    class Database {
        <<Autoload>>
        +GachaBallDefinitions: Dictionary
        +MergeRecipes: Dictionary
        +get_gachaball_definition(id): GachaBallDefinition
        +get_merge_recipe(id_a, id_b): MergeRecipe
    }

    class EventBus {
        <<Singleton>>
        +emit_signal(name, ...args)
        +connect(name, callable)
    }

    class GachaBallInstance {
        <<Resource>>
        +definition_id: StringName
        +ball_uuid: String
        +equipped_item_uuids: Array
        +equipped_on_unit_uuid: String
        +initialize(def)
        +create_battle_copy(): GachaBallInstance
    }

    class GachaBallView {
        <<Scene Script>>
        -instance_ref: GachaBallInstance
        +display(instance)
        +handle_gui_input(event)
        +play_feedback_animation(name)
        +set_drag_preview(control)
    }
    class ItemView {
        <<Scene Script>>
    }
    class UnitView {
        <<Scene Script>>
        +update_equipped_items_display()
    }
    GachaBallView <|-- ItemView
    GachaBallView <|-- UnitView

    GameManager --|> EventBus : Emits signals
    BattleManager --|> EventBus : Emits signals
    InteractionManager --|> EventBus : Emits signals
    
    EventBus --|> GameManager : Calls handlers
    EventBus --|> BattleManager : Calls handlers
    EventBus --|> SceneManager : Calls handlers

    BattleManager o-- GachaBallInstance : Manages
    GameManager o-- GachaBallInstance : Owns
    
    BattleManager ..> GachaBallView : Commands UI updates
    InteractionManager ..> GachaBallView : Responds to input from

    GameManager ..> Database : Reads definitions
    BattleManager ..> Database : Reads definitions