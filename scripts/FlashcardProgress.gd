# res://scripts/FlashcardProgress.gd
@tool
class_name FlashcardProgress extends Resource

## Reference to the FlashcardDefinition
@export var definition_id: StringName

## Current mastery level (0-5)
@export var mastery_level: int = 0

## Last day this card was reviewed (for SRS algorithm)
@export var last_review_day: int = 0

## Record an answer and update progress
## @param was_correct: bool - Whether the answer was correct
## @param current_day: int - The current day of the run
func record_answer(was_correct: bool, current_day: int) -> void:
	last_review_day = current_day
	
	if was_correct:
		mastery_level = min(5, mastery_level + 1)
	else:
		mastery_level = max(0, mastery_level - 1)