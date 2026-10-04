class_name ReplayReader
extends RefCounted

const CURRENT_SCHEMA_VERSION := 3

## Reads one JSON object per line. Errors retain the source line for diagnostics.
static func read_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"error": "Could not open replay: %s" % error_string(FileAccess.get_open_error())}

	var header: Dictionary = {}
	var events: Array[Dictionary] = []
	var legacy_rng_state_precision := false
	var line_number := 0
	while not file.eof_reached():
		var line := file.get_line()
		line_number += 1
		if line.strip_edges().is_empty():
			continue
		# Older recordings wrote uint64 RNG states as JSON numbers. Godot parses
		# large JSON numbers through floating point, which rounds those values.
		# Quote the raw decimal tokens before parsing so older replays restore the
		# exact RNG bit pattern too. New recordings already store them as strings.
		if line.contains("\"rng_state\""):
			var precision_safe_line := _quote_large_rng_state_numbers(line)
			legacy_rng_state_precision = legacy_rng_state_precision or precision_safe_line != line
			line = precision_safe_line

		var json := JSON.new()
		var parse_error := json.parse(line)
		if parse_error != OK:
			file.close()
			return {"error": "Malformed JSON at line %d: %s" % [line_number, json.get_error_message()]}
		if not json.data is Dictionary:
			file.close()
			return {"error": "Replay line %d is not a JSON object." % line_number}

		var payload: Dictionary = json.data
		if header.is_empty():
			if String(payload.get("event_class", "")) != "RunHeader":
				file.close()
				return {"error": "Replay line %d is not a RunHeader." % line_number}
			var schema_version := int(payload.get("schema_version", 0))
			if schema_version > CURRENT_SCHEMA_VERSION:
				file.close()
				return {"error": "Replay schema %d is newer than supported schema %d." % [schema_version, CURRENT_SCHEMA_VERSION]}
			if schema_version < 1:
				file.close()
				return {"error": "Replay header has no supported schema version."}
			header = payload
			header["_legacy_rng_state_precision"] = legacy_rng_state_precision
		else:
			payload["_line_number"] = line_number
			events.append(payload)
			if legacy_rng_state_precision:
				header["_legacy_rng_state_precision"] = true

	file.close()
	if header.is_empty():
		return {"error": "Replay file is empty."}
	return {"header": header, "events": events, "error": ""}

static func _quote_large_rng_state_numbers(line: String) -> String:
	var regex := RegEx.new()
	if regex.compile("(\"state\"\\s*:\\s*)(-?[0-9]{16,})") != OK:
		return line
	var matches := regex.search_all(line)
	for match_index in range(matches.size() - 1, -1, -1):
		var state_match: RegExMatch = matches[match_index]
		var start := state_match.get_start(2)
		var length := state_match.get_end(2) - start
		line = line.substr(0, start) + "\"" + line.substr(start, length) + "\"" + line.substr(start + length)
	return line
