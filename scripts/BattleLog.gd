extends RichTextLabel

const MAX_LINES = 15
var _lines: Array[String] = []

func _ready() -> void:
	# Connect to the battle log event signal from the BattleManager
	# Note: This assumes BattleManager is emitting this global signal.
	# A more robust solution might use a direct connection if a reference is available.
	SignalBus.battle_log_event.connect(add_message)

func add_message(message: String) -> void:
	# Add a timestamp or turn number for clarity
	var new_line = "- %s" % message
	_lines.push_back(new_line)

	# Keep the log from getting too long
	if _lines.size() > MAX_LINES:
		_lines.pop_front()

	# Update the RichTextLabel content
	text = ""
	for line in _lines:
		text += line + "\n"

	# Scroll to the bottom to show the latest message
	scroll_to_line(get_line_count() - 1)
