# UI/UX implementation status

Updated November 19, 2026. This document records the implemented interactions from the [screenshot review](UI_UX_Improvement_Plan_2026-11-17.md).

## 1. Challenge feedback

- During the **1.0-second** wrong-answer review, input is locked. The correct answer appears beside the question and the six choices flash red and clear. The correction remains until the next question or the end of the Challenge. [FlashcardMinigame.gd](../scripts/FlashcardMinigame.gd)
- The choices support spatial keyboard and controller navigation. Down from the bottom row focuses Skip. Confirmation submits the focused choice.

## 2. Machine labels and capsule storage

Tier machines display their Tier, effective Token cost and capsule count out of 25. Discard displays its count out of 80 and its one-Token recovery cost in battle. Count updates follow transfer playback and refresh from the current run or battle inventory. Physics bodies are views of model membership. [Main.gd](../scripts/Main.gd) · [BattleInventoryTrayRig.gd](../scripts/BattleInventoryTrayRig.gd)

## 3. Overflow and Discard recovery

The shared battle inventory operations resolve membership, cost, recovery and ejection before playback. The Discard knob rejects a draw when all tiers are full. A paid draw with no compatible capsule returns the selected capsule to Discard. See [InventoryManager.md](InventoryManager.md#3-gacha-draw--discard-lifecycle) for the state rules.

## 4. Unit order and Preview

- **Order** while held, or while R is held, numbers the occupied starting actors consecutively across both sides using their current combat order.
- **Preview** while held shows one final occupant per slot after Ready effects, combat and end-of-turn effects, or at an earlier battle-ending result. Release restores the regular board. Both controls are available during settled preparation. See [CombatSystem.md](CombatSystem.md#held-turn-preview).

## 5. Deck mastery and boss milestones

- Double the bar from **480 to 960 design pixels** below the day counter. Use the extra width for wider card segments and use each segment's whole space for hover or touch-drag. Adjust the spacing for long Decks. Sort unlocked cards from highest to lowest current mastery from left to right, followed by the locked cards in grey. Use the existing question style for the carousel and existing hero, boss, and banner sprites for markers. [Main.tscn](../scenes/Main.tscn) · [Main.gd](../scripts/Main.gd)
- The display and Crossroads use the same **current Level 3+ mastery count** and boss thresholds. The final Boss is at 80% of the selected Deck. See [EncounterSystem.md](EncounterSystem.md#31-milestone-boss-battle-scheduling-mastery-driven).
- Use the top edge of the bar as a platform. The hero stands at the left edge until a card reaches Level 3, then stands above the rightmost card at Level 3 or higher. Update the hero's position as answers move cards between mastery groups. Show the next boss from the start of its leg, just after the unlocked cards. Close the gap toward the hero in proportion to the mastery gained between the previous and next boss thresholds. Reveal any further bosses at their unlocked-card milestones and place them ahead of the next boss. For Full Deck those reveal milestones are **20%, 40%, 60%, 80%, and 100%**. For Half Deck they are approximately **33⅓%, 66⅔%, and 100%** of the selected pool. After a boss is defeated, show a red X at its mastery milestone.
- Resolve the boss and banner identity once and reuse it for the actual encounter. At the Level 3+ threshold, the next boss faces the hero and overlaps it slightly. Keep the overlap as the hero masters more cards and while the Boss path is offered or its battle is active. Inspection reads the stored identity. [EncounterGenerator.gd](../scripts/EncounterGenerator.gd)

## 6. Token tray

Place a clear, front-facing 2D plastic tray immediately left of the Ready controls and match their full height. Draw its flat bottom, side walls, and transparent front in Godot. Keep the first three Shelf slots open with four purchasable slots following them. The plus marks the next slot for purchase.

Show the token icon and current balance at the upper right of the tray, including when the balance is zero. Match the gold HUD icon and number sizes.

Use the existing five-frame [token spritesheet](../assets/PixelArt/ui/textures/TokenRotationSpriteSheet.png) to spin the coins on the way in and show a mix of edge-on, tilted, and face-on coins in the pile. Give each pose a rounded 2D collider that matches its visible size. Vary the entry angle, velocity, and spin, and aim incoming coins near the pile so collisions shift the coins already inside. The token balance determines the count and physics determines where the coins settle.

## Related design work

Contextual teaching and guided-run ideas remain in the [screenshot review](UI_UX_Improvement_Plan_2026-11-17.md).

