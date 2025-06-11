extends Resource
class_name EffectDefinition

enum ValueType {
    FLAT,                   # The 'value' is a direct, flat number.
    SOURCE_PWR_MULTIPLIER,  # 'value' is a multiplier for the source's PWR.
    TARGET_REF_HP_MULTIPLIER # 'value' is a multiplier for the target's reference HP.
}

@export var effect_type: StringName # e.g., "DEAL_DAMAGE", "INCREASE_HP"
@export var value_type: ValueType = ValueType.FLAT
@export var value: float # The magnitude or multiplier of the effect.
@export var status_effect_to_apply: Resource # StatusEffectDefinition
@export var duration: int # Duration in turns for temporary effects.
