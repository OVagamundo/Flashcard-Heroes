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
	
	# Note: base_hp_multiplier intentionally not supported
	if param_dict.has("base_hp_multiplier") and param_dict["base_hp_multiplier"] != 0.0:
		push_warning("[%s] base_hp_multiplier not supported - add source_base_hp to context" % script_name)
	
	return int(floor(final_value))
