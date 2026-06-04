# scratch/test_rusty_ring.gd
extends SceneTree

# Mock classes to simulate the BattleManager and necessary types
class MockBattleManager:
	var instances: Dictionary = {}
	
	func get_all_instances() -> Dictionary:
		return instances
		
	func get_instance(uuid: String) -> GachaBallInstance:
		return instances.get(uuid)
		
	func get_instance_by_uuid(uuid: String) -> GachaBallInstance:
		return instances.get(uuid)
		
	func apply_stat_delta(instance: GachaBallInstance, stat: String, delta: int) -> Variant:
		if stat == "hp":
			instance.current_hp += delta
			return instance.current_hp
		elif stat == "pwr":
			instance.current_pwr += delta
			return instance.current_pwr
		return null
		
	func _is_player_owned(instance: GachaBallInstance) -> bool:
		var container = instance.location_container_tag
		return container == &"PlayerLineup" or container == &"PlayerTrinkets" or container == &"PlayerBench"

var log_file: FileAccess
var log_lines: Array = []

func log_print(msg: String) -> void:
	print(msg)
	log_lines.append(msg)

func _init():
	log_print("=========================================")
	log_print("RUNNING RUSTY RING AUTOMATED TESTS")
	log_print("=========================================")
	
	# 1. Load resources/scripts
	var EffectBuff = load("res://scripts/effects/EffectRustyRingBuff.gd")
	var EffectPassive = load("res://scripts/effects/EffectRustyRingPassive.gd")
	
	assert(EffectBuff != null, "Failed to load EffectRustyRingBuff")
	assert(EffectPassive != null, "Failed to load EffectRustyRingPassive")
	
	var buff_script = EffectBuff.new()
	var passive_script = EffectPassive.new()
	
	# Setup Mock Battle Manager and Database
	var bm = MockBattleManager.new()
	
	# Mock GachaBallDefinition for target unit
	var unit_def = GachaBallDefinition.new()
	unit_def.id = &"unit_test"
	unit_def.base_hp = 5
	unit_def.base_pwr = 3
	unit_def.category = &"UNIT"
	unit_def.item_slot_count = 1
	
	# Mock GachaBallDefinition for trinket
	var trinket_def = TrinketDefinition.new()
	trinket_def.id = &"trinket_rusty_ring"
	trinket_def.category = &"TRINKET"
	
	# Create GachaBallInstance for Trinket
	var trinket_inst = GachaBallInstance.new()
	trinket_inst.initialize_from_trinket(trinket_def)
	trinket_inst.location_container_tag = &"PlayerTrinkets"
	trinket_inst.location_slot_index = 0
	
	# Create GachaBallInstance for target unit
	var unit_inst = GachaBallInstance.new()
	unit_inst.initialize(unit_def)
	unit_inst.location_container_tag = &"PlayerLineup"
	unit_inst.location_slot_index = 0
	
	# Register instances in Mock BattleManager
	bm.instances[trinket_inst.ball_uuid] = trinket_inst
	bm.instances[unit_inst.ball_uuid] = unit_inst
	
	# Context
	var ctx = {
		"is_simulation": false, # Mutate stats directly for tests
		"team": "PLAYER"
	}
	
	log_print("\nTest 1: Initial state")
	log_print("Unit HP: %d (Expected: 5)" % unit_inst.current_hp)
	log_print("Unit PWR: %d (Expected: 3)" % unit_inst.current_pwr)
	log_print("Unit stacks: %d (Expected: 0)" % unit_inst.get_status_effect_amount(&"rusty_ring_stacks"))
	log_print("Unit has tag 'rusty_ring_buffed': %s (Expected: false)" % unit_inst.has_tag(&"rusty_ring_buffed"))
	
	assert(unit_inst.current_hp == 5)
	assert(unit_inst.current_pwr == 3)
	assert(unit_inst.get_status_effect_amount(&"rusty_ring_stacks") == 0)
	assert(!unit_inst.has_tag(&"rusty_ring_buffed"))
	
	# ----------------------------------------------------
	# Test 2: Trigger Buff (Battle Start)
	# ----------------------------------------------------
	log_print("\nTest 2: Triggering Rusty Ring Buff (Simulating Draw/Summon/Battle Start)")
	buff_script.execute(trinket_inst.ball_uuid, [], bm, ctx)
	
	log_print("Unit HP: %d (Expected: 6)" % unit_inst.current_hp)
	log_print("Unit PWR: %d (Expected: 4)" % unit_inst.current_pwr)
	log_print("Unit stacks: %d (Expected: 1)" % unit_inst.get_status_effect_amount(&"rusty_ring_stacks"))
	log_print("Unit has tag 'rusty_ring_buffed': %s (Expected: true)" % unit_inst.has_tag(&"rusty_ring_buffed"))
	
	assert(unit_inst.current_hp == 6)
	assert(unit_inst.current_pwr == 4)
	assert(unit_inst.get_status_effect_amount(&"rusty_ring_stacks") == 1)
	assert(unit_inst.has_tag(&"rusty_ring_buffed"))
	
	# ----------------------------------------------------
	# Test 3: Run passive with no changes
	# ----------------------------------------------------
	log_print("\nTest 3: Triggering Passive with no changes")
	passive_script.execute(trinket_inst.ball_uuid, [], bm, ctx)
	assert(unit_inst.current_hp == 6)
	assert(unit_inst.current_pwr == 4)
	assert(unit_inst.get_status_effect_amount(&"rusty_ring_stacks") == 1)
	log_print("Verification: Stats remained consistent.")
	
	# ----------------------------------------------------
	# Test 4: Equip an item (Buff should be cancelled)
	# ----------------------------------------------------
	log_print("\nTest 4: Equipping an item onto the unit")
	unit_inst.equipped_item_uuids[0] = "mock_item_uuid"
	passive_script.execute(trinket_inst.ball_uuid, [], bm, ctx)
	
	log_print("Unit HP: %d (Expected: 5)" % unit_inst.current_hp)
	log_print("Unit PWR: %d (Expected: 3)" % unit_inst.current_pwr)
	log_print("Unit stacks: %d (Expected: 0)" % unit_inst.get_status_effect_amount(&"rusty_ring_stacks"))
	log_print("Unit has tag 'rusty_ring_buffed': %s (Expected: false)" % unit_inst.has_tag(&"rusty_ring_buffed"))
	
	assert(unit_inst.current_hp == 5)
	assert(unit_inst.current_pwr == 3)
	assert(unit_inst.get_status_effect_amount(&"rusty_ring_stacks") == 0)
	assert(!unit_inst.has_tag(&"rusty_ring_buffed"))
	
	# ----------------------------------------------------
	# Test 5: Unequip the item (Buff should be restored)
	# ----------------------------------------------------
	log_print("\nTest 5: Unequipping the item from the unit")
	unit_inst.equipped_item_uuids[0] = ""
	passive_script.execute(trinket_inst.ball_uuid, [], bm, ctx)
	
	log_print("Unit HP: %d (Expected: 6)" % unit_inst.current_hp)
	log_print("Unit PWR: %d (Expected: 4)" % unit_inst.current_pwr)
	log_print("Unit stacks: %d (Expected: 1)" % unit_inst.get_status_effect_amount(&"rusty_ring_stacks"))
	log_print("Unit has tag 'rusty_ring_buffed': %s (Expected: true)" % unit_inst.has_tag(&"rusty_ring_buffed"))
	
	assert(unit_inst.current_hp == 6)
	assert(unit_inst.current_pwr == 4)
	assert(unit_inst.get_status_effect_amount(&"rusty_ring_stacks") == 1)
	assert(unit_inst.has_tag(&"rusty_ring_buffed"))
	
	# ----------------------------------------------------
	# Test 6: Merging carryover correction
	# ----------------------------------------------------
	log_print("\nTest 6: Simulating Merging two buffed units (Carryover correction)")
	var merged_unit = GachaBallInstance.new()
	merged_unit.initialize(unit_def)
	merged_unit.location_container_tag = &"PlayerLineup"
	merged_unit.location_slot_index = 0
	
	# Apply combined stats (+2)
	merged_unit.current_hp = 5 + 2 # 7
	merged_unit.current_pwr = 3 + 2 # 5
	merged_unit.add_status_effect_silent(&"rusty_ring_stacks", 2)
	merged_unit.add_tag(&"rusty_ring_buffed")
	
	bm.instances[merged_unit.ball_uuid] = merged_unit
	
	log_print("Merged Unit (Before Correction) HP: %d, PWR: %d, Stacks: %d" % [
		merged_unit.current_hp, merged_unit.current_pwr, merged_unit.get_status_effect_amount(&"rusty_ring_stacks")
	])
	
	# Run passive script to correct the carryover
	passive_script.execute(trinket_inst.ball_uuid, [], bm, ctx)
	
	log_print("Merged Unit (After Correction) HP: %d (Expected: 6)" % merged_unit.current_hp)
	log_print("Merged Unit (After Correction) PWR: %d (Expected: 4)" % merged_unit.current_pwr)
	log_print("Merged Unit (After Correction) Stacks: %d (Expected: 1)" % merged_unit.get_status_effect_amount(&"rusty_ring_stacks"))
	log_print("Merged Unit has tag 'rusty_ring_buffed': %s (Expected: true)" % merged_unit.has_tag(&"rusty_ring_buffed"))
	
	assert(merged_unit.current_hp == 6)
	assert(merged_unit.current_pwr == 4)
	assert(merged_unit.get_status_effect_amount(&"rusty_ring_stacks") == 1)
	assert(merged_unit.has_tag(&"rusty_ring_buffed"))
	
	# ----------------------------------------------------
	# Test 7: Enemy Trinket verification
	# ----------------------------------------------------
	log_print("\nTest 7: Enemy team trinket isolation")
	var enemy_trinket = GachaBallInstance.new()
	enemy_trinket.initialize_from_trinket(trinket_def)
	enemy_trinket.location_container_tag = &"EnemyTrinkets"
	enemy_trinket.location_slot_index = 0
	bm.instances[enemy_trinket.ball_uuid] = enemy_trinket
	
	var enemy_unit = GachaBallInstance.new()
	enemy_unit.initialize(unit_def)
	enemy_unit.location_container_tag = &"EnemyLineup"
	enemy_unit.location_slot_index = 0
	bm.instances[enemy_unit.ball_uuid] = enemy_unit
	
	var enemy_ctx = {
		"is_simulation": false,
		"team": "ENEMY"
	}
	
	# Reset player unit first
	unit_inst.current_hp = 5
	unit_inst.current_pwr = 3
	unit_inst.clear_status_effect(&"rusty_ring_stacks")
	unit_inst.remove_tag(&"rusty_ring_buffed")
	
	buff_script.execute(enemy_trinket.ball_uuid, [], bm, enemy_ctx)
	
	log_print("Player Unit HP after Enemy Buff: %d (Expected: 5)" % unit_inst.current_hp)
	log_print("Enemy Unit HP after Enemy Buff: %d (Expected: 6)" % enemy_unit.current_hp)
	
	assert(unit_inst.current_hp == 5)
	assert(enemy_unit.current_hp == 6)
	
	log_print("\n=========================================")
	log_print("ALL RUSTY RING TESTS PASSED SUCCESSFULLY!")
	log_print("=========================================")
	
	# Write log file
	var file = FileAccess.open("res://scratch/test_rusty_ring_log.txt", FileAccess.WRITE)
	if file:
		for line in log_lines:
			file.store_line(line)
		file.close()
		print("Logs written to res://scratch/test_rusty_ring_log.txt")
	
	quit()
