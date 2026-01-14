# res://scripts/FlashcardProgress.gd
@tool
class_name FlashcardProgress extends Resource

## Mastery level bounds (1-5 scale)
const MASTERY_MIN: int = 1
const MASTERY_MAX: int = 5

## Mastery labels indexed by level (1-5)
const MASTERY_LABELS: Array[String] = ["", "Very Hard", "Hard", "Medium", "Easy", "Very Easy"]

## Mastery colors indexed by level (1-5)
## 1: Red (Very Hard), 2: Orange (Hard), 3: Yellow (Medium), 4: Green (Easy), 5: Blue (Very Easy)
const MASTERY_COLORS: Array[Color] = [
	Color.WHITE, # Index 0 (unused)
	Color(0.9, 0.2, 0.2), # 1: Red (Very Hard)
	Color(0.95, 0.5, 0.1), # 2: Orange (Hard)
	Color(0.95, 0.8, 0.1), # 3: Yellow (Medium)
	Color(0.2, 0.8, 0.2), # 4: Green (Easy)
	Color(0.2, 0.4, 0.9) # 5: Blue (Very Easy)
]

## Reference to the FlashcardDefinition
@export var definition_id: StringName

## Current mastery level (1-5, starts at 1 = Very Hard)
@export var mastery_level: int = MASTERY_MIN

## Last day this card was reviewed (for SRS algorithm)
@export var last_review_day: int = 0

## Total number of times this card has been reviewed
@export var times_reviewed: int = 0

## Get the color associated with the current mastery level
func get_mastery_color() -> Color:
	return MASTERY_COLORS[clampi(mastery_level, MASTERY_MIN, MASTERY_MAX)]

## Get the label associated with the current mastery level
func get_mastery_label() -> String:
	return MASTERY_LABELS[clampi(mastery_level, MASTERY_MIN, MASTERY_MAX)]

## Record an answer and update progress
## @param was_correct: bool - Whether the answer was correct
## @param current_day: int - The current day of the run
func record_answer(was_correct: bool, current_day: int) -> void:
	last_review_day = current_day
	times_reviewed += 1
	
	if was_correct:
		mastery_level = mini(MASTERY_MAX, mastery_level + 1)
	else:
		mastery_level = maxi(MASTERY_MIN, mastery_level - 1)