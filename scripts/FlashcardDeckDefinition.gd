# res://scripts/FlashcardDeckDefinition.gd
@tool
class_name FlashcardDeckDefinition
extends Resource

## Defines a flashcard deck for the educational component of the game.

## Unique identifier for the deck.
@export var id: StringName

## Localization key for the deck's display name.
@export var display_name_key: String

## MVP Placeholder: A list of question/answer pairs.
@export var card_list: Array[Dictionary] # e.g., [{"question": "Q1", "answer": "A1"}]
