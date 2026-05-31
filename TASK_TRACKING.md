# Flashcard Heroes Implementation Task Tracking

## Current Status: Refining Systems and UI

### ✅ RECENTLY COMPLETED TASKS
- [x] Implemented Non-Combat Encounter Study Sessions (Rest Site, Training Ground, Gambling Den) with a 5 Gold cost.
- [x] Added Gold Spend VFX Animation for Study Sessions.
- [x] Fixed `CombatEvent` member errors and refined target resolution logic.
- [x] Debugged and fixed Trinket Animation Architecture to correctly play VFX.
- [x] Fixed Entity Description Mismatches across various unit defs.
- [x] Audited Animation Refactor Documentation to reflect current architectural state.
- [x] Implemented Soul Inheritance Logic for dynamic stat transferring.

### 🔄 CURRENT TASKS
- [ ] **Test the complete flashcard system end-to-end**
  - [ ] Test battle flow with ResultsPopup
  - [ ] Verify SRS algorithm is working and rewards are accurately distributed
  - [ ] Test complete flow from Loadout → Battle → Rest Site
- [ ] **Polish existing animations and transitions**

### 🐛 KNOWN ISSUES TO FIX
- [ ] Results storage between `_on_flashcard_completed` and `_on_results_acknowledged` needs improvement.

### 📋 PENDING TASKS
- [ ] **Create Loadout Scene according to TDD Section 10.2**
  - [ ] Loadout.tscn scene and script
  - [ ] Hero and deck selection UI