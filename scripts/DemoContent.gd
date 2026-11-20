extends Node

## Runtime content access for the public demo build.

const DEMO_HERO_IDS: Array[StringName] = [&"hero_starter", &"hero_bounty_hunter"]
const DEMO_DECK_IDS: Array[StringName] = [&"katakana_main", &"hiragana_main"]

var demo_mode: bool = true


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O and event.ctrl_pressed and event.shift_pressed:
		demo_mode = not demo_mode
		SignalBus.title_scene_requested.emit()
		get_viewport().set_input_as_handled()


func is_demo_mode() -> bool:
	return demo_mode


func is_hero_unlocked(hero_id: StringName) -> bool:
	return not demo_mode or DEMO_HERO_IDS.has(hero_id)


func is_deck_unlocked(deck_id: StringName) -> bool:
	return not demo_mode or DEMO_DECK_IDS.has(deck_id)
