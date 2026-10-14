class_name DescriptionParser
extends Object

const KEYWORDS = {
	"ARMOR": {"color": "#4488FF", "meta": "effect_armor", "variants": ["ARMOR", "ARMADURA", "ARMADURAS"]},
	"SPIKES": {"color": "#44CC44", "meta": "effect_spikes", "variants": ["SPIKES", "SPIKE", "ESPINHOS", "ESPINHO", "THORN", "THORNS"]},
	"BURN": {"color": "#FF8800", "meta": "effect_burn", "variants": ["BURN", "CHAMAS", "CHAMA"]},
	"STATIC": {"color": "#FFEE00", "meta": "effect_static", "variants": ["STATIC", "ESTÁTICO", "ESTATICO"]},
}

static func find_keywords(text: String) -> Array[String]:
	var found: Array[String] = []
	if text.is_empty():
		return found
	for key in KEYWORDS:
		for variant in KEYWORDS[key].variants:
			var regex = RegEx.new()
			regex.compile("(?i)\\b" + variant + "\\b")
			if regex.search(text) != null:
				if not found.has(key):
					found.append(key)
				break
	return found

static func parse(text: String, exclude_meta: String = "", enable_urls: bool = false) -> String:
	var result = text
	
	# We want to process all variants across all keyword types.
	# Sort all variants by length descending to prevent partial matches.
	var all_variants = []
	var variant_to_key = {}
	for key in KEYWORDS:
		for v in KEYWORDS[key].variants:
			all_variants.append(v)
			variant_to_key[v] = key
	
	all_variants.sort_custom(func(a, b): return a.length() > b.length())
	
	for variant in all_variants:
		var key = variant_to_key[variant]
		var config = KEYWORDS[key]
		var meta_to_use = config.meta if enable_urls else ""
		if not exclude_meta.is_empty() and config.meta == exclude_meta:
			meta_to_use = ""
		
		result = _replace_keyword(result, variant, config.color, meta_to_use)
		
	return result

static func _replace_keyword(text: String, word: String, color: String, meta: String) -> String:
	var regex = RegEx.new()
	# \b ensures word boundaries. Case insensitive.
	regex.compile("(?i)\\b" + word + "\\b")
	
	# Use a function to replace while keeping the matched word to convert it to upper case
	# and wrap with BBCode.
	var matches = regex.search_all(text)
	# Iterate backwards to not invalidate indices
	for i in range(matches.size() - 1, -1, -1):
		var m = matches[i]
		var matched_str = m.get_string()
		
		var start = m.get_start()
		var end = m.get_end()
		
		# Check if the match is inside a [url] tag already
		var prefix = text.left(start)
		if prefix.count("[url=") > prefix.count("[/url]"):
			continue

		var replacement = ""
		if meta.is_empty():
			replacement = "[b][color=%s]%s[/color][/b]" % [color, matched_str.to_upper()]
		else:
			replacement = "[b][color=%s][url=%s]%s[/url][/color][/b]" % [color, meta, matched_str.to_upper()]
			
		text = text.left(start) + replacement + text.right(-end)
	
	return text
