# Hero Set Proposal: Aprendice

**Status:** Design proposal

**Scope:** Aprendice, Scholars, the Scholar unit and item lineages, the Scholar Emblem, and supporting trinkets

**Design goal:** Make the starting Hero forgiving through time and safe study choices, while making combat power follow correct answers and review progress. Token-held scaling belongs mainly to Tier 3. No unit or item discounts gacha draws.

The unit recipes follow the closed Hero-pack model: one unique Tier 1, four Tier 2 recipes with the neutral Tier 1 units, and all six pairings of those Tier 2 units. The item recipes use one unique Tier 1 item and the two neutral Tier 1 items; the resulting Tier 2 items merge into one Tier 3 item. Tier 2 and Tier 3 items have new abilities of their own and do not inherit the neutral ingredients' abilities.

## 1. Unit placeholder naming convention

Use the existing descriptive placeholder IDs as names. The ID records elemental souls first, then class traits, then visual traits.

| Group | Codes |
|---|---|
| Elemental souls | `E` = Earth, `F` = Fire, `W` = Water, `A` = Air. Soul letters use the game's established order. A Tier 1 has one soul, Tier 2 has two, and Tier 3 has four. |
| Class traits | `Tnk` = Tank, `Fig` = Fighter, `Sup` = Support, `Spe` = Specialist. `Sch` is added for Scholars after the other class codes. |
| Visual traits | `Fod` = Food, `Mec` = Mecha, `Ani` = Animal, `Pla` = Plant, `Toy` = Toy, `App` = Appliance, `Cos` = Costume. |

The unique Tier 1 Scholar is assigned Air, Tank, Fighter, and Scholars. Tank and Fighter give the affordable starter unit defensive and offensive trait hooks. The neutral Tier 1 recipe parents are `ASpeFodToy`, `ETnkPlaToy`, `FFigMecApp`, and `WSupAniCos`.

## 2. Hero

| Field | Proposal |
|---|---|
| Name | **Aprendice** |
| Unlock | Starting Hero, available from the beginning. Other Heroes are unlocked through progression. |
| Base stats | 10 HP / 2 PWR, retaining Starter's current values. |
| Traits | Fixed **Scholars**, plus one random Elemental trait and one random thematic Class or Visual trait. Roll the two random traits once when the Hero is selected and keep them for the run. |
| Token guarantee | At the end of each token-awarding minigame, if that session generated fewer than 3 Tokens, grant enough to reach 3. If it generated 3 or more, grant nothing. Count the session's Token awards, not Tokens already carried into the session. |
| Study time | Each correct answer adds Timekeeper's extra +1.0 second, in addition to the normal +0.5 seconds, in battle and non-battle minigames. This passive works outside of battle minigames as well. Aprendice has no timer penalty for an incorrect submitted answer. Skip is resolved separately. |
| Ally deaths | Whenever an allied unit dies in battle, Aprendice gains +1 HP and +1 PWR. |

The Token floor is a safety net for a difficult session. Token awards from effects that trigger during that session count toward its total, including the Scholars Prismatic reward; tokens already held from earlier turns do not.

## 3. Scholars trait

Scholars counts Scholar-tagged units in the active lineup, including Aprendice. Aprendice always contributes one Scholar because the trait is fixed on the Hero; no separate item is required to activate the trait. Trait thresholds are cumulative.

| Level | Threshold | Effect |
|---|---:|---|
| **Bronze** | 2 Scholars | Add +1.0 second to the starting timer of each battle minigame. |
| **Silver** | 3 Scholars | In addition to Bronze, each Skip adds +1.0 extra second on top of its normal +0.5 seconds. A Skip preserves the correct-answer streak, grants no Token, and lowers that card's mastery under the current SRS rule. |
| **Gold** | 4 Scholars | In addition to Silver, a correct answer to a card at Mastery Level 1 grants 1 bonus Token. |
| **Prismatic** | 5 Scholars | In addition to all previous levels, each incorrect submitted answer adds +0.5 second to the remaining timer. This does not apply to a Skip and reaching a 3-correct-answer streak grants 1 bonus Token once per minigame. A Skip preserves the streak; an incorrect answer resets it. |

Correct answers remain the best way to extend and improve a session: they raise mastery, award their normal Token, add Timekeeper's extra second, and keep the +0.5-second base extension. Aprendice never loses time for an incorrect answer. At Gold, an incorrect answer adds +0.5 second, but still grants no Token or mastery progress and resets the streak. A Skip preserves the streak and, with Silver, adds +1.5 seconds.

### Answer and Token event rules

- Trigger combat stat and status buffs from **correct-answer events**, not from generic Token changes. The Hero's floor, death refunds, or other Token sources do not count as correct answers and must not activate answer-based buffs.
- For low-mastery effects, check the card's Mastery Level **before** recording the correct answer. Level 1 is the minimum mastery level.
- Resolve all Token awards generated by the minigame first. A correct answer normally grants 1 Token; Beginner's Charm adds 1 more for a Level 1 mastery card, and Scholars Gold adds a separate 1 for that same correct answer. If both apply, the total is 3 Tokens for that answer. Check mastery before recording the answer.
- Apply the Aprendice Token floor after those awards. The floor checks the number generated in that session, not the encounter wallet balance.
- Keep Skip and incorrect-answer outcomes distinct. Aprendice has no wrong-answer timer penalty; Gold's +0.5 second applies only to an incorrect submitted answer, while Silver's Skip bonus applies only to a Skip. The current completion payload counts Skips as incorrect, so the session data needs an explicit Skip count or outcome.
- The current `FlashcardManager._on_minigame_complete()` uses `correct < 3` for Aprendice's floor. Update it to use actual Tokens generated in the session, after the other Token awards have been resolved.
- The current `skip_minigame_question()` resets `current_streak`, while the Flashcard System documentation says Skip preserves it. Preserve the documented behavior before relying on Prismatic's streak trigger.

## 4. Unique unit lineage

The unique Tier 1 merges only with the four neutral Tier 1 recipe parents below. The four resulting Tier 2 units merge only with one another, creating all six Tier 3 pairings. Every listed ability states its Level 1 / Level 2 / Level 3 value. Proposed Tier 2 and Tier 3 stats are Level 1 base stats; ordinary level stats and merge-surplus inheritance still apply.

### Tier 1 starter

| Placeholder ID / name | Tags | Level 1 / 2 / 3 stats | Ability at Levels 1 / 2 / 3 |
|---|---|---:|---|
| `ATnkFigSch` | Air, Tank, Fighter, Scholars | 1/2, 2/3, 3/4 HP/PWR | While this unit is in the lineup, each correct answer during the battle minigame gives +1 / +2 / +3 Armor to the frontmost Scholar in the allied lineup. Token gains from other sources do not trigger this ability. Armor follows normal end-of-turn decay. |

### Tier 2 crossbreeds

| Placeholder ID / name | Recipe | Level 1 stats | Additional tags | Ability at Levels 1 / 2 / 3 |
|---|---|---:|---|---|
| `AATnkFigSpeSchFodToy` | `ATnkFigSch` + `ASpeFodToy` | 2 HP / 3 PWR | Specialist, Scholars, Food, Toy | **At minigame end:** Gain +1 / +2 / +3 PWR for each correct answer to a Level 1 mastery card in that session. |
| `EATnkFigSchPlaToy` | `ATnkFigSch` + `ETnkPlaToy` | 3 HP / 3 PWR | Tank, Fighter, Scholars, Plant, Toy | **Pre-combat:** Gain +1 / +2 / +3 Armor for each correct answer in the previous minigame. Armor decays normally at turn end. |
| `FATnkFigSchMecApp` | `ATnkFigSch` + `FFigMecApp` | 2 HP / 4 PWR | Tank, Fighter, Scholars, Mecha, Appliance | **At minigame end:** Gain +1 / +2 / +3 PWR for every 2 correct answers in that session. Count full pairs of correct answers; this does not require them to be consecutive. |
| `WATnkFigSupSchAniCos` | `ATnkFigSch` + `WSupAniCos` | 2 HP / 3 PWR | Tank, Fighter, Support, Scholars, Animal, Costume | **At minigame end:** If the player answered at least 1 card correctly, add +1 / +2 / +3 seconds to the starting timer of the next battle minigame. This is a one-session bonus, not a permanent timer increase. |

Minigame-end and pre-combat effects resolve for the living holder while it is on the player's battle board. Effects that directly target the frontmost Scholar require that Scholar to be in the active lineup.

Ability-granted HP and PWR modify the battle copy, persist for the rest of that encounter, and do not permanently change the Run Inventory unit. Temporary statuses such as Armor follow their normal duration rules.

### Tier 3 crossbreeds

All six Tier 2 pairings are recipes. Token-held scaling is concentrated here. Held-Token checks use the battle Token balance after management; ability effects scale with the holder's current unit level.

| Placeholder ID / name | Recipe | Level 1 stats | Ability at Levels 1 / 2 / 3 |
|---|---|---:|---|
| `EAAATnkFigSpeSchFodPlaToy` | `AATnkFigSpeSchFodToy` + `EATnkFigSchPlaToy` | 5 HP / 6 PWR | **Pre-combat:** Gain +1 / +2 / +3 Armor for every full 5 Tokens held. Spending Tokens on draws lowers this opening Armor. |
| `FAAATnkFigSpeSchFodMecToyApp` | `AATnkFigSpeSchFodToy` + `FATnkFigSchMecApp` | 4 HP / 7 PWR | **At minigame end:** Gain +1 / +2 / +3 PWR for each correct answer in that session. |
| `WAAATnkFigSupSpeSchFodAniToyCos` | `AATnkFigSpeSchFodToy` + `WATnkFigSupSchAniCos` | 4 HP / 6 PWR | **On death:** If defeated in battle, add +2 / +3 / +4 seconds to the starting timer of the next battle minigame. |
| `EFAATnkFigSchMecPlaToyApp` | `EATnkFigSchPlaToy` + `FATnkFigSchMecApp` | 5 HP / 7 PWR | **Pre-combat:** Gain +1 / +2 / +3 PWR for every full 5 Tokens held. This is a battle stat bonus based on the post-management balance. |
| `EWAATnkFigSupSchAniPlaToyCos` | `EATnkFigSchPlaToy` + `WATnkFigSupSchAniCos` | 5 HP / 6 PWR | **On attack:** If at least 5 Tokens are held, spend 1 Token to deal +1 / +2 / +3 bonus damage for every full 5 Tokens held before the spend. If fewer than 5 are held, do not spend a Token. |
| `FWAATnkFigSupSchMecAniAppCos` | `FATnkFigSchMecApp` + `WATnkFigSupSchAniCos` | 4 HP / 7 PWR | **At minigame end:** If the correct-answer streak reaches 3 in that session, gain +1 / +2 / +3 HP and +1 / +2 / +3 PWR. This triggers once at the first 3-streak; the separate Prismatic trait reward is one Token. |

The three Token-scaled capstones give different choices: save Tokens for Armor, save them for PWR, or spend them on an attack bonus. The other capstones turn correct answers, a three-streak, and even a battle loss into future progress or extra study time.

## 5. Unique item lineage

Item recipes change the item definition. Tier 2 items do **not** retain Koi's Blessing's heal or Tiger's Spirit's extra attack. Every recipe result below has a completely new ability.

| Item | Tier and recipe | Proposed stats | New ability |
|---|---|---:|---|
| **Study Pouch** | Unique Tier 1 | +1 HP | **On holder death:** Grant Tokens equal to the holder's Tier draw cost: 1 / 2 / 3 Tokens for a Tier 1 / 2 / 3 holder. Unit Level does not change the grant. This triggers once when the holder dies. |
| **Review Ledger** | Tier 2: Study Pouch + `item_t1_a` | +2 HP | While equipped to a unit in the lineup during a battle minigame, each correct answer to a Level 1 mastery card gives the holder +1 PWR. |
| **Answer Key** | Tier 2: Study Pouch + `item_t1_b` | +2 PWR | While equipped to a unit in the lineup during a battle minigame, every 2 correct answers give the holder +1 HP at minigame end. Count full pairs; answers need not be consecutive. |
| **Scholar's Archive** | Tier 3: Review Ledger + Answer Key | +2 HP / +2 PWR | **At minigame end:** If the holder is alive and equipped to a unit on the lineup, add +1 second to the next battle minigame's starting timer for every 3 correct answers in the completed session. This is a new ability, not a combination of the Tier 2 item abilities. |

The Study Pouch's Token grant follows the holder unit's documented battle draw cost. Unit Level does not change that cost:

| Holder | Level 1 | Level 2 | Level 3 |
|---|---:|---:|---:|
| Tier 1 | 1 Token | 1 Token | 1 Token |
| Tier 2 | 2 Tokens | 2 Tokens | 2 Tokens |
| Tier 3 | 3 Tokens | 3 Tokens | 3 Tokens |

Gold valuation is a separate economy and doubles at each Level. For example, a Tier 1 Level 3 unit is worth 4 Gold and a Tier 3 Level 3 unit is worth 16 Gold; those values do not change the Pouch's Token grant.

### Scholar Emblem

| Item | Tier and recipe | Proposed effect |
|---|---|---|
| **Scholar Emblem** | Tier 3 standalone item | Adds 1 Scholar counter to its holder while the holder is in the active lineup. For each enemy unit the holder defeated in the previous combat, add +1 second to the next battle minigame's starting timer. |

Combat follows the minigame, so Emblem kills add time to the **next** minigame. The added Scholar counter counts only while its holder is in the active lineup.

## 6. Supporting trinkets

| Trinket | Proposed effect |
|---|---|
| **Study Hall Bell** | Before the minigame at the start of each battle turn, including Turn 1, summon a Level 1 `ATnkFigSch` into the first open lineup slot. If the lineup is full, use an open bench slot; if both are full, do nothing. This is a battle-only summon and is not added to the permanent run deck. |

Study Hall Bell needs a pre-minigame hook: current battle flow runs the minigame before ordinary `on_turn_start` abilities and suppresses those abilities on Turn 1. Summoned units use the normal board-entry, combat, death, and merge rules.

## 7. Balance and implementation notes

- Correct answers are the primary power source: they grant mastery, the normal Token and timer extension, and trigger Scholar unit/item effects. Level 1 correct answers reward successful review of the hardest cards.
- Skip remains useful when the player is unsure. It gives its base time extension, preserves streak, and gains Silver's extra second. A wrong answer never gains mastery or a Token and breaks the streak; with Silver, choosing Skip provides more time than answering incorrectly.
- Generic Tokens from Aprendice's floor, Study Pouch, or another ability do not trigger answer-based stat buffs. Only a correct-answer event does that.
- Token saving is a Tier 3 combat choice. Token thresholds use the current battle balance after management; spending on a draw can reduce the next pre-combat scaling bonus. The attack capstone converts one held Token into damage when the threshold is met.
- There are no machine draw discounts in this unit or item set.
- Tier 1's Armor effect needs an answer event with the card's correctness. Low-mastery rewards need the card's pre-answer mastery level. Session tracking should expose correct-answer counts, correct Level 1 answers, and whether a 3-streak occurred.
- The starting timer bonus and Study Hall Bell must resolve before the minigame begins. The next-minigame time bonuses from a death, Emblem kill, or item resolve after that session and apply on the following battle turn.

## 8. Source alignment and assumptions

This proposal follows the GDD's 1 / 4 / 6 Hero-unit recipe structure, 1 / 2 / 3 Token draw costs at all unit Levels, active-lineup trait counting, 1–5 flashcard mastery levels, and normal unit leveling and merge-surplus inheritance. It keeps Starter's 10 HP / 2 PWR base, the 3-Token session floor, +1 HP / +1 PWR per allied death, and an extra +1.0 second per correct answer.

`Sch` is added to the placeholder naming convention for Scholars. The unique Tier 1 unit's Air soul and Tank/Fighter traits, and the exact ability amounts, are design proposals. The trait follows the game's standard 2 / 3 / 4 / 5 unit threshold ladder. The Skip streak behavior matches the Flashcard System documentation; the current `FlashcardManager.gd` implementation resets streak on Skip and needs alignment.
