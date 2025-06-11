extends Node

# A queue that holds effects waiting to be resolved.
# Each entry is a dictionary: {effect: EffectDefinition, source: GachaBallInstance, target: GachaBallInstance, priority: int}
var effect_queue: Array[Dictionary] = []

# A direct reference to the current BattleManager, set on battle start.
var _battle_manager_ref

signal resolve_queue_completed

func _ready() -> void:
    # Connect to all game event signals that can trigger abilities.
    EventBus.initiate_battle.connect(_on_initiate_battle)
    EventBus.turn_started.connect(func(): _on_game_event("turn_started"))
    EventBus.turn_ended.connect(func(): _on_game_event("turn_ended"))
    EventBus.unit_performed_attack.connect(func(a, t): _on_game_event("unit_performed_attack", {"attacker": a, "target": t}))
    EventBus.unit_took_damage.connect(func(a, d, amt): _on_game_event("unit_took_damage", {"attacker": a, "defender": d, "damage_amount": amt}))
    EventBus.unit_was_merged.connect(func(u): _on_game_event("unit_was_merged", {"unit": u}))
    EventBus.unit_defeated.connect(func(uuid, is_enemy): _on_game_event("unit_defeated", {"uuid": uuid, "is_enemy": is_enemy}))
    EventBus.unit_is_acting.connect(func(unit): _on_game_event("unit_is_acting", {"unit": unit}))

func _on_initiate_battle(battle_setup_data: Dictionary) -> void:
    # This assumes the BattleManager is a child of the BattleScene and is in the 'battle_manager' group.
    var battle_scene = get_tree().get_first_node_in_group("battle_manager")
    if battle_scene:
        _battle_manager_ref = battle_scene
    else:
        print("Error: AbilityResolver could not find BattleManager.")

func _on_game_event(event_type: StringName, event_data: Dictionary = {}) -> void:
    if not _battle_manager_ref:
        return

    # Placeholder for the complex logic of querying all units/items for abilities,
    # checking conditions, and queueing effects.
    pass

func queue_effect(effect: Resource, source: GachaBallInstance, target: GachaBallInstance) -> void:
    var priority = 0 # Player-sourced effects should have higher priority.
    # This logic will be refined with BattleManager implementation.
    effect_queue.append({"effect": effect, "source": source, "target": target, "priority": priority})

func resolve_queue() -> void:
    # This method will sort the queue by priority and apply each effect.
    # It needs to handle cases where resolving one effect queues another.
    while not effect_queue.is_empty():
        var effect_data = effect_queue.pop_front()
        _apply_effect(effect_data)

    emit_signal("resolve_queue_completed")

func _apply_effect(effect_data: Dictionary) -> void:
    # Placeholder for the logic that matches effect_type to actions,
    # e.g., target.take_damage(), target.increase_hp().
    pass
