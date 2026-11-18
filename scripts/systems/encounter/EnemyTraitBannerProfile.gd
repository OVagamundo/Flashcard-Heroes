class_name EnemyTraitBannerProfile
extends Resource

## A curated strategy: package membership authorizes the specific off-trait partners.
@export var banner_id: StringName
@export var trait_name: StringName
@export var package_ids: Array[StringName] = []
@export var wave_fraction: float = 0.33

func crest() -> StringName:
	return BannerDrafter.get_trait_crest(trait_name)

func emblem() -> StringName:
	return BannerDrafter.get_trait_emblem(trait_name)

func threshold() -> int:
	return 3 if trait_name in [&"Fire", &"Earth", &"Water", &"Air"] else 2

func native_unit(unit_id: StringName) -> bool:
	return BannerDrafter.unit_has_trait(unit_id, trait_name)

func filler_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for unit_id: StringName in EncounterSynergyRegistry.UNIT_PROFILES:
		if unit_id in [&"WATnkAni", &"FFWASupMec", &"EEFASpeCos"]:
			continue # Empty-space, item-transfer and transformation strategies need packages.
		if EncounterSynergyRegistry.is_unit_enemy_draftable(unit_id) and native_unit(unit_id):
			result.append(unit_id)
	# Candidate order must survive save/continue in a fresh process.
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return String(a) < String(b)
	)
	return result

func packages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for package_id: StringName in package_ids:
		result.append(EncounterSynergyRegistry.get_package(package_id))
	return result
