class_name DescriptionParser
extends Object

const KEYWORDS = {
	"ARMOR": {
		"color": "#1D4ED8",
		"meta": "effect_armor",
		"name_key": "STATUS_ARMOR",
		"desc_key": "STATUS_ARMOR_DESC",
		"variants": ["ARMOR", "ARMADURA", "ARMADURAS"]
	},
	"SPIKES": {
		"color": "#15803D",
		"meta": "effect_spikes",
		"name_key": "STATUS_SPIKES",
		"desc_key": "STATUS_SPIKES_DESC",
		"variants": ["SPIKES", "SPIKE", "ESPINHOS", "ESPINHO", "THORN", "THORNS"]
	},
	"BURN": {
		"color": "#C2410C",
		"meta": "effect_burn",
		"name_key": "STATUS_BURN",
		"desc_key": "STATUS_BURN_DESC",
		"variants": ["BURN", "CHAMAS", "CHAMA"]
	},
	"STATIC": {
		"color": "#B45309",
		"meta": "effect_static",
		"name_key": "STATUS_STATIC",
		"desc_key": "STATUS_STATIC_DESC",
		"variants": ["STATIC", "ESTÁTICO", "ESTATICO"]
	},
	"BOUNTY": {
		"color": "#92400E",
		"meta": "effect_bounty",
		"name_key": "STATUS_BOUNTY",
		"desc_key": "STATUS_BOUNTY_DESC",
		"variants": ["BOUNTY", "RECOMPENSA"]
	},
	"REINFORCE": {
		"color": "#0E7490",
		"meta": "effect_reinforce",
		"name_key": "STATUS_REINFORCE",
		"desc_key": "STATUS_REINFORCE_DESC",
		"variants": ["REINFORCE", "REFORÇO", "REFORCO"]
	},
	"SHOCKWAVE": {
		"color": "#7E22CE",
		"meta": "glossary_shockwave",
		"name_key": "GLOSSARY_SHOCKWAVE",
		"desc_key": "GLOSSARY_SHOCKWAVE_DESC",
		"variants": ["SHOCKWAVE", "SHOCKWAVES", "ONDA DE CHOQUE", "ONDAS DE CHOQUE"]
	},
	"MELEE": {
		"color": "#B91C1C",
		"meta": "glossary_melee",
		"name_key": "GLOSSARY_MELEE",
		"desc_key": "GLOSSARY_MELEE_DESC",
		"variants": ["MELEE ATTACK", "MELEE ATTACKS", "MELEE", "ATAQUE CORPO A CORPO", "ATAQUES CORPO A CORPO", "CORPO A CORPO"]
	},
	"RANGED": {
		"color": "#1D4ED8",
		"meta": "glossary_ranged",
		"name_key": "GLOSSARY_RANGED",
		"desc_key": "GLOSSARY_RANGED_DESC",
		"variants": ["RANGED ATTACK", "RANGED ATTACKS", "RANGED", "ATAQUE À DISTÂNCIA", "ATAQUE A DISTANCIA", "ATAQUES À DISTÂNCIA", "À DISTÂNCIA", "A DISTANCIA"]
	},
	"BOUNCE": {
		"color": "#0369A1",
		"meta": "glossary_bounce",
		"name_key": "GLOSSARY_BOUNCE",
		"desc_key": "GLOSSARY_BOUNCE_DESC",
		"variants": ["BOUNCE", "BOUNCES", "RICOCHETE", "RICOCHETES", "REBATE", "REBATER"]
	},
	"EXTRA_ATTACK": {
		"color": "#A16207",
		"meta": "glossary_extra_attack",
		"name_key": "GLOSSARY_EXTRA_ATTACK",
		"desc_key": "GLOSSARY_EXTRA_ATTACK_DESC",
		"variants": ["EXTRA ATTACK", "EXTRA ATTACKS", "ATAQUE EXTRA", "ATAQUES EXTRAS"]
	},
	"EXTRA_ACTION": {
		"color": "#C2410C",
		"meta": "glossary_extra_action",
		"name_key": "GLOSSARY_EXTRA_ACTION",
		"desc_key": "GLOSSARY_EXTRA_ACTION_DESC",
		"variants": ["EXTRA ACTION", "EXTRA ACTIONS", "AÇÃO EXTRA", "ACAO EXTRA", "AÇÕES EXTRAS", "ACOES EXTRAS"]
	},
	"EMPOWERED_ATTACK": {
		"color": "#C2410C",
		"meta": "glossary_empowered_attack",
		"name_key": "GLOSSARY_EMPOWERED_ATTACK",
		"desc_key": "GLOSSARY_EMPOWERED_ATTACK_DESC",
		"variants": ["EMPOWERED ATTACK", "EMPOWERED ATTACKS", "ATAQUE FORTALECIDO", "ATAQUES FORTALECIDOS"]
	},
	"INTERCEPT": {
		"color": "#166534",
		"meta": "glossary_intercept",
		"name_key": "GLOSSARY_INTERCEPT",
		"desc_key": "GLOSSARY_INTERCEPT_DESC",
		"variants": ["INTERCEPT", "INTERCEPTS", "INTERCEPTAR", "INTERCETAR", "INTERCEPTA"]
	},
	"LIFESTEAL": {
		"color": "#9F1239",
		"meta": "glossary_lifesteal",
		"name_key": "GLOSSARY_LIFESTEAL",
		"desc_key": "GLOSSARY_LIFESTEAL_DESC",
		"variants": ["LIFESTEAL", "ROUBO DE VIDA"]
	},
	"ATTACK_OVERRIDE": {
		"color": "#9A3412",
		"meta": "glossary_attack_override",
		"name_key": "GLOSSARY_ATTACK_OVERRIDE",
		"desc_key": "GLOSSARY_ATTACK_OVERRIDE_DESC",
		"variants": ["ATTACK OVERRIDE", "ATTACK OVERRIDES", "SUBSTITUIÇÃO DE ATAQUE", "SUBSTITUICAO DE ATAQUE"]
	},
}

const TRIGGER_HIGHLIGHT_HEX: String = "#9A3412"
const TRIGGER_PHRASES: Array[String] = [
	# EN (longest first)
	"When taking melee attack damage",
	"When taking ranged attack damage",
	"When any unit is knocked out",
	"When this unit is knocked out",
	"When an ally is knocked out",
	"When taking effect damage",
	"When taking status damage",
	"When taking melee damage",
	"When taking ranged damage",
	"When holder is knocked out",
	"Whenever a merge happens",
	"At the start of each turn",
	"When an enemy is summoned",
	"When an ally takes damage",
	"When an ally is summoned",
	"Before being knocked out",
	"Before taking damage",
	"At the start of turn",
	"When taking damage",
	"At the end of turn",
	"Prevents knockout",
	"Prevent knockout",
	"At minigame end",
	"When knocked out",
	"On knockout blow",
	"At battle start",
	"When attacking",
	"At turn start",
	"At turn end",
	"Pre-Battle",
	"Pre-battle",
	"Pre-combat",
	"When healed",
	# PT-BR (longest first)
	"Ao sofrer dano de ataque corpo a corpo",
	"Ao sofrer dano de ataque à distância",
	"Quando qualquer unidade é nocauteada",
	"Quando esta unidade é nocauteada",
	"Quando o portador é nocauteado",
	"Quando um aliado é nocauteado",
	"Ao sofrer dano corpo a corpo",
	"Ao sofrer dano à distância",
	"Sempre que uma fusão acontece",
	"Quando um inimigo é invocado",
	"Quando um aliado é invocado",
	"Ao sofrer dano de efeito",
	"Quando um aliado sofre dano",
	"No início de cada turno",
	"Antes de ser nocauteado",
	"Antes de ser nocauteada",
	"No início da batalha",
	"Antes de sofrer dano",
	"No início do turno",
	"Ao fim do minijogo",
	"Ao fim de minijogo",
	"Quando nocauteado",
	"Quando nocauteada",
	"Ao ser nocauteado",
	"Ao ser nocauteada",
	"Antes da batalha",
	"No final do turno",
	"Impede o nocaute",
	"Prevenir nocaute",
	"No fim do turno",
	"Ao sofrer dano",
	"Ao ser curado",
	"Ao ser curada",
	"Ao nocautear",
	"Pré-batalha",
	"Pré-combate",
	"Ao atacar"
]

static func get_keyword_info(kw: String) -> Dictionary:
	var upper_kw = kw.to_upper()
	if KEYWORDS.has(upper_kw):
		return KEYWORDS[upper_kw]
	for key in KEYWORDS:
		var cfg = KEYWORDS[key]
		if cfg.meta == kw:
			return cfg
		for v in cfg.variants:
			if v == upper_kw:
				return cfg
	return {}

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
		
	# Apply zero-tooltip inline highlighting to constitutional trigger phrases
	var sorted_phrases: Array[String] = TRIGGER_PHRASES.duplicate()
	sorted_phrases.sort_custom(func(a, b): return a.length() > b.length())
	for phrase in sorted_phrases:
		result = _replace_trigger_phrase(result, phrase, TRIGGER_HIGHLIGHT_HEX)
		
	return result

static func _replace_trigger_phrase(text: String, phrase: String, color: String) -> String:
	var regex = RegEx.new()
	regex.compile("(?i)\\b" + phrase + "\\b")
	var matches = regex.search_all(text)
	for i in range(matches.size() - 1, -1, -1):
		var m = matches[i]
		var matched_str = m.get_string()
		var start = m.get_start()
		var end = m.get_end()
		
		# Check if match is inside an existing [color] or [url] tag already
		var prefix = text.left(start)
		if prefix.count("[color=") > prefix.count("[/color]") or prefix.count("[url=") > prefix.count("[/url]"):
			continue
		
		var replacement = "[color=%s][b]%s[/b][/color]" % [color, matched_str]
		text = text.left(start) + replacement + text.right(-end)
	return text

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
		
		# Check if the match is inside a [url] tag or [color] tag already
		var prefix = text.left(start)
		if prefix.count("[url=") > prefix.count("[/url]") or prefix.count("[color=") > prefix.count("[/color]"):
			continue

		var replacement = ""
		if meta.is_empty():
			replacement = "[b][color=%s]%s[/color][/b]" % [color, matched_str.to_upper()]
		else:
			replacement = "[b][color=%s][url=%s]%s[/url][/color][/b]" % [color, meta, matched_str.to_upper()]
			
		text = text.left(start) + replacement + text.right(-end)
	
	return text

static func resolve_level_scaling(text: String, level: int) -> String:
	if text.is_empty():
		return text
	
	var result := text
	
	# 1. Strip trailing redundant "at Levels 1 / 2 / 3" and "nos Níveis 1 / 2 / 3"
	var reg_levels := RegEx.new()
	reg_levels.compile("(?i)\\s+at\\s+levels?\\s+1\\s*(?:/\\s*2\\s*(?:/\\s*3)?)?")
	result = reg_levels.sub(result, "", true)
	
	var reg_niveis := RegEx.new()
	reg_niveis.compile("(?i)\\s+nos\\s+n[íi]veis\\s+1\\s*(?:/\\s*2\\s*(?:/\\s*3)?)?")
	result = reg_niveis.sub(result, "", true)
	
	# 2. Bracketed slash lists: [ 1 / 2 / 3 ], [100% / 150% / 200%], [+0 / +2 / +4]
	var reg_bracket := RegEx.new()
	reg_bracket.compile("\\[([^\\]]+/[^\\]]+)\\]")
	var bracket_matches := reg_bracket.search_all(result)
	for i in range(bracket_matches.size() - 1, -1, -1):
		var m = bracket_matches[i]
		var inner = m.get_string(1).strip_edges()
		if inner.begins_with("/"): # BBCode closing tag
			continue
		var parts = inner.split("/")
		var clean_parts: Array[String] = []
		for p in parts:
			clean_parts.append(p.strip_edges())
		if clean_parts.size() >= 2:
			var idx = clampi(level - 1, 0, clean_parts.size() - 1)
			result = result.left(m.get_start()) + clean_parts[idx] + result.right(-m.get_end())
	
	# 3. Plain number slash sequences: 1 / 2 / 3 or +1 / +2 / +3
	var reg_plain := RegEx.new()
	reg_plain.compile("\\+?\\d+%?\\s*/\\s*\\+?\\d+%?(?:\\s*/\\s*\\+?\\d+%?)?")
	var plain_matches := reg_plain.search_all(result)
	for i in range(plain_matches.size() - 1, -1, -1):
		var m = plain_matches[i]
		var matched_str = m.get_string().strip_edges()
		var parts = matched_str.split("/")
		var clean_parts: Array[String] = []
		for p in parts:
			clean_parts.append(p.strip_edges())
		if clean_parts.size() >= 2:
			var idx = clampi(level - 1, 0, clean_parts.size() - 1)
			result = result.left(m.get_start()) + clean_parts[idx] + result.right(-m.get_end())

	return result

static func strip_bbcode(text: String) -> String:
	var regex = RegEx.new()
	regex.compile("\\[[^\\]]*\\]")
	return regex.sub(text, "", true)

static func split_bbcode(bbcode: String, split_char_idx: int) -> Array[String]:
	if bbcode.is_empty() or split_char_idx <= 0:
		return ["", bbcode]
	
	var parsed_idx := 0
	var i := 0
	var n := bbcode.length()
	
	var tag_stack: Array[String] = []
	var upper_end := 0
	var lower_start := 0
	
	while i < n and parsed_idx < split_char_idx:
		if bbcode[i] == '[':
			var tag_close = bbcode.find("]", i)
			if tag_close != -1:
				var tag_content = bbcode.substr(i + 1, tag_close - i - 1).strip_edges()
				if tag_content.begins_with("/"):
					if not tag_stack.is_empty():
						tag_stack.pop_back()
				else:
					tag_stack.append(tag_content)
				i = tag_close + 1
				continue
		parsed_idx += 1
		i += 1
	
	if parsed_idx < split_char_idx:
		return [bbcode, ""]
	
	upper_end = i
	lower_start = i
	
	while lower_start < n and bbcode[lower_start] in [" ", "\n", "\t"]:
		lower_start += 1
	
	var upper_str = bbcode.substr(0, upper_end).strip_edges()
	var lower_str = bbcode.substr(lower_start).strip_edges()
	
	for idx in range(tag_stack.size() - 1, -1, -1):
		var tag = tag_stack[idx].split("=")[0]
		upper_str += "[/%s]" % tag
	
	var prefix = ""
	for tag in tag_stack:
		prefix += "[%s]" % tag
	lower_str = prefix + lower_str
	
	return [upper_str, lower_str]
