extends Node

# Player stats
var hero_hp: int = 30
var max_hero_hp: int = 30
var gold: int = 0
var gacha_tokens: int = 0
var current_floor: int = 1

# Master Run Pool (collected units and items)
var master_run_pool: Array[Dictionary] = []

# Signals
signal health_changed(new_health: int, max_health: int)
signal gold_changed(new_amount: int)
signal tokens_changed(new_amount: int)

# Reset player data for a new run
func start_new_run() -> void:
	hero_hp = max_hero_hp
	gold = 0
	gacha_tokens = 0
	current_floor = 1
	master_run_pool.clear()
	
	# Emit initial values
	emit_signal("health_changed", hero_hp, max_hero_hp)
	emit_signal("gold_changed", gold)
	emit_signal("tokens_changed", gacha_tokens)

# Health management
func take_damage(amount: int) -> void:
	hero_hp = max(0, hero_hp - amount)
	emit_signal("health_changed", hero_hp, max_hero_hp)
	
	if hero_hp <= 0:
		GameManager.change_scene("game_over")

func heal(amount: int) -> void:
	hero_hp = min(max_hero_hp, hero_hp + amount)
	emit_signal("health_changed", hero_hp, max_hero_hp)

# Resource management
func add_gold(amount: int) -> void:
	gold += amount
	emit_signal("gold_changed", gold)

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		emit_signal("gold_changed", gold)
		return true
	return false

func add_gacha_tokens(amount: int) -> void:
	gacha_tokens += amount
	emit_signal("tokens_changed", gacha_tokens)

func spend_gacha_tokens(amount: int) -> bool:
	if gacha_tokens >= amount:
		gacha_tokens -= amount
		emit_signal("tokens_changed", gacha_tokens)
		return true
	return false

# Master Run Pool management
func add_to_master_pool(item_data: Dictionary) -> void:
	master_run_pool.append(item_data)

func remove_from_master_pool(index: int) -> void:
	if index >= 0 and index < master_run_pool.size():
		master_run_pool.remove_at(index)

# Save/Load functionality (stub for now)
func save_game() -> void:
	pass

func load_game() -> void:
	pass
