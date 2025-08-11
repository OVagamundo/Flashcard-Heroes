<!-- Original: scripts/FlashcardDefinition.gd -->

```gdscript
@tool
class_name FlashcardDefinition extends Resource

## Unique identifier for this flashcard
@export var id: StringName

## The flashcard question text
@export var question: String

## The flashcard answer text
@export var answer: String

## Detailed explanation (optional)
@export var explanation: String 
```