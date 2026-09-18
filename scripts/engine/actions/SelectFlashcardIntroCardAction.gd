# res://scripts/engine/actions/SelectFlashcardIntroCardAction.gd
class_name SelectFlashcardIntroCardAction
extends GameAction

## Dispatched when clicking a priority card button during new card intro in the flashcard minigame.
## Updates the displayed card and highlight state.

var card_id: StringName = &""

func _init(p_card_id: StringName = &"") -> void:
	super._init(&"SelectFlashcardIntroCardAction")
	card_id = p_card_id

func validate() -> bool:
	return not card_id.is_empty()

func execute() -> void:
	var minigame = Engine.get_main_loop().root.find_child("FlashcardMinigame", true, false)
	if is_instance_valid(minigame) and minigame.has_method("execute_select_intro_card"):
		minigame.execute_select_intro_card(card_id)

func yields_for_visuals() -> bool:
	return false

func to_dict() -> Dictionary:
	var d := super.to_dict()
	d["card_id"] = String(card_id)
	return d

func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	card_id = StringName(data.get("card_id", ""))
