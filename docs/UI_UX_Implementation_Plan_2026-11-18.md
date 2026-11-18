# UI/UX implementation plan

Updated November 18, 2026. This is the implementation plan for the latest decisions in the [screenshot review](UI_UX_Improvement_Plan_2026-11-17.md).

## 1. Challenge feedback

- In [FlashcardMinigame.gd](../scripts/FlashcardMinigame.gd), keep the existing **1.0-second** wrong-answer review. As soon as the wrong answer is accepted, lock input, reveal the correct answer to the right of the current question using the Review window's typography and formatting, and flash all six choices red. Clear the old choices after the flash, then display the next question and its choices at the existing transition time.
- Keep the correction visible until the next question replaces it or the Challenge ends. Re-enable input after the new choices are installed. The six-choice grid uses spatial keyboard/controller navigation, with Down selecting Skip and confirmation submitting the focused choice.

## 2. Machine labels and capsule storage

| Context | What exists today | Planned limit |
| --- | --- | --- |
| Run inventory | A fixed 5×5 grid per tier. `RUN_INVENTORY_CAP` is **25** in [Constants.gd](../scripts/Constants.gd). | Keep **25 per tier**. |
| Battle tier trays | Physics capsules synced from battle inventory records. | Use **25 per tier** as a gameplay count. |
| Battle Discard | A physics pile synced from the Discard records. | Use **80**, from `3 × 25 + 5`. |

`GrowableGridContainer` is the code name for the backing list of capsule IDs. Its initial allocation of 24 can expand. The trays display freely moving physics bodies. A body can still be queued to spawn after its capsule is already present in battle data, and a body recovered from outside the tray can respawn without changing capsule ownership. There is also an intentional connection in the other direction today. If a ball overlaps the lid area for five seconds, the UI can ask BattleManager to move it to Discard or, if it is already in Discard, back to its tier. Count-based overflow replaces that position-based penalty. [BattleState.gd](../scripts/battle/BattleState.gd) · [BattleInventoryTrayRig.gd](../scripts/BattleInventoryTrayRig.gd) · [PhysicsTierContainer.gd](../scripts/PhysicsTierContainer.gd)

Use the existing machine art and token icon. Put a numbered Tier badge and the effective token cost by each tier knob, and show the one-token recovery cost on Discard when available. Use the appropriate run or battle count for `x/25` and `x/80`. Drive changes from model and transfer events so labels follow the animation, and refresh from the model when opening, closing, or changing scenes. Use the existing capsule art, scaled to sit on the Shelf platform with its contents close to their unencapsulated size.

## 3. Overflow and Discard recovery

| Outcome | State and feedback |
| --- | --- |
| A capsule arrives at a full tier | Route the incoming capsule to Discard. |
| A capsule arrives at a full Discard pile | Use the seeded game RNG to eject one capsule already in Discard, then admit the incoming one. The ejected capsule is lost for this battle. |
| Discard draw with a matching tier that has room | Randomly draw among Discard capsules whose own tier has room. Send the chosen capsule to its tier and charge one token. |
| Discard draw with room in at least one tier but no matching capsule | Play the paid draw and return the selected capsule to Discard. Charge one token and keep the Discard count steady. |
| Discard draw with all three tiers full | Reject at the Discard knob using the existing rejection animation. Spend no token and leave the pile intact. |

Enforce the rules at the shared battle inventory operation, including additions from abilities, merges, draws, and transfers. Apply the all-full guard in the same check used by the Discard action and the machine. Resolve membership, cost, and any ejection before the physics presentation. Emit the events needed to animate the actual destination and any ejected capsule. The contextual explanations are for the dedicated helper session.

## 4. Unit order and held Preview

- **Order** toggles a large number over each unit itself. Number occupied actors consecutively starting at 1 across both sides, using the actual action order. Empty slots don't create gaps. Use a contrasting outline and a font size visibly larger than the HP and PWR digits underneath. Place it clear of the stars and equipped-item icon. The button and R toggle the same overlay. Refresh it as formation changes, summons, or removals affect order. [CombatSimulator.gd](../scripts/battle/CombatSimulator.gd) · [BattleView.gd](../scripts/BattleView.gd)
- Put Order on the left and the hold-to-Preview control on the right, side by side above Ready. Their total width including the gap matches the existing Ready button.
- **Preview** uses the same turn resolution as Ready and renders one final occupant per slot. The current combat path already resolves the attacks and builds an event log before VCR playback. Reuse that resolver and the Ready and turn-end effect paths. Run them against a temporary copy of battle data and the relevant run data, with the same starting RNG state, then render the resulting board snapshot. Release returns immediately to the live board. This takes a button and a way to isolate the existing resolution. The current Ready path also writes to live state and advances the phase through animation completion, so skipping playback alone would commit the turn. [BattleManager.gd](../scripts/BattleManager.gd) · [EndTurnAction.gd](../scripts/engine/actions/EndTurnAction.gd) · [RNGManager.gd](../scripts/systems/RNGManager.gd)

The proposed Preview endpoint is the board after the current turn's Ready effects, combat, and end-of-turn effects, or after an earlier battle-ending result. It stops before the next Challenge. The preview uses the same random outcomes as Ready for the same starting state, and preserves the live phase, RNG, currencies, saves, and replay.

## 5. Deck mastery and boss milestones

- Double the bar from **480 to 960 design pixels** below the day counter. Use the extra width for wider card segments and use each segment's whole space for hover or touch-drag. Adjust the spacing for long Decks. Sort the unlocked cards from highest to lowest current mastery, with locked cards grouped in grey on the left. Use the existing question style for the carousel and existing hero, boss, and banner sprites for markers. [Main.tscn](../scenes/Main.tscn) · [Main.gd](../scripts/Main.gd)
- Count unlocked cards with **current mastery of at least Level 3**. Cards start at Level 1 and can reach Level 3 after two correct answers. Levels 4 and 5 qualify. If an answer drops a card below Level 3, it stops counting toward the next milestone. Use that count both in the display and when the Crossroads offers the next boss.
- The final boss is at **80% of the Deck**. With the existing five bosses in a Full Deck, space thresholds at **16%, 32%, 48%, 64%, and 80%**. A 100-card Full Deck therefore uses **16, 32, 48, 64, 80**. In a Half Deck, space three bosses evenly through 80% of the selected run's pool. Round fractional thresholds up. A 50-card Half Deck uses **14, 27, 40**. [FlashcardProgress.gd](../scripts/FlashcardProgress.gd) · [RunState.gd](../scripts/RunState.gd) · [GameManager.gd](../scripts/GameManager.gd)
- Use the top edge of the bar as a platform. The hero stands at the Level 3/2 boundary, and the boss sprites stand on the same line. Refresh their positions as answers change the mastery groups and unlock new cards. Reveal each boss sprite at its existing unlocked-card milestone. For Full Deck those milestones are **20%, 40%, 60%, 80%, and 100%**. For Half Deck they are approximately **33⅓%, 66⅔%, and 100%** of the selected pool. Encounter eligibility uses the separate Level 3+ milestones above. After a boss is defeated, replace its sprite with a red X at the position where it was defeated. Preserve that position as the bar changes.
- Resolve the boss and banner identity once for each previewable milestone and reuse it for the actual encounter. Inspection reads that identity without rolling another encounter. [EncounterGenerator.gd](../scripts/EncounterGenerator.gd)

## 6. Token tray

Place a clear, front-facing 2D plastic tray immediately left of the Ready controls, in the space of the two rightmost Shelf slots. Draw its flat bottom, side walls, and transparent front in Godot. Keep the first three Shelf slots open with three purchasable slots following them. The plus marks the next slot for purchase.

When the tray is visible, replace the top HUD token count with a numeric label directly below the tray. The label shows the current token balance.

Use the existing five-frame [token spritesheet](../assets/PixelArt/ui/textures/TokenRotationSpriteSheet.png) to spin the coins on the way in. Switch to the middle frame (index 2) for the edge-on rectangle as each coin drops into the tray. The frame is vertical in the sheet. Orient each rectangular 2D body roughly horizontal on entry and vary its starting position and angle slightly so the coins can settle into a natural stack. Size the collisions to the visible edge of the coin. The coin count comes from the token balance, while physics determines where they settle. Existing art and Godot controls cover this pass.

## Implementation order

1. Challenge feedback and input.
2. Shared capacity rules, Discard rejection, machine labels, and Shelf/tray layout.
3. Order overlay and held Preview, using the same overflow rules as Ready.
4. Mastery display, shared boss thresholds, and boss inspection.

