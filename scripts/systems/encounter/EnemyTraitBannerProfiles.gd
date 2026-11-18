class_name EnemyTraitBannerProfiles
extends RefCounted

const TRAITS: Array[StringName] = [&"Fire", &"Earth", &"Water", &"Air", &"Tank", &"Fighter", &"Support", &"Plant", &"Food", &"Animal", &"Mecha", &"Toy", &"Appliance", &"Costume"]

## Each approved package supplies a real trigger, beneficiary or protection relationship.
## Emblems are assigned only within these packages (or repairs of these packages).
const PACKAGES: Dictionary[StringName, Array] = {
	&"Fire": [&"pair_branblee_ripplepup", &"pair_pepspray_ripplepup", &"triplet_fire_branblee_ripplepup_pepspray", &"pair_puffcorn_vulcannon", &"pair_branblee_vulcannon", &"pair_relaytron_tsunamantle"],
	&"Earth": [&"pair_stumpling_ripplepup", &"pair_branblee_ripplepup", &"pair_stumpling_branblee", &"triplet_oakbark_bogmantle_nuton", &"pair_branblee_komatop"],
	&"Water": [&"pair_stumpling_ripplepup", &"pair_branblee_ripplepup", &"pair_pepspray_ripplepup", &"pair_reizokun_ripplepup", &"pair_reizokun_komatop", &"pair_komatop_pachinkannon"],
	&"Air": [&"pair_puffcorn_vulcannon", &"pair_griffoam_pachinkannon", &"pair_matryodust_mechamom", &"pair_matryoshkan_mechamom", &"pair_reizokun_komatop"],
	&"Tank": [&"pair_stumpling_ripplepup", &"pair_branblee_ripplepup", &"pair_branblee_komatop", &"pair_reizokun_ripplepup", &"pair_reizokun_komatop", &"triplet_oakbark_bogmantle_nuton", &"pair_nuton_ripplepup"],
	&"Fighter": [&"pair_puffcorn_vulcannon", &"pair_puffcorn_bogmantle", &"pair_matryodust_bogmantle", &"pair_griffoam_pachinkannon", &"pair_komatop_pachinkannon"],
	&"Support": [&"pair_stumpling_ripplepup", &"pair_matryodust_mechamom", &"pair_matryoshkan_mechamom", &"triplet_oakbark_bogmantle_nuton"],
	&"Plant": [&"pair_stumpling_ripplepup", &"pair_branblee_ripplepup", &"triplet_oakbark_bogmantle_nuton", &"pair_nuton_ripplepup"],
	&"Food": [&"pair_stumpling_pepspray", &"triplet_stumpling_pepspray_nuton", &"pair_pepspray_ripplepup", &"pair_puffcorn_bogmantle", &"pair_bogmantle_nuton", &"triplet_puffcorn_bogmantle_nuton"],
	&"Animal": [&"pair_stumpling_ripplepup", &"pair_branblee_ripplepup", &"pair_pepspray_ripplepup", &"pair_reizokun_ripplepup", &"pair_griffoam_pachinkannon"],
	&"Mecha": [&"pair_branblee_ripplepup", &"pair_branblee_vulcannon", &"pair_matryodust_mechamom", &"pair_matryoshkan_mechamom", &"pair_komatop_pachinkannon", &"pair_relaytron_vulcannon"],
	&"Toy": [&"pair_matryodust_bogmantle", &"pair_matryodust_mechamom", &"pair_matryoshkan_mechamom", &"pair_komatop_pachinkannon", &"pair_reizokun_komatop"],
	&"Appliance": [&"pair_reizokun_ripplepup", &"pair_reizokun_komatop", &"pair_stumpling_sojikun", &"pair_sojikun_pachinkannon"],
	&"Costume": [&"pair_puffcorn_bogmantle", &"pair_matryodust_bogmantle", &"pair_bogmantle_nuton", &"triplet_puffcorn_bogmantle_nuton"],
}

static func create(trait_name: StringName) -> EnemyTraitBannerProfile:
	assert(TRAITS.has(trait_name), "Unsupported enemy banner trait_name %s" % trait_name)
	var profile := EnemyTraitBannerProfile.new()
	profile.trait_name = trait_name
	profile.banner_id = &"trinket_banner_fire_phalanx" if trait_name == &"Fire" else StringName("trinket_banner_" + String(trait_name).to_lower())
	profile.package_ids.assign(PACKAGES[trait_name])
	profile.wave_fraction = 0.50 if trait_name == &"Fire" else 0.33
	return profile
