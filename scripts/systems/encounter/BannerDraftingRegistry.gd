# res://scripts/systems/encounter/BannerDraftingRegistry.gd
class_name BannerDraftingRegistry
extends RefCounted

static var _drafters: Dictionary = {
	&"trinket_banner_lone_whale": LoneWhaleBannerDrafter.new(),
	&"trinket_banner_swarm": SwarmBannerDrafter.new(),
	&"trinket_banner_fire_phalanx": FireBannerDrafter.new(),
	&"trinket_banner_earth": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Earth")),
	&"trinket_banner_water": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Water")),
	&"trinket_banner_air": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Air")),
	&"trinket_banner_tank": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Tank")),
	&"trinket_banner_fighter": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Fighter")),
	&"trinket_banner_support": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Support")),
	&"trinket_banner_plant": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Plant")),
	&"trinket_banner_food": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Food")),
	&"trinket_banner_animal": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Animal")),
	&"trinket_banner_mecha": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Mecha")),
	&"trinket_banner_toy": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Toy")),
	&"trinket_banner_appliance": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Appliance")),
	&"trinket_banner_costume": TraitBannerDrafter.new(EnemyTraitBannerProfiles.create(&"Costume")),
	&"trinket_banner_burnie": BurnieBannerDrafter.new(),
	&"trinket_banner_slimeblob": SlimeblobBannerDrafter.new(),
	&"trinket_banner_dustmon": DustmonBannerDrafter.new(),
	&"trinket_banner_toughmon": ToughmonBannerDrafter.new(),
	&"trinket_banner_doppelkun": DoppelkunBannerDrafter.new(),
}

static var _entity_to_banner: Dictionary = {
	&"elite_slimeblob": &"trinket_banner_slimeblob",
	&"elite_burnie": &"trinket_banner_burnie",
	&"boss_dustmon": &"trinket_banner_dustmon",
	&"boss_toughmon": &"trinket_banner_toughmon",
	&"boss_doppelkun": &"trinket_banner_doppelkun",
}

static func has_drafter(banner_id: StringName) -> bool:
	return _drafters.has(banner_id)

static func get_banner_for_entity(entity_id: StringName) -> StringName:
	assert(_entity_to_banner.has(entity_id), "BannerDraftingRegistry: Unknown entity %s" % entity_id)
	return _entity_to_banner[entity_id]

static func get_drafter(banner_id: StringName) -> BannerDrafter:
	assert(_drafters.has(banner_id), "BannerDraftingRegistry: No drafter registered for banner %s" % banner_id)
	return _drafters[banner_id]

static func get_drafter_for_entity(entity_id: StringName) -> BannerDrafter:
	var banner_id: StringName = get_banner_for_entity(entity_id)
	return get_drafter(banner_id)

static func regular_banner_ids(budget: int) -> Array[StringName]:
	var result: Array[StringName] = [&"trinket_banner_lone_whale", &"trinket_banner_swarm"]
	for trait_name: StringName in EnemyTraitBannerProfiles.TRAITS:
		var profile: EnemyTraitBannerProfile = EnemyTraitBannerProfiles.create(trait_name)
		var drafter: TraitBannerDrafter = get_drafter(profile.banner_id) as TraitBannerDrafter
		assert(drafter != null, "Trait banner registered with the wrong drafter: %s" % profile.banner_id)
		if drafter.minimum_budget() <= budget:
			result.append(profile.banner_id)
	return result
