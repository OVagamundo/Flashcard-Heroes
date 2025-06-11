extends Node

# FSM States
enum State { IDLE, SETUP, START_OF_TURN, MANAGEMENT, COMBAT, END_OF_TURN, VICTORY, DEFEAT }
var _state: State = State.IDLE

# Properties
var _battle_gacha_pools: Dictionary = {} # Tier -> Array[GachaBallInstance]
var _battle_discard_pile: Array[GachaBallInstance] = []
var _gacha_tokens: int = 0
var active_synergies: Dictionary = {}

# Scene References
@onready var player_lineup_container = find_child("PlayerLineup")
@onready var enemy_lineup_container = find_child("EnemyLineup")
@onready var player_bench_container = find_child("PlayerBench")
@onready var player_inventory_container = find_child("PlayerInventory")

func _ready() -> void:
    EventBus.initiate_battle.connect(_on_initiate_battle)
    EventBus.draw_gacha_request.connect(_on_draw_gacha_request)
    EventBus.end_turn_button_pressed.connect(_on_end_turn_button_pressed)
    EventBus.merge_units_requested.connect(_on_merge_units_requested)
    EventBus.equip_item_requested.connect(_on_equip_item_requested)

func _on_initiate_battle(battle_setup_data: Dictionary) -> void:
    _transition_to(State.SETUP, battle_setup_data)

func _transition_to(new_state: State, data = null) -> void:
    _state = new_state
    match _state:
        State.SETUP:
            _enter_setup(data)
        State.START_OF_TURN:
            _enter_start_of_turn()
        State.MANAGEMENT:
            # Player makes decisions in this phase
            pass
        State.COMBAT:
            _enter_combat()
        State.END_OF_TURN:
            _enter_end_of_turn()
        State.VICTORY:
            EventBus.emit_signal("battle_won")
        State.DEFEAT:
            EventBus.emit_signal("battle_lost")

func _enter_setup(battle_setup_data: Dictionary) -> void:
    # 1. Clear previous state
    for container in [player_lineup_container, enemy_lineup_container, player_bench_container, player_inventory_container]:
        for child in container.get_children():
            child.queue_free()
    _battle_gacha_pools = {}
    _battle_discard_pile.clear()
    _gacha_tokens = 0

    # 2. Populate battle gacha pools from setup data
    var player_pool = battle_setup_data["player_pool"]
    for tier in player_pool:
        _battle_gacha_pools[tier] = []
        for unit_instance in player_pool[tier]:
            unit_instance.current_location_state = GachaBallInstance.LocationState.IN_BATTLE_GACHA_POOL_TIER_1 # Simplified
            _battle_gacha_pools[tier].append(unit_instance)

    # 3. Instantiate enemy units
    var encounter_def = battle_setup_data["encounter_def"]
    for unit_def in encounter_def.enemy_units:
        var enemy_instance = GachaBallInstance.new()
        enemy_instance.initialize(unit_def)
        enemy_instance.current_location_state = GachaBallInstance.LocationState.IN_ENEMY_LINEUP
        _add_unit_display(enemy_lineup_container, enemy_instance)

    # 4. Instantiate player hero
    var hero_instance = battle_setup_data["player_hero"]
    hero_instance.current_location_state = GachaBallInstance.LocationState.IN_PLAYER_LINEUP
    _add_unit_display(player_lineup_container, hero_instance)

    # 5. Initial synergy check & battle start
    _update_and_apply_synergies()
    EventBus.emit_signal("battle_started")
    _transition_to(State.START_OF_TURN)

func _enter_start_of_turn() -> void:
    # Per TDD, simplified flashcard mechanic
    _gacha_tokens += 3
    EventBus.gacha_tokens_updated.emit(_gacha_tokens)

    EventBus.turn_started.emit()
    await AbilityResolver.resolve_queue_completed
    _transition_to(State.MANAGEMENT)

func _enter_combat() -> void:
    var action_order: Array = []
    var player_units = _get_instances_from_container(player_lineup_container)
    var enemy_units = _get_instances_from_container(enemy_lineup_container)

    # This logic assumes team and position are stored on the instance, which isn't in the TDD.
    # We will simulate it based on container and child index.
    for i in range(player_units.size()):
        player_units[i].team = "PLAYER"
        player_units[i].position = i
    for i in range(enemy_units.size()):
        enemy_units[i].team = "ENEMY"
        enemy_units[i].position = i

    action_order.append_array(player_units)
    action_order.append_array(enemy_units)

    # Per TDD: Sort by Player team first, then back-to-front (higher position index)
    action_order.sort_custom(func(a, b):
        if a.team != b.team:
            return a.team == "PLAYER"
        return a.position > b.position
    )

    for unit_instance in action_order:
        if unit_instance.current_hp <= 0:
            continue

        EventBus.unit_is_acting.emit(unit_instance)
        await AbilityResolver.resolve_queue_completed

        var _unit_display = _find_unit_display(unit_instance) # Prefixed with _ as it's currently unused
        # TDD mentions a `play_act_animation` method which is not on UnitDisplay.gd yet.
        # if _unit_display:
        #     _unit_display.play_act_animation()
        await get_tree().create_timer(0.5).timeout

    _transition_to(State.END_OF_TURN)

func _enter_end_of_turn() -> void:
    EventBus.turn_ended.emit()
    await AbilityResolver.resolve_queue_completed

    # Check for victory/defeat
    if _get_instances_from_container(enemy_lineup_container).is_empty():
        _transition_to(State.VICTORY)
    elif _get_instances_from_container(player_lineup_container).is_empty():
        _transition_to(State.DEFEAT)
    else:
        _transition_to(State.START_OF_TURN)

# --- Helper & Stub Methods ---

func _add_unit_display(container: Node, instance: GachaBallInstance) -> void:
    var unit_display_scene = load("res://scenes/UnitDisplay.tscn")
    var unit_display = unit_display_scene.instantiate()
    container.add_child(unit_display)
    unit_display.display_instance(instance)

func _get_instances_from_container(container: Node) -> Array[GachaBallInstance]:
    var instances = []
    for child in container.get_children():
        if child.has_method("get_instance") and is_instance_valid(child.get_instance()):
            instances.append(child.get_instance())
    return instances

func _find_unit_display(instance_to_find: GachaBallInstance) -> Node:
    for container in [player_lineup_container, enemy_lineup_container, player_bench_container]:
        for child in container.get_children():
            if child.has_method("get_instance") and child.get_instance() == instance_to_find:
                return child
    return null

func _on_end_turn_button_pressed() -> void:
    if _state == State.MANAGEMENT:
        _transition_to(State.COMBAT)

func _on_draw_gacha_request(_tier: int) -> void: pass
func _on_merge_units_requested(_unit_a_uuid: String, _unit_b_uuid: String) -> void: pass
func _on_equip_item_requested(_item_uuid: String, _target_unit_uuid: String) -> void: pass
func _update_and_apply_synergies() -> void: pass
