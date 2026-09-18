# res://scripts/engine/actions/ActionFactory.gd
class_name ActionFactory
extends RefCounted

## Central factory for deserializing GameActions from dictionary payloads.
## Fails fast with descriptive error on unknown action types.

static var _action_map: Dictionary = {}

static func _get_action_map() -> Dictionary:
	if _action_map.is_empty():
		_action_map = {
			"SelectPathAction": SelectPathAction,
			"MoveInventoryAction": MoveInventoryAction,
			"ConfirmMergeAction": ConfirmMergeAction,
			"MergeEncounterAction": MergeEncounterAction,
			"ConfirmSwapAction": ConfirmSwapAction,
			"DrawGachaAction": DrawGachaAction,
			"EndTurnAction": EndTurnAction,
			"AcknowledgeBattleResultsAction": AcknowledgeBattleResultsAction,
			"SetCombatSpeedAction": SetCombatSpeedAction,
			"PauseRunAction": PauseRunAction,
			"AcknowledgeFlashcardIntroAction": AcknowledgeFlashcardIntroAction,
			"SelectFlashcardIntroCardAction": SelectFlashcardIntroCardAction,
			"SubmitFlashcardAnswerAction": SubmitFlashcardAnswerAction,
			"SkipFlashcardAction": SkipFlashcardAction,
			"DismissTutorialAction": DismissTutorialAction,
			"BuyShopAction": BuyShopAction,
			"RerollShopAction": RerollShopAction,
			"LeaveShopAction": LeaveShopAction,
			"DrawRewardAction": DrawRewardAction,
			"CollectRewardAction": CollectRewardAction,
			"SellRewardAction": SellRewardAction,
			"StudyRewardAction": StudyRewardAction,
			"LeaveRewardAction": LeaveRewardAction,
			"DrawRestSiteAction": DrawRestSiteAction,
			"UpgradeRestSiteAction": UpgradeRestSiteAction,
			"ClaimRestSiteGoldAction": ClaimRestSiteGoldAction,
			"StudyRestSiteAction": StudyRestSiteAction,
			"LeaveRestSiteAction": LeaveRestSiteAction,
			"StartTrainingAction": StartTrainingAction,
			"TrainUnitStatAction": TrainUnitStatAction,
			"CloseTrainingPopupAction": CloseTrainingPopupAction,
			"LeaveTrainingAction": LeaveTrainingAction,
			"RemoveBlackMarketAction": RemoveBlackMarketAction,
			"TransformBlackMarketAction": TransformBlackMarketAction,
			"LeaveBlackMarketAction": LeaveBlackMarketAction,
			"LeaveMergeEncounterAction": LeaveMergeEncounterAction,
			"AcknowledgeRunCompleteAction": AcknowledgeRunCompleteAction
		}
	return _action_map

static func create_from_dict(data: Dictionary) -> GameAction:
	var action_type := String(data.get("action_type", ""))
	var map := _get_action_map()
	if not map.has(action_type):
		push_error("[ActionFactory] Unknown action type: '%s'. Valid types: %s" % [action_type, str(map.keys())])
		return null

	var action_class = map[action_type]
	var action: GameAction = action_class.new()
	action.from_dict(data)
	return action
