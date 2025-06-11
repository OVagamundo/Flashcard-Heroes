# res://scripts/GachaBallInstance.gd
extends Resource
class_name GachaBallInstance

enum LocationState {
	UNDEFINED,
	IN_MASTER_RUN_POOL_TIER_1,
	IN_MASTER_RUN_POOL_TIER_2,
	IN_MASTER_RUN_POOL_TIER_3,
	IN_BATTLE_GACHA_POOL_TIER_1,
	IN_BATTLE_GACHA_POOL_TIER_2,
	IN_BATTLE_GACHA_POOL_TIER_3,
	IN_PLAYER_BENCH,
	IN_PLAYER_LINEUP,
	IN_ENEMY_LINEUP,
	IN_BATTLE_INVENTORY,
	EQUIPPED_ON_UNIT,
	IN_BATTLE_DISCARD_PILE
}

var definition_id: StringName
var ball_uuid: String
var current_hp: int
var current_pwr: int

func initialize(def: GachaBallDefinition) -> void:
	definition_id = def.id
	ball_uuid = Crypto.new().generate_random_bytes(16).hex_encode()
	current_hp = def.base_hp
	current_pwr = def.base_pwr
