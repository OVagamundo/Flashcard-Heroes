# scripts/AbilityPriorities.gd
class_name AbilityPriorities
extends RefCounted

## ═══════════════════════════════════════════════════════════════════════════
## ABILITY PRIORITY SYSTEM - Single Source of Truth
## ═══════════════════════════════════════════════════════════════════════════
## 
## Higher number = executes FIRST
## Gaps of ~50-100 between tiers allow inserting new priorities without reordering
##
## USAGE IN CODE:
##   request.priority = AbilityPriorities.COUNTER_ATTACK
##
## USAGE IN .tres FILES:
##   priority = 50  # See AbilityPriorities.gd: COUNTER_ATTACK
##
## ═══════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# TIER 1: GUARDIAN (300+)
# Damage interception - must check before any damage resolves
# ─────────────────────────────────────────────────────────────────────────────
const GUARDIAN_INTERCEPT = 300 ## Guardian Sentinel intercept check

# ─────────────────────────────────────────────────────────────────────────────
# TIER 2: SUMMONS (200-299)
# Resurrection and spawn effects - higher priority = first claim on slots
# ─────────────────────────────────────────────────────────────────────────────
const TRINKET_SUMMON = 210 ## Soul Echo resurrection (highest summon)
const UNIT_SUMMON = 205 ## Unit on-death summon (e.g., UnitTier3C)
const ITEM_SUMMON = 200 ## Item on-death summon (e.g., ItemTier2C)

# ─────────────────────────────────────────────────────────────────────────────
# TIER 3: AURAS (100-199)
# Defensive reactions that trigger on being hurt
# ─────────────────────────────────────────────────────────────────────────────
const RESILIENT_AURA = 100 ## Buffs allies when hurt (UnitTier3D)
const ON_HURT_HEAL = 100 ## Heal allies when hurt (ItemTier3A)
const ON_ATTACK_BUFF = 100 ## Buff allies when attacking (ItemTier3B)

# ─────────────────────────────────────────────────────────────────────────────
# TIER 4: COUNTERS (50-99)
# Retaliation attacks executed on hurt
# ─────────────────────────────────────────────────────────────────────────────
const COUNTER_ATTACK = 50 ## Counter on hurt (UnitTier1B, ItemTier3D)

# ─────────────────────────────────────────────────────────────────────────────
# TIER 5: MODIFIERS (10-49)
# Attack modifications and special attack types
# ─────────────────────────────────────────────────────────────────────────────
const DEFENSIVE_STANCE = 10 ## Pre-attack HP boost (UnitTier2A)
const SHOCKWAVE = 10 ## AOE cascade (UnitTier2B)
const MIRROR_STRIKE = 10 ## Target swap attack (UnitTier3A)

# ─────────────────────────────────────────────────────────────────────────────
# TIER 6: STANDARD (0)
# Default abilities with no special timing requirements
# ─────────────────────────────────────────────────────────────────────────────
const STANDARD = 0 ## Default for new abilities
const LIFESTEAL = 0 ## On-attack heal (ItemTier3C)
const TURN_START_HEAL = 0 ## Turn start healing (ItemTier1A)
const PASSIVE_HEAL = 0 ## Passive on-hurt heal (ItemTier2C)
const ALLY_DEATH_BUFF = 0 ## Buff on ally death (UnitTier2C)

# ─────────────────────────────────────────────────────────────────────────────
# TIER 7: DELAYED (-1 to -99)
# Effects that should happen after main combat
# ─────────────────────────────────────────────────────────────────────────────
const BOSS_SUMMON = -50 ## End-of-turn boss reinforcements

# ─────────────────────────────────────────────────────────────────────────────
# TIER 8: DEFERRED (-100 and below)
# Must happen last - grants additional actions
# ─────────────────────────────────────────────────────────────────────────────
const EXTRA_ACTION = -100 ## Bloodlust Edge extra turn

# ═══════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE TABLE (for copy-paste into .tres files)
# ═══════════════════════════════════════════════════════════════════════════
#
# | Value | Constant          | Use Case                              |
# |-------|-------------------|---------------------------------------|
# |  300  | GUARDIAN_INTERCEPT| Intercept lethal damage               |
# |  210  | TRINKET_SUMMON    | Soul Echo resurrection                |
# |  205  | UNIT_SUMMON       | Unit on-death summon                  |
# |  200  | ITEM_SUMMON       | Item on-death summon                  |
# |  100  | RESILIENT_AURA    | Buffs/heals on hurt                   |
# |   50  | COUNTER_ATTACK    | Counter-attack on hurt                |
# |   10  | DEFENSIVE_STANCE  | Pre-attack modifiers                  |
# |    0  | STANDARD          | Default for new abilities             |
# |  -50  | BOSS_SUMMON       | End-of-turn spawns                    |
# | -100  | EXTRA_ACTION      | Grant extra action (must be last)     |
#
# ═══════════════════════════════════════════════════════════════════════════
