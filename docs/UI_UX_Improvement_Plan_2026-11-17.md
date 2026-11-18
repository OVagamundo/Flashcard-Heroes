# UI/UX Clarity and Player Decision Plan

- Updated: 2026-11-18
- Project: Flashcard Heroes — replacement title still to be chosen
- Status: planning document; work is not marked implemented

This plan records the UI work and decisions from the screenshot review. It focuses on changes to make, with unresolved choices listed separately. The aim is for players to understand actions, consequences, and game state with minimal persistent text, so they can focus on strategy and learning.

See the [November 18 implementation plan](UI_UX_Implementation_Plan_2026-11-18.md) for the updated rules, code findings, and remaining decisions. Section 7 is a design draft for a dedicated contextual helper session.

## 1. Battle flow and action controls

### Phase sequence

The current battle cycle is:

Challenge → turn-start effects → player preparation → Ready effects → combat → end-of-turn effects → next Challenge.

The first battle entrance has a special staging sequence. Verify the cues against the current phase implementation. Current code also skips the regular turn-start sequence on the first turn.

Use animation, emphasis, and action availability to distinguish phases without permanent phase labels:

| Phase | Signal to develop |
| --- | --- |
| Challenge | Make the question, timer, and answer choices the focus. Do not show teaching popups during the timed answer sprint. |
| Turn-start effects | Briefly highlight each effect source and its actual recipient as it resolves. |
| Player preparation | Light up available machines, Shelf, Formation, and preparation actions. |
| Ready effects | Change Ready to its pressed/inactive state and animate sources and targets before attacks begin. |
| Combat | Highlight one acting unit at a time, then cue its target and attack direction. |
| End of turn | Animate the turn marker advancing, then transition to the next Challenge. |

### Crest and team feedback

When a placed unit contributes to one or more crest effects, pulse every matching group and every affected crest in the same feedback beat. If one unit belongs to several groups, it pulses once while each group and crest is called out. Keep contributing units visually distinct from the units that actually receive the effect; show recipients when the effect resolves.

### Order overlay and final-state preview

Add two compact controls side by side above Ready:

- **Left, Order:** toggles consecutive numbers over occupied units in actual action order. Use digits larger than the stats below, with a contrasting outline. Numbers update when units or summons change the queue. The UI button and R toggle the same overlay.
- **Right, Preview:** while held, run the complete combat simulation and show only the final board state. Do not play the normal event-by-event VCR sequence or show intermediate deaths and summons. Render one final occupant per slot, or an empty slot. On release, restore the live board immediately.

Keep the Ready button at its original size and visual treatment. The two compact controls together, including their gap, match Ready's width. The preview must be visibly temporary and must not alter the live game state.

## 2. Machines, Shelf, capacity, and tokens

### Machine labels and counts

Use icon-and-number labels rather than routine text, to reduce localization work:

- Tier 1, 2, and 3 machines show a distinct tier badge with the number 1, 2, or 3.
- Beside it, show a token icon and the actual current draw cost. Base costs are 1, 2, and 3 tokens by tier; show discounts when they apply.
- Show occupied/capacity as x/25 on each tier machine and x/80 on Discard. Use the machine's current context. The run inventory already has 25 fixed slots per tier; the battle tier trays and Discard use physics for display.
- Localized helper/inspection text teaches the icons as Tokens/Fichas and explains Tier. Do not print those words on every machine.
- Make Tier badges visually distinct from unit Level stars. The grey Discard machine shows its current 1-token recovery cost when available.

### Shelf capsules

Increase an occupied Shelf capsule until it nearly fills the visible slot footprint and rests on the platform without clipping. Its contained unit or item should appear at approximately its normal display scale outside the capsule, not as a miniature.

### Token tray and Shelf layout

Use a clear, flat 2D plastic tray immediately left of the Ready controls. It occupies the two rightmost Shelf positions, leaving three active slots and three purchasable slots. The plus marks the next purchasable slot.

Coins spin using the existing spritesheet, then fall and stack with 2D physics using its middle frame for the edge-on shape. The token balance drives the pile. When the tray is visible, the numerical token total moves from the top HUD to directly below the tray.

### Gacha-ball overflow

When a tier container is full, route additions to Discard. If Discard is full, eject a random capsule from its pile for the rest of the battle and admit the incoming one. Discard draws prefer capsules whose tier has room. If at least one tier has room but no capsule matches, the draw returns to Discard and spends the token. When all three tiers are full, the Discard knob plays a rejection animation and spends no token. The implementation plan lists the model and presentation changes. Tutorial explanations will be designed in the helper session.


## 3. Deck mastery and boss progress bar

Replace boss timing based on the number of unlocked flashcards with mastery-based milestones. This should prevent a player who unlocks many cards during long battles from facing a boss unusually early, such as on Day 2.

Turn the thin bar below the day counter into a wider, easier-to-scan map of the Deck:

- Show progress for the full Deck, including which cards are mastered and their mastery levels.
- Sort unlocked cards from highest mastery on the left (blue) toward the least mastered on the right (red); use the existing level colors, including the yellow/orange Level 3-to-Level 2 boundary.
- Represent not-yet-unlocked cards in grey; they have no mastery level yet. Keep them to the left of the unlocked cards, which are ordered from highest to lowest mastery.
- Use the top edge as a platform shared by the hero and the boss sprites. The hero stands at the Level 3/2 boundary. Update their positions as answers change the bar.
- Reveal boss sprites one at a time at the existing unlocked-card milestones of 20%, 40%, 60%, 80%, and 100% for Full Deck, or at thirds for Half Deck. Inspection shows the boss's banner and unit(s). Replace a defeated boss with a red X at the position where it was defeated. Mastery still governs when the boss encounter becomes available.
- Double the bar from 480 to 960 design pixels to give each card a wider target. Hover or drag across the bar on touch to see a carousel-style question preview.

Count unlocked cards currently at Level 3 or higher. Cards start at Level 1 and can reach Level 3 after two correct answers. A 100-card Full Deck has milestones at 16, 32, 48, 64, and 80 qualifying cards. A 50-card Half Deck has three milestones at 14, 27, and 40. The final boss is at 80% mastery coverage in either mode.

## 4. Title and loadout

- Separate Continue from New Run and show a compact summary of the saved run. Make save replacement clear at the commitment point.
- Distinguish selected, available, and locked hero/Deck choices. Show the selected hero clearly and keep Katakana/Hiragana adjacent.
- Make the practical Deck differences, actual card count, starting contents, and hero ability easy to find without repeating ability text or opening a wall of prose. Keep longer writing-system descriptions in a secondary readable view.
- Complete the EN/PT-BR text and selector localization. Use “Deck” in both languages.

## 5. Encounter screens

- **Shop:** Use the unfamiliar-content outline and inspection for items/units the player has not seen. Once an offer is selected, make its gold price and purchase destination clear. Show the current escalating reroll cost.
- **Ordinary rewards:** Let the player take or sell desired prizes individually. On leaving, collect the remaining prizes automatically. Elite/boss exclusive rewards still resolve as one choice.
- **Shrine:** Distinguish permanent removal from transformation. Show the selected capsule, action, and cost. Transformation selects another definition in the same category and Tier and carries over Level; disclose any other instance-property changes based on the actual rules.
- **Merge:** For a selected valid combination, show the resulting capsule, cost, consumed ingredients, relevant inherited state, and recipe unlock. Add another cue only if the current eligibility outlines/result preview do not communicate the outcome clearly enough.
- **Training:** Show token cost with the shared token icon and numeral. Make the selected stat and possible gains clear. Current weighted outcomes are: 1 token gives 0/1/2 gains at 10/80/10%; 2 tokens gives 0/1/2/3 at 10/40/40/10%; 3 tokens gives 0/1/2/3/4/5 at 5/15/30/30/15/5%.

## 6. Flashcard answers and input

Keep six answer choices and the existing 1.0-second wrong-answer review. On an incorrect click, show the correct answer to the right of the question, using the same presentation as the Review window. Flash the answer options red, then remove them before showing the next question.

Add spatial keyboard/controller input and a skip shortcut:

- Use spatial keyboard/controller navigation to choose among the six answers. Down selects Skip.
- Capture the selected answer on confirmation so releasing a stick or key cannot change it.

## 7. Contextual helper and first-time tutorial

### Helper behavior

Teach the most important actionable fact when the player encounters a mechanic for the first or second time, or when it becomes relevant to a decision. Anchor each brief explanation to the relevant object. If several lessons become relevant together, show only the highest-priority one and defer the others until their next relevant opportunity. Tune spacing through play so interruptions do not crowd the run.

Use short proceed/cancel explanations before a player's first unfamiliar consequential action, including:

- placing a capsule in the Formation, which opens it and prevents it returning to the Shelf;
- drawing when the Shelf is full, which sends the capsule to Discard;
- replacing an equipped item, which discards the previous item;
- pressing Ready while useful preparation space or tokens remain.

Explain automatic events without a cancel prompt, such as a crest activating or an enemy being summoned by its banner. Avoid tutorial popups during timed answers. Pause gameplay for blocking lessons and resume the action they belong to.

### First-time Dan run

Make Dan the only hero available to first-time players until they complete the core introduction, so the tutorial can rely on his token guarantee. Present the introduction as a normal run, while quietly shaping it with easier enemy teams, relevant rewards and shop offers, scripted legal draws, and selected randomness. Continue until all basic concepts have been introduced. If the player dies or quits before then, offer another guided run with some variation. Keep the tutorial enable/disable option; if the player disables it before seeing all contextual lessons, briefly explain that some game explanations will be missed.

Teach the starter units and positioning through visible outcomes. For example, show Ripplepup's heal relationship with the ally in front: position it behind a unit likely to survive the first hit; if a fragile target is knocked out before the heal can trigger, explain that result. Use later introductory battles to demonstrate more advanced enemy, item, crest, and trinket mechanics. Preserve player choice and provide checkpoints so a failed or alternative formation does not block the lesson.

### Topics to teach at the relevant first-use opportunity

| Topic | Visual / interaction lesson |
| --- | --- |
| Gold, tokens, Tier, cost, capacity | Animate the correct currency to a priced machine; point out tier badge and x/y count. |
| Challenge rewards and skipping | Show how answers and skipping affect tokens, including Dan's minimum reward. |
| Shelf versus Formation | Animate capsule draw, placement, opening, and the one-way Shelf-to-Formation transition. |
| Position, attack order, and support | Highlight front/target relationship; show a unit surviving long enough to trigger its support effect. |
| Ready and battle phases | Use the phase cues above; teach that Ready begins automatic resolution. |
| Crest groups and effects | Show every matching group on activation, then the actual recipients when effects resolve. |
| Items and consumables | Show target, effect, replacement/discard outcome, or one-use consumption before commitment. |
| Merge, Shrine, training, shop, rewards | Show the selected result, cost, affected capsule(s), and whether the result is permanent or encounter-only. |
| Banners, summons, Dust, overflow | Attribute summons/pollution to their source and teach the selected capacity/overflow outcome when it first matters. |
| Mastery map and boss milestones | Show the hero marker moving with mastery and inspect a boss preview before that encounter. |

Track whether a lesson was shown, deferred, canceled, or demonstrated by play. Do not treat dismissal alone as proof that the player learned it. Existing tutorial replay and profile progress need to remain distinct from first-time hero access.

## 8. Replacement title and multi-pool research

The replacement title should retain “Flashcard” or an obvious variant and may invoke Gacha/Gachapon or capsules. Flashcard Hero and Gachamon are already taken, according to the user. Current candidates:

- **FlashKADO: Learn or Die**
- **FlashcarDo: Knowledge is Power** / **FlashcarDo: The Way of the Flashcard**
- **Flashcard Legends: Gachapon**
- **Flashcard Jigoku: Learn or Die** / **Flashcard Hell: Gachapon**
- **Flashapon**

Availability has not been verified; select and screen the title before changing branding.

The three separately curated pools with different draw costs are a core distinction. Related systems are not exact matches:

- [Little Adventure Tale](https://store.steampowered.com/app/3320370/Little_Adventure_Tale/) uses character decks and a shared draw allowance; its documented draft-mode start has 11 cards. Fixed different prices by pool were not verified.
- [Across the Obelisk](https://store.steampowered.com/app/1385380/Across_the_Obelisk/) uses separate hero decks; 15-card starts are commonly reported, but not a player-wide average or maximum.
- [Arcanium](https://store.steampowered.com/app/1056840/) has three character decks; reports describe 9–14 cards in active decks, with no reliable current maximum.

No reliable average or maximum was found for a close equivalent. Treat reported sizes as comparisons, not balance targets.

## 9. Decisions still open

1. **Replacement title:** choose a candidate and screen it for conflicts.
2. **Tutorial pacing:** playtest interruption timing and the guided-run variation.

## 10. Work order and completion checks

1. Implement machine icon/cost/capacity labels, Shelf capsule scale, and the selected Shelf/tray layout.
2. Implement mastery-sorted Deck progress, boss milestones/inspection, and the card carousel.
3. Implement crest-group feedback and the order/held-preview controls at the original Ready size.
4. Implement overflow routing and Discard rejection, including the paid fallback when no capsule fits a tier with room.
5. Implement the correction feedback and six-answer input. Schedule the contextual helper and Dan introduction for their dedicated design session.
6. Finish encounter-specific information, title selection, and focused playtests.

Check that players can read machine costs/capacities at a glance, see Deck mastery and distance to the next boss, predict the consequence of a placement or purchase, identify all members of a newly active crest, and distinguish a temporary forecast from the live board.
