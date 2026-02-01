# res://scripts/utils/StatScaling.gd
class_name StatScaling
extends RefCounted

## Centralized stat-scaling calculation utility.
## Calculates values based on parameters + source stats from context.
## Used for damage, healing, buffs, and any stat-based calculations.
##
## Parameter formats:
##   - null/missing: Returns source_pwr from context
##   - int: Fixed value (e.g., 5 → returns 5)
##   - Dictionary: Stat-scaling formula
##
## Stat-scaling Dictionary format:
##   {
##     "base_value": int,        # Flat bonus
##     "pwr_multiplier": float,  # Multiplied by context["source_pwr"]
##     "hp_multiplier": float,   # Multiplied by context["source_hp"]
##     "use_source_pwr": bool,   # Shorthand: return source_pwr directly
##   }


## Calculate a stat-scaled value from parameters and context.
## @param param: Can be null, int, or Dictionary with scaling
## @param context: Must contain "source_pwr" (and optionally "source_hp")
## @param script_name: For warning messages (e.g., "BasicAttackEffect")
## @return: Final calculated value (integer, always >= 0)
static func calculate(param: Variant, context: Dictionary, script_name: String = "StatScaling") -> int:
	var source_pwr: int = context.get("source_pwr", 0)
	
	# No parameter: use source PWR directly
	if param == null:
		if source_pwr == 0:
			push_warning("[%s] source_pwr missing from context, value will be 0" % script_name)
		return source_pwr
	
	# Fixed integer value
	if param is int:
		return param
	
	# Stat-scaling dictionary
	if param is Dictionary:
		return _calculate_scaled(param, context, script_name)
	
	# Fallback to source PWR
	if source_pwr == 0:
		push_warning("[%s] source_pwr missing from context, value will be 0" % script_name)
	return source_pwr


## Calculate stat-scaled value using the formula:
##   final = base_value + (source_pwr * pwr_multiplier) + (source_hp * hp_multiplier)
## Also supports "use_source_pwr: true" shorthand.
static func _calculate_scaled(param_dict: Dictionary, context: Dictionary, script_name: String) -> int:
	# Shorthand: use_source_pwr returns source PWR directly
	if param_dict.get("use_source_pwr", false):
		var pwr: int = context.get("source_pwr", 0)
		if pwr == 0:
			push_warning("[%s] source_pwr missing from context for use_source_pwr=true" % script_name)
		return pwr
	
	var base_value: int = param_dict.get("base_value", 0)
	var pwr_multiplier: float = param_dict.get("pwr_multiplier", 0.0)
	var hp_multiplier: float = param_dict.get("hp_multiplier", 0.0)
	
	var source_pwr: int = context.get("source_pwr", 0)
	var source_hp: int = context.get("source_hp", 0)
	
	var final_value: float = base_value
	final_value += source_pwr * pwr_multiplier
	final_value += source_hp * hp_multiplier
	
	# Complex: Dynamic multiplier from context (e.g., "tokens_spent")
	var multiplier_key: String = param_dict.get("context_multiplier_key", "")
	if not multiplier_key.is_empty():
		var context_val = context.get(multiplier_key, 1)
		if context_val is int or context_val is float:
			final_value *= float(context_val)
	
	# Complex: Scaling by any context key (e.g., "damage_dealt" for lifesteal)
	var scaling_key: String = param_dict.get("scaling_context_key", "")
	var scaling_multiplier: float = param_dict.get("scaling_context_multiplier", 1.0)
	if not scaling_key.is_empty():
		var context_val = context.get(scaling_key, 0)
		if context_val is int or context_val is float:
			final_value += float(context_val) * scaling_multiplier
			
	# Optional: Clamping
	var min_val: int = param_dict.get("min_value", -999999)
	var max_val: int = param_dict.get("max_value", 999999)
	
	return clampi(int(floor(final_value)), min_val, max_val)
