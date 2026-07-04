# Flashcard Heroes Implementation Task Tracking

## Current Status: Refining Systems and UI

### ✅ RECENTLY COMPLETED TASKS
- [x] Created and implemented Loadout Scene (`scenes/Loadout.tscn`, `scripts/Loadout.gd`) with Hero and Deck selection carousels, Deck Order options (Regular, Inverted, Random), and Test Mode starters.
- [x] Implemented 7 new Trinkets (Rusty Ring, Hero's Catalyst, Purifying Pendant, Awe Inspiring Totem, Beginner's Charm, Trinity Charm, Spiked Armor) with corresponding abilities, effects, and localized assets.
- [x] Implemented Non-Combat Encounter Study Sessions (Rest Site, Training Ground, Gambling Den) with a 5 Gold cost.
- [x] Added Gold Spend VFX Animation for Study Sessions.
- [x] Fixed `CombatEvent` member errors and refined target resolution logic.
- [x] Debugged and fixed Trinket Animation Architecture to correctly play VFX.
- [x] Fixed Entity Description Mismatches across various unit defs.
- [x] Audited Animation Refactor Documentation to reflect current architectural state.
- [x] Implemented Soul Inheritance Logic for dynamic stat transferring.
- [x] Debugged and fixed Engine Resource Leaks.
- [x] Fixed Fusion Spark Bug.
- [x] Fixed inspection window lookup failures during combat animations by implementing UUID-based fallback in `WindowManager`.
- [x] Fixed premature enemy memory erasure by deferring `_flush_deferred_enemy_erasures()` until combat animations finish in `BattleManager`.
- [x] Fixed interaction bugs during VCR playback by disabling hover and properly ignoring double-click events to prevent instant window closures.

### 🔄 CURRENT TASKS
- [ ] **Test the complete flashcard system end-to-end**
  - [ ] Test battle flow with ResultsPopup
  - [ ] Verify SRS algorithm is working and rewards are accurately distributed
  - [ ] Test complete flow from Loadout → Battle → Rest Site
- [ ] **Polish existing animations and transitions**

### 🐛 KNOWN ISSUES TO FIX
- [ ] Results storage between `_on_flashcard_completed` and `_on_results_acknowledged` needs improvement.