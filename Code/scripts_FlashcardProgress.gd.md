<!-- Original: scripts/FlashcardProgress.gd -->

```gdscript
# res://scripts/FlashcardProgress.gd
extends Resource
class_name FlashcardProgress

## Tracks run-specific progress for a single flashcard.
## Properties as defined in TDD Section 2.1

@export var definition_id: StringName
@export var mastery_level: int = 0
@export var last_review_day: int = 0

## Additional properties for SRS algorithm
@export var total_reviews: int = 0
@export var correct_answers: int = 0
@export var incorrect_answers: int = 0

func get_accuracy() -> float:
	"""Returns the accuracy percentage for this card"""
	if total_reviews == 0:
		return 0.0
	return float(correct_answers) / float(total_reviews) * 100.0

func record_answer(was_correct: bool, current_day: int) -> void:
	"""Records an answer and updates progress"""
	total_reviews += 1
	last_review_day = current_day
	
	if was_correct:
		correct_answers += 1
		# Increase mastery level (capped at 5)
		mastery_level = min(mastery_level + 1, 5)
	else:
		incorrect_answers += 1
		# Decrease mastery level (capped at 0)
		mastery_level = max(mastery_level - 1, 0) 
```