# res://scripts/systems/encounter/drafters/FireBannerDrafter.gd
class_name FireBannerDrafter
extends TraitBannerDrafter

func _init() -> void:
	super(EnemyTraitBannerProfiles.create(&"Fire"))

func draft_lineup(budget: int, context: Dictionary = {}) -> EncounterDefinition:
	var reserved_slot: int = int(context.get("preplaced_burnie_slot", -1))
	if reserved_slot == -1:
		return super.draft_lineup(budget, context)
	var burnie := EncounterDraftUnit.new(&"elite_burnie", reserved_slot)
	burnie.reserved = true
	return draft_with_reserved(budget, burnie, &"trinket_banner_burnie")
