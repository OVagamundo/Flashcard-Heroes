extends Node

func _ready():
	# Wait for the Database to be ready
	await get_tree().process_frame
	
	test_gacha_system()

func test_gacha_system():
	print("=== Testing Gacha System ===")
	
	# Test drawing from each tier
	for tier in range(1, 4):
		var gacha = Database.get_random_gachaball(tier)
		if gacha:
			print("Tier", tier, " - ", gacha.display_name_key, " (", gacha.id, ")")
			
			# Create an instance of the gacha ball
			var instance = GachaBallInstance.new(gacha)
			print("  Instance UUID: ", instance.uuid)
			print("  HP: ", instance.get_hp_string())
			print("  Is Unit: ", instance.is_unit())
			print("  Is Item: ", instance.is_item())
		else:
			print("Failed to get gacha ball for tier ", tier)
		
		print("")
	
	print("=== Test Complete ===")
