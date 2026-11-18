# res://scripts/systems/EncounterSynergyRegistry.gd
class_name EncounterSynergyRegistry
extends RefCounted

const C = preload("res://scripts/Constants.gd")

## Units excluded from enemy encounter drafting due to asymmetric player-only mechanics:
## - FWAASpeToy (Wind-up-kun): grows on PlayerShelf (enemies have no shelf)
## - EFFWSpeApp (Blendroid): scales on_merge on merged_team (enemies never merge in combat)
## - FASpeApp (Furnair): scales with unspent player gacha tokens (spent prior to combat)
## - EFWASpeFod (BubbleGunger): scales with twin copies and shuffles into gacha machine
const ENEMY_EXCLUDED_UNITS: Array[StringName] = [
	&"FWAASpeToy",
	&"EFFWSpeApp",
	&"FASpeApp",
	&"EFWASpeFod"
]

const UNIT_PROFILES: Dictionary = {
	# ==================== TIER 1 (Cost 1G) ====================
	&"ETnkPla": { # Stumpling
		"tier": 1,
		"cost": 1,
		"preferred_slots": [0, 1],
		"mandatory_front": false,
		"mandatory_behind": false,
		"forbidden_slots": [3, 4],
		"front_partners": [&"ASpeFod", &"EMPTY"],
		"behind_partners": [&"WSupAni", &"FWFigFod", &"ASpeFod", &"FFigMec", &"EEFWSupPla", &"EWAASpeApp"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_plant", &"trinket_trait_tank", &"trinket_purifying_pendant"],
		"slot_0_trinket_votes": [&"trinket_spiked_armor"]
	},
	&"FFigMec": { # Vulcannon
		"tier": 1,
		"cost": 1,
		"preferred_slots": [0, 3, 4],
		"mandatory_front": false,
		"mandatory_behind": false,
		"forbidden_slots": [],
		"front_partners": [&"ASpeFod", &"ETnkPla", &"EFTnkMec", &"FFWASupMec", &"FWFigFod", &"EMPTY"],
		"behind_partners": [&"EWFigCos"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_mecha", &"trinket_trait_fighter", &"trinket_vengeance"]
	},
	&"WSupAni": { # Ripplepup (NEVER place in Slot 0!)
		"tier": 1,
		"cost": 1,
		"preferred_slots": [1, 2, 3],
		"forbidden_slots": [0],
		"mandatory_front": true,
		"mandatory_behind": false,
		"front_partners": [&"EFTnkMec", &"ETnkPla", &"EFWATnkApp", &"EWFigCos"],
		"behind_partners": [&"FWFigFod", &"ASpeFod", &"FFigMec"],
		"items": [&"item_t1_a", &"item_t2_a", &"item_t3_a"],
		"trinket_votes": [&"trinket_trait_water", &"trinket_trait_animal", &"trinket_trait_support", &"trinket_vengeance"]
	},
	&"ASpeFod": { # Puffcorn
		"tier": 1,
		"cost": 1,
		"preferred_slots": [0, 3, 4],
		"mandatory_front": false,
		"mandatory_behind": false,
		"mandatory_behind_if_slot_0": true,
		"forbidden_slots": [1, 2],
		"front_partners": [&"EMPTY", &"ETnkPla", &"EFTnkMec", &"ASpeFod", &"FWFigFod", &"WSupAni"],
		"behind_partners": [&"FFigMec", &"EWFigCos", &"EFTnkMec", &"ETnkPla", &"EASupToy", &"ASpeFod"],
		"items": [&"item_t1_b", &"item_t3_e"],
		"trinket_votes": [&"trinket_trait_air", &"trinket_trait_food", &"trinket_trait_specialist", &"trinket_vengeance"]
	},
	# ==================== TIER 2 (Cost 2G) ====================
	&"EWFigCos": { # Bogmantle
		"tier": 2,
		"cost": 2,
		"preferred_slots": [1, 2, 3],
		"forbidden_slots": [],
		"front_partners": [&"ASpeFod", &"EASupToy", &"EFAASupToy", &"FFigMec", &"EEFWSupPla", &"FFWASupMec"],
		"behind_partners": [&"FWWATnkFod", &"WSupAni"],
		"items": [&"item_t2_b", &"item_t3_c", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_fighter", &"trinket_trait_costume", &"trinket_vengeance", &"trinket_soul_echo"]
	},
	&"FASpeApp": { # Furnair (Player Exclusive in Combat)
		"tier": 2,
		"cost": 2,
		"is_enemy_draftable": false,
		"preferred_slots": [2, 3],
		"forbidden_slots": [0, 4],
		"front_partners": [&"ETnkPla", &"EFTnkMec", &"ASpeFod"],
		"behind_partners": [&"WSupAni", &"EFWAFigMec"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_appliance"]
	},
	&"EASupToy": { # Matryodust
		"tier": 2,
		"cost": 2,
		"preferred_slots": [0, 1],
		"forbidden_slots": [3, 4],
		"front_partners": [&"EMPTY", &"ASpeFod"],
		"behind_partners": [&"EWFigCos", &"EFFASupMec"],
		"items": [&"item_t2_a", &"item_t3_e", &"item_t1_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_toy", &"trinket_vengeance"]
	},
	&"WATnkAni": { # Soliwhale (Pairs with empty space in front or behind!)
		"tier": 2,
		"cost": 2,
		"preferred_slots": [0],
		"forbidden_slots": [1, 2, 3, 4],
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t2_c", &"item_t3_b", &"item_t3_c", &"item_t3_d", &"item_t1_a"],
		"trinket_votes": [&"trinket_underdog_emblem", &"trinket_spiked_armor", &"trinket_polished_plate", &"trinket_aegis", &"trinket_rusty_ring"]
	},
	&"EFTnkMec": { # Branblee
		"tier": 2,
		"cost": 2,
		"preferred_slots": [0, 1],
		"forbidden_slots": [3, 4],
		"front_partners": [&"ASpeFod", &"EMPTY"],
		"behind_partners": [&"WSupAni", &"FWFigFod", &"FFigMec", &"ASpeFod", &"EEFASpeCos", &"EEFWSupPla", &"EEWAFigAni", &"EFWWFigCos", &"EWWATnkToy", &"EWAASpeApp"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_tank", &"trinket_trait_mecha", &"trinket_spiked_armor", &"trinket_polished_plate"]
	},
	&"FWFigFod": { # Pepspray
		"tier": 2,
		"cost": 2,
		"preferred_slots": [2, 3],
		"forbidden_slots": [0, 4],
		"front_partners": [&"WSupAni", &"ETnkPla", &"EFTnkMec"],
		"behind_partners": [&"ASpeFod", &"FFigMec", &"EFWAFigMec"],
		"items": [&"item_t1_a", &"item_t3_c"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_fighter", &"trinket_trait_food"]
	},
	# ==================== TIER 3 (Cost 4G) ====================
	&"EEFASpeCos": { # Mimicloak
		"tier": 3,
		"cost": 4,
		"preferred_slots": [0, 1, 2],
		"forbidden_slots": [],
		"front_partners": [&"EFTnkMec", &"EWWATnkToy", &"EMPTY"],
		"behind_partners": [&"EWAASpeApp"],
		"items": [&"item_t2_b", &"item_t1_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_costume"]
	},
	&"EEFWSupPla": { # Oakbark
		"tier": 3,
		"cost": 4,
		"preferred_slots": [1, 2],
		"forbidden_slots": [0, 3, 4],
		"front_partners": [&"ETnkPla", &"EFTnkMec"],
		"behind_partners": [&"FWWATnkFod", &"EWFigCos"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_support", &"trinket_trait_plant", &"trinket_armor_aura"]
	},
	&"EEWAFigAni": { # Griffoam
		"tier": 3,
		"cost": 4,
		"preferred_slots": [2, 3, 4],
		"forbidden_slots": [],
		"front_partners": [&"EFTnkMec", &"EFWATnkApp", &"EWWATnkToy"],
		"behind_partners": [&"EFWAFigMec"],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_f"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_fighter", &"trinket_trait_animal"]
	},
	&"EFAASupToy": { # Matryoshkan
		"tier": 3,
		"cost": 4,
		"preferred_slots": [0, 1],
		"forbidden_slots": [],
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"EWFigCos", &"EFFASupMec"],
		"items": [&"item_t2_a", &"item_t3_e", &"item_t2_c"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_toy", &"trinket_vengeance"]
	},
	&"EFFASupMec": { # Mechamom
		"tier": 3,
		"cost": 4,
		"preferred_slots": [3, 4],
		"forbidden_slots": [],
		"front_partners": [&"EASupToy", &"EFAASupToy"],
		"behind_partners": [&"EFWAFigMec"],
		"items": [&"item_t1_a", &"item_t2_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_mecha"]
	},
	&"EFFWSpeApp": { # Blendroid (Player Exclusive in Combat)
		"tier": 3,
		"cost": 4,
		"is_enemy_draftable": false,
		"preferred_slots": [1, 2],
		"forbidden_slots": [],
		"front_partners": [&"ETnkPla", &"EFTnkMec"],
		"behind_partners": [&"FWWATnkFod"],
		"items": [&"item_t2_b", &"item_t3_b", &"item_t3_c"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_specialist", &"trinket_trait_appliance"]
	},
	&"EFWAFigMec": { # Pachinkannon
		"tier": 3,
		"cost": 4,
		"preferred_slots": [3, 4],
		"forbidden_slots": [0, 1, 2],
		"front_partners": [&"EWWATnkToy", &"EFWATnkApp", &"EEWAFigAni", &"EFFASupMec"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t3_f", &"item_t2_b", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_fighter", &"trinket_trait_mecha"]
	},
	&"EFWASpeFod": { # BubbleGunger (Player Exclusive in Combat)
		"tier": 3,
		"cost": 4,
		"is_enemy_draftable": false,
		"preferred_slots": [1, 2, 3],
		"forbidden_slots": [],
		"front_partners": [&"EFTnkMec"],
		"behind_partners": [],
		"items": [&"item_t1_b", &"item_t2_b", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_food", &"trinket_twin_charm"]
	},
	&"EFWATnkApp": { # Reizokun
		"tier": 3,
		"cost": 4,
		"preferred_slots": [0],
		"forbidden_slots": [2, 3, 4],
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"WSupAni", &"EWWATnkToy", &"EFWWFigCos", &"EEWAFigAni", &"EFWAFigMec", &"EWAASpeApp"],
		"items": [&"item_t2_c", &"item_t3_b", &"item_t1_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_tank", &"trinket_spiked_armor", &"trinket_polished_plate"]
	},
	&"EFWWFigCos": { # Tsunamantle
		"tier": 3,
		"cost": 4,
		"preferred_slots": [1, 2],
		"forbidden_slots": [4],
		"front_partners": [&"FFWASupMec", &"EFWATnkApp", &"EFTnkMec", &"EWWATnkToy"],
		"behind_partners": [&"FWWATnkFod"],
		"items": [&"item_t2_b", &"item_t3_b", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_fighter", &"trinket_trait_costume"]
	},
	&"EWAASpeApp": { # Sojikun
		"tier": 3,
		"cost": 4,
		"preferred_slots": [2, 3],
		"forbidden_slots": [0],
		"front_partners": [&"EEFASpeCos", &"ETnkPla", &"EFTnkMec", &"EFWATnkApp", &"EWWATnkToy"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t1_b", &"item_t3_c", &"item_t3_f"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_appliance"]
	},
	&"EWWATnkToy": { # Komatop
		"tier": 3,
		"cost": 4,
		"preferred_slots": [1, 2],
		"forbidden_slots": [4],
		"front_partners": [&"EFWATnkApp", &"EFTnkMec"],
		"behind_partners": [&"EFWAFigMec", &"EFWWFigCos", &"EEFASpeCos", &"EEWAFigAni", &"EWAASpeApp"],
		"items": [&"item_t2_c", &"item_t3_b", &"item_t1_a"],
		"trinket_votes": [&"trinket_trait_earth", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_tank", &"trinket_trait_toy", &"trinket_aegis", &"trinket_polished_plate"]
	},
	&"FFWASupMec": { # Relaytron
		"tier": 3,
		"cost": 4,
		"preferred_slots": [0, 1],
		"forbidden_slots": [4],
		"mandatory_behind": true,
		"front_partners": [&"EMPTY"],
		"behind_partners": [&"EFWWFigCos", &"EWFigCos", &"FFigMec"],
		"items": [&"item_t2_b", &"item_t3_b", &"item_t3_c"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_support", &"trinket_trait_mecha", &"trinket_vengeance"]
	},
	&"FWAASpeToy": { # Wind-up-kun (Player Exclusive in Combat)
		"tier": 3,
		"cost": 4,
		"is_enemy_draftable": false,
		"preferred_slots": [1],
		"forbidden_slots": [4],
		"front_partners": [&"EFTnkMec", &"EFWATnkApp"],
		"behind_partners": [&"FWWATnkFod"],
		"items": [&"item_t2_b", &"item_t3_c", &"item_t1_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_specialist", &"trinket_trait_toy"]
	},
	&"FWWATnkFod": { # Nuton
		"tier": 3,
		"cost": 4,
		"preferred_slots": [2],
		"forbidden_slots": [0, 4],
		"front_partners": [&"EEFWSupPla", &"EWFigCos"],
		"behind_partners": [&"EMPTY"],
		"items": [&"item_t1_a", &"item_t2_c", &"item_t3_b"],
		"trinket_votes": [&"trinket_trait_fire", &"trinket_trait_water", &"trinket_trait_air", &"trinket_trait_tank", &"trinket_trait_food", &"trinket_armor_aura"]
	}
}

# =============================================================================
# CURATED ATOMIC SYNERGY PACKAGES (PAIRS & TRIPLETS)
# =============================================================================

const SYNERGY_PACKAGES: Array[Dictionary] = [
	# -------------------- TIER 1 PAIRS (Cost: 2G) --------------------
	{
		"id": &"pair_stumpling_ripplepup",
		"type": &"PAIR",
		"units": [&"ETnkPla", &"WSupAni"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 2,
		"tags": [&"Tank", &"Support", &"Earth", &"Water"],
		"base_weight": 110.0
	},
	{
		"id": &"pair_puffcorn_vulcannon",
		"type": &"PAIR",
		"units": [&"ASpeFod", &"FFigMec"],
		"valid_start_slots": [0],
		"required_items": {},
		"base_cost": 2,
		"tags": [&"Specialist", &"Fighter", &"Air", &"Fire"],
		"base_weight": 100.0
	},
	{
		"id": &"pair_stumpling_vulcannon",
		"type": &"PAIR",
		"units": [&"ETnkPla", &"FFigMec"],
		"valid_start_slots": [0, 1, 2],
		"required_items": {},
		"base_cost": 2,
		"tags": [&"Tank", &"Fighter", &"Earth", &"Fire"],
		"base_weight": 80.0
	},

	# -------------------- TIER 2 & CROSS-TIER PAIRS (Cost: 3G - 6G) --------------------
	{
		"id": &"pair_branblee_ripplepup",
		"type": &"PAIR",
		"units": [&"EFTnkMec", &"WSupAni"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 3,
		"tags": [&"Tank", &"Support", &"Fire", &"Earth", &"Water"],
		"base_weight": 120.0
	},
	{
		"id": &"pair_puffcorn_bogmantle",
		"type": &"PAIR",
		"units": [&"ASpeFod", &"EWFigCos"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 3,
		"tags": [&"Specialist", &"Fighter", &"Air", &"Earth"],
		"base_weight": 100.0
	},
	{
		"id": &"pair_branblee_vulcannon",
		"type": &"PAIR",
		"units": [&"EFTnkMec", &"FFigMec"],
		"valid_start_slots": [0, 1, 2],
		"required_items": {},
		"base_cost": 3,
		"tags": [&"Tank", &"Fighter", &"Fire", &"Earth"],
		"base_weight": 80.0
	},
	{
		"id": &"pair_stumpling_branblee",
		"type": &"PAIR",
		"units": [&"ETnkPla", &"EFTnkMec"],
		"valid_start_slots": [0],
		"required_items": {},
		"base_cost": 3,
		"tags": [&"Tank", &"Earth", &"Fire"],
		"base_weight": 90.0
	},
	{
		"id": &"pair_matryodust_bogmantle",
		"type": &"PAIR",
		"units": [&"EASupToy", &"EWFigCos"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 4,
		"tags": [&"Support", &"Fighter", &"Earth", &"Toy"],
		"base_weight": 100.0
	},
	{
		"id": &"pair_reizokun_ripplepup",
		"type": &"PAIR",
		"units": [&"EFWATnkApp", &"WSupAni"],
		"valid_start_slots": [0],
		"required_items": {},
		"base_cost": 5,
		"tags": [&"Tank", &"Support", &"Water", &"Appliance"],
		"base_weight": 90.0
	},
	{
		"id": &"pair_matryodust_mechamom",
		"type": &"PAIR",
		"units": [&"EASupToy", &"EFFASupMec"],
		"valid_start_slots": [0, 1, 2],
		"required_items": {},
		"base_cost": 6,
		"tags": [&"Support", &"Toy", &"Mecha"],
		"base_weight": 90.0
	},
	{
		"id": &"pair_bogmantle_nuton",
		"type": &"PAIR",
		"units": [&"EWFigCos", &"FWWATnkFod"],
		"valid_start_slots": [1],
		"required_items": {},
		"base_cost": 6,
		"tags": [&"Fighter", &"Tank", &"Food"],
		"base_weight": 85.0
	},
	{
		"id": &"pair_branblee_komatop",
		"type": &"PAIR",
		"units": [&"EFTnkMec", &"EWWATnkToy"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 6,
		"tags": [&"Tank", &"Toy", &"Mecha"],
		"base_weight": 80.0
	},

	# -------------------- TIER 3 PAIRS (Cost: 8G - 10G) --------------------
	{
		"id": &"pair_matryoshkan_mechamom",
		"type": &"PAIR",
		"units": [&"EFAASupToy", &"EFFASupMec"],
		"valid_start_slots": [0, 1, 2],
		"required_items": {},
		"base_cost": 8,
		"tags": [&"Support", &"Toy", &"Mecha"],
		"base_weight": 90.0
	},
	{
		"id": &"pair_oakbark_nuton",
		"type": &"PAIR",
		"units": [&"EEFWSupPla", &"FWWATnkFod"],
		"valid_start_slots": [1],
		"required_items": {},
		"base_cost": 8,
		"tags": [&"Support", &"Tank", &"Plant", &"Food"],
		"base_weight": 100.0
	},
	{
		"id": &"pair_komatop_pachinkannon",
		"type": &"PAIR",
		"units": [&"EWWATnkToy", &"EFWAFigMec"],
		"valid_start_slots": [1, 2],
		"required_items": {},
		"base_cost": 8,
		"tags": [&"Tank", &"Fighter", &"Toy", &"Mecha"],
		"base_weight": 80.0
	},
	{
		"id": &"pair_griffoam_pachinkannon",
		"type": &"PAIR",
		"units": [&"EEWAFigAni", &"EFWAFigMec"],
		"valid_start_slots": [2, 3],
		"required_items": {},
		"base_cost": 8,
		"tags": [&"Fighter", &"Animal", &"Mecha"],
		"base_weight": 70.0
	},
	{
		"id": &"pair_reizokun_komatop",
		"type": &"PAIR",
		"units": [&"EFWATnkApp", &"EWWATnkToy"],
		"valid_start_slots": [0],
		"required_items": {},
		"base_cost": 8,
		"tags": [&"Tank", &"Toy", &"Appliance"],
		"base_weight": 80.0
	},
	{
		"id": &"pair_relaytron_bogmantle",
		"type": &"PAIR",
		"units": [&"FFWASupMec", &"EWFigCos"],
		"valid_start_slots": [0, 1],
		"required_items": {0: &"item_t2_b"},
		"base_cost": 8, # 4 + 2 + 2(Scythe)
		"tags": [&"Support", &"Fighter", &"Mecha"],
		"base_weight": 90.0
	},
	{
		"id": &"pair_relaytron_tsunamantle",
		"type": &"PAIR",
		"units": [&"FFWASupMec", &"EFWWFigCos"],
		"valid_start_slots": [0, 1],
		"required_items": {0: &"item_t2_b"},
		"base_cost": 10, # 4 + 4 + 2(Scythe)
		"tags": [&"Support", &"Fighter", &"Mecha", &"Costume"],
		"base_weight": 100.0
	},

	# -------------------- TRIPLETS (Cost: 6G - 9G) --------------------
	{
		"id": &"triplet_fire_branblee_ripplepup_pepspray",
		"type": &"TRIPLET",
		"units": [&"EFTnkMec", &"WSupAni", &"FWFigFod"],
		"valid_start_slots": [0],
		"required_items": {1: &"item_emblem_fire", 2: &"item_t1_a"},
		"base_cost": 6, # 2 + 1 + 2 + Candy (1); the Fire Emblem is free.
		"tags": [&"Tank", &"Support", &"Fighter", &"Fire", &"SOUL_FIRE"],
		"base_weight": 150.0
	},
	{
		"id": &"triplet_puffcorn_bogmantle_nuton",
		"type": &"TRIPLET",
		"units": [&"ASpeFod", &"EWFigCos", &"FWWATnkFod"],
		"valid_start_slots": [0],
		"required_items": {},
		"base_cost": 7, # 1 + 2 + 4
		"tags": [&"Specialist", &"Fighter", &"Tank", &"Food"],
		"base_weight": 90.0
	},
	{
		"id": &"triplet_branblee_ripplepup_pachinkannon",
		"type": &"TRIPLET",
		"units": [&"EFTnkMec", &"WSupAni", &"EFWAFigMec"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 7, # 2 + 1 + 4
		"tags": [&"Tank", &"Support", &"Fighter", &"Mecha"],
		"base_weight": 90.0
	},
	{
		"id": &"triplet_matryodust_bogmantle_mechamom",
		"type": &"TRIPLET",
		"units": [&"EASupToy", &"EWFigCos", &"EFFASupMec"],
		"valid_start_slots": [0, 1],
		"required_items": {},
		"base_cost": 8, # 2 + 2 + 4
		"tags": [&"Support", &"Fighter", &"Toy", &"Mecha"],
		"base_weight": 90.0
	},
	{
		"id": &"triplet_stumpling_oakbark_nuton",
		"type": &"TRIPLET",
		"units": [&"ETnkPla", &"EEFWSupPla", &"FWWATnkFod"],
		"valid_start_slots": [0],
		"required_items": {},
		"base_cost": 9, # 1 + 4 + 4
		"tags": [&"Tank", &"Support", &"Plant", &"Food"],
		"base_weight": 100.0
	}
]

## Extra curated packages. Trait-only packages rely on that banner's Crest and Emblems.
const TRAIT_PACKAGES: Array[Dictionary] = [
	{"id": &"pair_pepspray_ripplepup", "units": [&"FWFigFod", &"WSupAni"], "valid_start_slots": [0, 1, 2], "required_items": {}, "base_cost": 3, "base_weight": 120.0},
	{"id": &"pair_stumpling_pepspray", "units": [&"ETnkPla", &"FWFigFod"], "valid_start_slots": [0, 1], "required_items": {}, "base_cost": 3, "base_weight": 130.0, "trait_only": true},
	{"id": &"triplet_stumpling_pepspray_nuton", "units": [&"ETnkPla", &"FWFigFod", &"FWWATnkFod"], "valid_start_slots": [0], "required_items": {}, "base_cost": 7, "base_weight": 140.0, "trait_only": true},
	{"id": &"triplet_oakbark_bogmantle_nuton", "units": [&"EEFWSupPla", &"EWFigCos", &"FWWATnkFod"], "valid_start_slots": [1], "required_items": {}, "base_cost": 10, "base_weight": 130.0},
	{"id": &"pair_nuton_ripplepup", "units": [&"FWWATnkFod", &"WSupAni"], "valid_start_slots": [2, 3], "required_items": {}, "base_cost": 5, "base_weight": 80.0},
	{"id": &"pair_relaytron_vulcannon", "units": [&"FFWASupMec", &"FFigMec"], "valid_start_slots": [0, 1], "required_items": {0: &"item_t2_b"}, "base_cost": 7, "base_weight": 100.0},
	{"id": &"pair_stumpling_sojikun", "units": [&"ETnkPla", &"EWAASpeApp"], "valid_start_slots": [0, 1], "required_items": {}, "base_cost": 5, "base_weight": 90.0},
	{"id": &"pair_sojikun_pachinkannon", "units": [&"EWAASpeApp", &"EFWAFigMec"], "valid_start_slots": [1, 2, 3], "required_items": {}, "base_cost": 8, "base_weight": 80.0},
]

static func get_package(package_id: StringName) -> Dictionary:
	for package: Dictionary in SYNERGY_PACKAGES + TRAIT_PACKAGES:
		if package["id"] == package_id:
			return package
	assert(false, "EncounterSynergyRegistry: unknown package %s" % package_id)
	return {}

static func is_unit_enemy_draftable(unit_id: StringName) -> bool:
	if ENEMY_EXCLUDED_UNITS.has(unit_id):
		return false
	assert(UNIT_PROFILES.has(unit_id), "EncounterSynergyRegistry: missing profile for %s" % unit_id)
	var definition: GachaBallDefinition = Database.get_definition(unit_id) as GachaBallDefinition
	assert(definition != null, "EncounterSynergyRegistry: missing unit %s" % unit_id)
	return not definition.is_player_exclusive and not definition.is_hero and Database.get_entity_set(definition) == Database.SET_BASE and bool(UNIT_PROFILES[unit_id].get("is_enemy_draftable", true))

static func get_profile(unit_id: StringName) -> Dictionary:
	return UNIT_PROFILES.get(unit_id, {})

static func get_unit_cost(unit_id: StringName) -> int:
	var prof: Dictionary = UNIT_PROFILES.get(unit_id, {})
	if prof.has("cost"):
		return int(prof["cost"])
	var def = Database.get_definition(unit_id)
	if is_instance_valid(def):
		return (1 << (int(def.tier) - 1))
	return 1

static func get_front_partners(unit_id: StringName) -> Array:
	var prof: Dictionary = UNIT_PROFILES.get(unit_id, {})
	return prof.get("front_partners", [])

static func get_behind_partners(unit_id: StringName) -> Array:
	var prof: Dictionary = UNIT_PROFILES.get(unit_id, {})
	return prof.get("behind_partners", [])

## Returns all Synergy Packages valid for a given budget, start slot, and available span.
static func get_eligible_packages(
	max_cost: int,
	start_slot: int,
	max_units: int,
	unit_filter: Callable = Callable()
) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for pkg in SYNERGY_PACKAGES:
		var u_list: Array = pkg["units"]
		if u_list.size() > max_units:
			continue
		var valid_slots: Array = pkg["valid_start_slots"]
		if not valid_slots.has(start_slot):
			continue
		var cost: int = int(pkg["base_cost"])
		if cost > max_cost:
			continue
		var all_valid: bool = true
		for u_id in u_list:
			if not is_unit_enemy_draftable(u_id):
				all_valid = false
				break
			if unit_filter.is_valid() and not unit_filter.call(u_id):
				all_valid = false
				break
		if all_valid:
			eligible.append(pkg)
	return eligible

## Scores a Synergy Package based on base weight, adjacent board connection, and secondary trinkets.
static func score_package(
	pkg: Dictionary,
	start_slot: int,
	board: Dictionary,
	active_trinkets: Array[StringName]
) -> float:
	var score: float = float(pkg.get("base_weight", 100.0))
	var u_list: Array = pkg["units"]

	# Bonus if connected to previous unit on board
	if start_slot > 0 and board.has(start_slot - 1):
		var prev_id: StringName = board[start_slot - 1]
		var front_unit: StringName = u_list[0]
		var prev_behind: Array = get_behind_partners(prev_id)
		if prev_behind.has(front_unit):
			score += 50.0
		var front_prof_front: Array = get_front_partners(front_unit)
		if front_prof_front.has(prev_id):
			score += 50.0

	# Trinket vote match multiplier (x1.5 per matching tag)
	var pkg_tags: Array = pkg.get("tags", [])
	for t_id in active_trinkets:
		for tag in pkg_tags:
			if String(t_id).to_upper().find(String(tag).to_upper()) != -1:
				score *= 1.5
				break

	return score

## Validates whether a unit can legally occupy a given slot index on the board.
static func is_valid_slot_for_unit(unit_id: StringName, slot: int, board: Dictionary) -> bool:
	if not is_unit_enemy_draftable(unit_id):
		return false
	if slot < 0 or slot > 4:
		return false
	var prof: Dictionary = UNIT_PROFILES.get(unit_id, {})
	if prof.is_empty():
		return true

	var forbidden_slots: Array = prof.get("forbidden_slots", [])
	if forbidden_slots.has(slot):
		return false

	# Mandatory Front (e.g. Ripplepup WSupAni): cannot be in slot 0, and MUST have a unit in slot - 1
	if prof.get("mandatory_front", false):
		if slot == 0 or not board.has(slot - 1):
			return false

	# Mandatory Behind (e.g. Relaytron FFWASupMec): cannot be in slot 4
	if prof.get("mandatory_behind", false) and slot == 4:
		return false

	# Frontline Tanks: if preferred_slots is [0, 1] or unit is a Tank, do not allow in slot >= 2 if slot 0 or slot 1 is empty
	var pref_slots: Array = prof.get("preferred_slots", [])
	if pref_slots.has(0) and not pref_slots.has(3) and not pref_slots.has(4):
		if slot >= 2 and (not board.has(0) or not board.has(1)):
			return false

	# Soliwhale Solitary Guard: requires at least one adjacent empty slot (front or behind).
	if unit_id == &"WATnkAni":
		var front_occupied := (slot > 0 and board.has(slot - 1))
		var behind_occupied := (slot < 4 and board.has(slot + 1))
		if front_occupied and behind_occupied:
			return false

	return true

## Scores the synergistic fit of placing unit_id at slot given the currently occupied board and active trinkets.
static func score_unit_in_slot(unit_id: StringName, slot: int, board: Dictionary, active_trinket_ids: Array[StringName]) -> float:
	if not is_unit_enemy_draftable(unit_id):
		return 0.0

	var prof: Dictionary = UNIT_PROFILES.get(unit_id, {})
	if prof.is_empty():
		return 10.0

	var preferred_slots: Array = prof.get("preferred_slots", [])
	var score: float = 50.0 if preferred_slots.has(slot) else 1.0

	var front_partners: Array = prof.get("front_partners", [])
	var front_neighbor: StringName = board.get(slot - 1, &"")
	if slot == 0 or front_neighbor == &"":
		if front_partners.has(&"EMPTY"):
			score += 40.0
	else:
		if front_partners.has(front_neighbor):
			score += 40.0
		var front_prof_behind: Array = get_behind_partners(front_neighbor)
		if front_prof_behind.has(unit_id):
			score += 40.0

	var behind_partners: Array = prof.get("behind_partners", [])
	var behind_neighbor: StringName = board.get(slot + 1, &"")
	if slot == 4 or behind_neighbor == &"":
		if behind_partners.has(&"EMPTY"):
			score += 40.0
	else:
		if behind_partners.has(behind_neighbor):
			score += 40.0
		var behind_prof_front: Array = get_front_partners(behind_neighbor)
		if behind_prof_front.has(unit_id):
			score += 40.0

	# Directional deathrattle anti-pattern penalty:
	# If Puffcorn (ASpeFod) is placed directly behind a Tank, but has NO ally behind it,
	# its deathrattle will pass to nobody after the tank dies!
	if unit_id == &"ASpeFod" and slot > 0:
		var ally_in_front: StringName = board.get(slot - 1, &"")
		if ally_in_front == &"EFTnkMec" or ally_in_front == &"ETnkPla":
			if slot == 4 or not board.has(slot + 1):
				score = maxf(0.1, score - 60.0)

	# Bidirectional Trinket Weighting: x3 per matching active secondary trinket
	var trinket_votes: Array = prof.get("trinket_votes", [])
	for t_id in active_trinket_ids:
		if trinket_votes.has(t_id):
			score *= 3.0

	return score

## Tallies votes from units on board for eligible 5G Secondary Trinkets and picks the highest-voted.
static func select_best_voted_trinket(board: Dictionary, owned_trinkets: Array[StringName], rng: SeededRNG, equipped_units: Array[EncounterDraftUnit] = []) -> StringName:
	var votes: Dictionary = {} # StringName -> int

	for slot_idx in board.keys():
		var u_id: StringName = board[slot_idx]
		var prof: Dictionary = UNIT_PROFILES.get(u_id, {})
		if prof.is_empty():
			continue
		var u_votes: Array = prof.get("trinket_votes", [])
		for t_id in u_votes:
			if owned_trinkets.has(t_id):
				continue
			votes[t_id] = votes.get(t_id, 0) + 1

		if int(slot_idx) == 0:
			var slot_0_votes: Array = prof.get("slot_0_trinket_votes", [])
			for t_id in slot_0_votes:
				if owned_trinkets.has(t_id):
					continue
				votes[t_id] = votes.get(t_id, 0) + 1

	if votes.is_empty():
		return &""

	# Filter out trait Crests that don't have at least 2 matching trait souls/units on board
	var trait_counts: Dictionary = _count_trait_souls_on_board(board)
	if not equipped_units.is_empty():
		trait_counts.clear()
		for trait_name: StringName in BannerDrafter.TRAIT_MAP:
			var crest: StringName = BannerDrafter.get_trait_crest(trait_name)
			votes.erase(crest)
			var unit_votes: int = 0
			var count: int = 0
			for unit: EncounterDraftUnit in equipped_units:
				var contribution: int = unit.trait_count(trait_name)
				count += contribution
				unit_votes += 1 if contribution > 0 else 0
			trait_counts[String(trait_name).to_upper()] = count
			if unit_votes > 0 and not owned_trinkets.has(crest):
				votes[crest] = unit_votes
	var filtered_votes: Dictionary = {}
	for t_id in votes.keys():
		var definition: TrinketDefinition = Database.get_definition(t_id) as TrinketDefinition
		assert(definition != null, "Unknown enemy trinket vote %s" % t_id)
		if definition.is_player_exclusive or definition.is_banner or t_id in [&"trinket_trait_specialist", &"trinket_trait_mercenary", &"trinket_trait_novice"]:
			continue
		var t_id_str: String = String(t_id)
		if t_id_str.begins_with("trinket_trait_"):
			var trait_name: String = t_id_str.trim_prefix("trinket_trait_").to_upper()
			var levels: Array = C.TRAIT_DEFINITIONS[trait_name]["levels"]
			if trait_counts.get(trait_name, 0) < int(levels[0]["min"]):
				continue
		filtered_votes[t_id] = votes[t_id]

	if filtered_votes.is_empty():
		return &""

	# Find highest vote count
	var max_votes: int = -1
	for t_id in filtered_votes.keys():
		var v: int = int(filtered_votes[t_id])
		if v > max_votes:
			max_votes = v

	var top_candidates: Array[StringName] = []
	for t_id in filtered_votes.keys():
		if int(filtered_votes[t_id]) == max_votes:
			top_candidates.append(t_id)

	assert(not top_candidates.is_empty(), "EncounterSynergyRegistry: top_candidates must not be empty")
	if top_candidates.size() == 1:
		return top_candidates[0]

	# StringName's default order uses internal identity, which varies between runs.
	# Compare the text so the same seeded index always selects the same trinket.
	top_candidates.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	var pick_idx: int = rng.randi_range(0, top_candidates.size() - 1)
	return top_candidates[pick_idx]

static func _count_trait_souls_on_board(board: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for slot_idx in board.keys():
		var u_id: StringName = board[slot_idx]
		var def = Database.get_definition(u_id)
		if not is_instance_valid(def):
			continue
		for tag in def.tags:
			match tag:
				&"SOUL_FIRE":
					counts["FIRE"] = counts.get("FIRE", 0) + 1
				&"SOUL_EARTH":
					counts["EARTH"] = counts.get("EARTH", 0) + 1
				&"SOUL_WATER":
					counts["WATER"] = counts.get("WATER", 0) + 1
				&"SOUL_AIR":
					counts["AIR"] = counts.get("AIR", 0) + 1
				_:
					var upper = String(tag).to_upper()
					counts[upper] = counts.get(upper, 0) + 1
	return counts
