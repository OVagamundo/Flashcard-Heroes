extends RefCounted

## Builds a stable digest from gameplay state at an action completion boundary.
## Dictionary key order is normalized before hashing so equivalent state does not
## depend on resource or container insertion order.
static func current_digest() -> String:
	if not is_instance_valid(GameManager) or not GameManager.has_method("get_replay_state_snapshot"):
		return ""
	return digest(GameManager.get_replay_state_snapshot())

static func digest(value: Variant) -> String:
	var normalized: Variant = _normalize(value)
	return str(hash(JSON.stringify(normalized)))

static func _normalize(value: Variant) -> Variant:
	if value is Dictionary:
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return str(a) < str(b)
		)
		var normalized: Dictionary = {}
		var is_rng_stream: bool = value.has("name") and value.has("seed") and value.has("state")
		for key in keys:
			if is_rng_stream and str(key) == "state":
				# Keep digest values compatible with recordings made before RNG
				# states switched from JSON numbers to exact decimal strings.
				normalized[str(key)] = int(str(value[key]))
			else:
				normalized[str(key)] = _normalize(value[key])
		return normalized
	if value is Array:
		var normalized_array: Array = []
		for item in value:
			normalized_array.append(_normalize(item))
		return normalized_array
	if value is float:
		if value == floor(value):
			# JSON parsing can turn integer tokens in untyped dictionaries into
			# integral floats. Treat numerically identical values consistently.
			return int(value)
		return snappedf(value, 0.00001)
	if typeof(value) == TYPE_OBJECT:
		if value == null or not is_instance_valid(value):
			return null
		if value.has_method("to_dict"):
			return _normalize(value.to_dict())
		if value.has_method("to_save_dict"):
			return _normalize(value.to_save_dict())
		if value is Resource and not value.resource_path.is_empty():
			return value.resource_path
		return ""
	return value
