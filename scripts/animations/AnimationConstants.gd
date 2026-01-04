# scripts/animations/AnimationConstants.gd
class_name AnimationConstants
extends RefCounted

# =============================================================================
# MELEE ATTACK ANIMATION
# =============================================================================
# Total duration: WINDUP + LUNGE + RETURN = 0.1 + 0.6 + 0.3 = 1.0s
const MELEE_LUNGE_DURATION := 0.6 # Travel to target (2x return time)
const MELEE_WINDUP_DURATION := 0.1 # Anticipation before lunge
const MELEE_RETURN_DURATION := 0.3 # Return time (half of travel time)
const MELEE_ARC_HEIGHT := 120.0 # Arc height for the jump
const MELEE_WINDUP_DISTANCE := 30.0 # Pixels to wind back before lunge

# =============================================================================
# GUARDIAN SENTINEL LEAP
# =============================================================================
const GUARDIAN_LEAP_DURATION := 0.25 # Quick leap to ally's position
const GUARDIAN_RETURN_DURATION := 0.35 # Slightly slower return
const GUARDIAN_ARC_HEIGHT := 60.0 # Arc height for the leap

# =============================================================================
# BUMP ATTACK (Small knock-back animation)
# =============================================================================
const BUMP_DISTANCE := 10.0 # Pixels to bump forward
const BUMP_FORWARD_DURATION := 0.15 # Move forward time
const BUMP_RETURN_DURATION := 0.15 # Return time
const BUMP_TOTAL_DURATION := 0.5 # Total bump animation including settle time

# =============================================================================
# DEATH ANIMATION
# =============================================================================
const DEATH_LEVITATE_HEIGHT := 40.0 # Pixels to float up
const DEATH_DURATION := 1.0 # Total fade-out duration

# =============================================================================
# SUMMON ANIMATION
# =============================================================================
const SUMMON_DROP_HEIGHT := 50.0 # Pixels to drop from
const SUMMON_DROP_DURATION := 0.8 # Drop animation duration
const SUMMON_FADE_DURATION := 0.6 # Fade-in duration

# =============================================================================
# FLASH EFFECT
# =============================================================================
const FLASH_HOP_HEIGHT := 30.0 # Heal/buff hop height (increased for visibility)
const FLASH_RECOIL_DISTANCE := 8.0 # Damage recoil distance (legacy - use HURT_RECOIL_DISTANCE)
const FLASH_HOP_UP_DURATION := 0.12 # Hop up time (slightly longer to sync with deform)
const FLASH_HOP_DOWN_DURATION := 0.18 # Land with bounce
const FLASH_RECOIL_DURATION := 0.08 # Recoil back time (slightly longer)
const FLASH_RETURN_DURATION := 0.2 # Return from recoil (elastic)
const FLASH_FADE_DURATION := 0.25 # Flash intensity fade
const FLASH_GOLD_FADE_DURATION := 0.8 # Aegis gold flash (longer)

# =============================================================================
# LETHAL SAVE (Aegis Charm)
# =============================================================================
const LETHAL_SAVE_LEVITATE_HEIGHT := 30.0
const LETHAL_SAVE_RISE_DURATION := 0.5
const LETHAL_SAVE_HOLD_DURATION := 0.3
const LETHAL_SAVE_LAND_DURATION := 0.6

# =============================================================================
# COLORS
# =============================================================================
const COLOR_GOLD := Color(1.0, 0.84, 0.0) # Aegis Charm gold
const COLOR_GOLD_GLOW := Color(1.5, 1.26, 0.0) # Golden glow on parent
const COLOR_HEAL_BUFF := Color(0.6, 0.8, 1.0) # Unified blue tint for heal/buff

# =============================================================================
# SQUISH/STRETCH DEFORMATION (Rubber Ball Effect)
# Squish = horizontal compression (narrow & tall) - like pressing on sides / anticipation
# Stretch = vertical compression (wide & short) - like pressing from top / impact
# =============================================================================
const SQUISH_SCALE := Vector2(0.85, 1.15) # Narrow & tall (horizontal compression)
const STRETCH_SCALE := Vector2(1.15, 0.85) # Wide & short (vertical compression)
const NORMAL_SCALE := Vector2(1.0, 1.0) # Reset to normal
const DEFORM_DURATION := 0.08 # Deformation time (increased slightly for sync)

# =============================================================================
# HURT RECOIL (Enhanced)
# =============================================================================
const HURT_RECOIL_DISTANCE := 35.0 # Very noticeable recoil (was 15px)

# =============================================================================
# STAGGERED ENTRY ANIMATION
# =============================================================================
const ENTRY_STAGGER_DELAY := 0.1 # 100ms between each ball appearing
