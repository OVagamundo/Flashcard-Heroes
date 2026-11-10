# Flashcard Heroes — UI/UX & Typography Design Principles

> **Document Type:** Master Visual & UX Design Specification  
> **Status:** Authoritative Standard — Implemented Across All Game UI  
> **Target Audience:** Engineering, Technical Artists, UI/UX Designers  
> **Scope:** Screen Resolutions, Typographic Hierarchy, Color Systems, Accessibility (WCAG), Layout Rules, and Mobile Readability

---

## 1. Core Philosophy: Mobile-First Legibility & Tactical Clarity

*Flashcard Heroes* is a tactical roguelike deckbuilder played on desktop displays and mobile devices (smartphones and tablets). The UI must communicate critical tactical information—unit stats, elemental synergies, combat triggers, status effects, and merge previews—instantly and effortlessly.

### 1.1 Non-Negotiable UX Laws
1. **The Mobile Arm's-Length Rule:** All critical gameplay text (descriptions, keywords, stats, titles) must be effortlessly legible when held at arm's length on a 5.5-to-6.5-inch mobile screen (rendered at 1080p canvas resolution).
2. **Strict Typographic Scale (No Ad-Hoc Font Sizes):** Every label, rich text block, and button in the game must draw from the standardized scale defined in Section 2. Ad-hoc pixel sizes (e.g. 14px, 17px, 32px body) are prohibited.
3. **Minimum Legibility Floor (18px Absolute Minimum):** Under NO circumstances may any visible gameplay or UI text fall below **18px** in the 1920x1080 canvas. Microscopic text (12px–16px) is completely banned.
4. **WCAG AA Contrast on Card Surfaces (4.5:1 Minimum):** The game's primary UI panel is an off-white/light-grey parchment/card background (`panel_v4.png`). All text colors, keywords, and badges rendered against this surface must satisfy a minimum contrast ratio of **4.5:1** (3:1 for large display titles). Washed-out pastel tints (pale yellow, neon cyan, faint pink) are prohibited on light backgrounds.
5. **Full-Width Text Flow (No Narrow Straws):** Text descriptions must never be artificially constrained into narrow vertical strips (e.g. < 240px) to make room for redundant miniature art. Body copy requires sufficient horizontal measure (320px–360px on root cards, 240px–260px on glossary cards) to sustain natural 40–55 character line lengths.
6. **Breathing Room (Zero Negative Line Spacing):** Negative line separation (`line_separation < 0`) is strictly prohibited. RichTextLabels must maintain positive line separation (+2px to +4px) and clear paragraph separation (+6px to +8px) to prevent ascender/descender collisions.

---

## 2. Standardized Typographic Hierarchy

All typography in the game is calibrated for the master viewport of **1920 × 1080** running with `canvas_items` stretch mode.

| Hierarchy Level | Font Size | Line Separation | Font Style / Weight | Primary Use Cases |
| :--- | :---: | :---: | :---: | :--- |
| **Display / Hero** | `42px – 48px` | `0px` | Bold / Black | Floating damage numbers, Victory / Defeat banners, Draft title |
| **Title 1 (Screen Header)** | `32px – 36px` | `0px` | Bold / Black | Modal titles ("Shop", "Rest Site", "Unit Training", "Replay Browser") |
| **Title 2 (Window Header)** | `26px` | `0px` | Bold / Black | Root inspection titles (Unit name, Item name, Trait header) |
| **Title 3 (Card / Section)** | `22px` | `0px` | Bold | Glossary card titles ("Burn", "Melee Attack"), Section headers ("Equipped Items", "Attack Override:") |
| **Body Primary** | `22px` | `+3px` | Normal / Bold for terms | Primary unit ability descriptions, item descriptions, tutorial narrative |
| **Body Secondary** | `20px` | `+3px` | Normal / Bold for terms | Glossary child card descriptions, equipped item sub-descriptions |
| **Metadata / Badges** | `18px` | `0px` | Bold / Semi-bold | Trait pills (`1x Fire`, `Novice`), attack hints (`(Frontmost)`), stat suffixes (`(+2 PWR)`) |

---

## 3. High-Contrast Accessible Color System

The primary card surface (`panel_v4.png`) presents an average luminance of `#E8E8E8`. To guarantee instant readability and accessibility, all text colors are calibrated for high contrast against this surface.

### 3.1 Unit Tier & Inspection Title Colors

| Tier | Semantic Meaning | Color Value | Hex Code | Contrast Ratio on Card |
| :---: | :--- | :--- | :---: | :---: |
| **Tier 1** | Elemental Form | Deep Rich Bronze / Amber | `Color(0.52, 0.30, 0.05)` | `#854D0E` (5.2:1) |
| **Tier 2** | Complex Animal | Deep Crimson Violet / Purple | `Color(0.44, 0.10, 0.46)` | `#701A75` (6.8:1) |
| **Tier 3** | Anthropomorphic Hero | Deep Royal Navy / Azure | `Color(0.12, 0.23, 0.54)` | `#1E3A8A` (8.5:1) |
| **Default** | Neutral / Items / General | Dark Slate / Charcoal | `Color(0.06, 0.09, 0.16)` | `#0F172A` (13.5:1) |

*(Note: Legacy raw neon primaries such as `Color.YELLOW`, `Color.CYAN`, and `Color.MAGENTA` are retired because their contrast on light panels fell below 1.8:1).*

### 3.2 Combat Effects & Gameplay Keywords (`DescriptionParser.KEYWORDS`)

All gameplay keywords injected into RichTextLabels by `DescriptionParser` must use rich, saturated tones:

| Keyword | Semantic Domain | Canonical Hex | Visual Character |
| :--- | :--- | :---: | :--- |
| **`BURN`** | Damage-over-time | `#C2410C` | Vivid Burnt Orange / Fiery Rust |
| **`STATIC`** | Detonation damage | `#B45309` | Electric Deep Amber / Honey |
| **`ARMOR`** | Damage mitigation | `#1D4ED8` | Royal Cobalt Blue |
| **`SPIKES`** | Retaliation damage | `#15803D` | Forest Emerald Green |
| **`REINFORCE`** | Armor enhancement | `#0E7490` | Deep Ocean Cyan / Teal |
| **`BOUNTY`** | Economy boost | `#92400E` | Rich Amber Bronze |
| **`SHOCKWAVE`** | Row-piercing damage | `#7E22CE` | Royal Amethyst / Deep Violet |
| **`MELEE`** | Direct contact clash | `#B91C1C` | Strong Brick Red |
| **`RANGED`** | Mirror / Backline strike | `#1D4ED8` | Strong Cobalt Azure |
| **`BOUNCE`** | Chained ricochet | `#0369A1` | Deep Azure Blue |
| **`EMPOWERED_ATTACK`** | Primed special strike | `#C2410C` | Burnt Vermilion |
| **`EXTRA_ATTACK`** | Chained bonus attack | `#A16207` | Deep Goldenrod |
| **`EXTRA_ACTION`** | Full turn re-queue | `#C2410C` | Rich Crimson Orange |
| **`INTERCEPT`** | Defensive leap | `#166534` | Deep Pine Green |
| **`LIFESTEAL`** | Health drain | `#9F1239` | Rich Wine / Ruby |
| **`ATTACK_OVERRIDE`** | Replaced basic attack | `#9A3412` | Deep Ochre |

### 3.3 Trigger Phrases & Constitutional Conditions

All constitutional trigger phrases (e.g. `At Battle Start`, `When Attacking`, `At Minigame End`, `When Knocked Out`) are highlighted inline by `DescriptionParser`:
- **Trigger Highlight Hex:** `#9A3412` (Deep Warm Ochre / Mahogany)
- **Formatting:** `[color=#9A3412][b]Trigger Phrase[/b][/color]`
- **Contrast Ratio:** > 5.6:1 against `#E8E8E8`.

### 3.4 Trait Pills & Badges

Trait pills are compact metadata badges rendered via `PanelContainer` with rounded corners (radius 6px):
- **Base Color:** Trait thematic hue (Fire Red, Earth Ochre, Water Blue, Air Cyan, Tank Slate, Fighter Crimson, etc.).
- **Typography:** `18px` Bold, centered vertically and horizontally.
- **Text Color Rule:**
  - Dark/Saturated Pills (Fire, Tank, Fighter, Specialist, Air, Earth, Water, Mecha, Costume): `#FFFFFF` with subtle dark outline `Color(0, 0, 0, 0.75)` (size 2).
  - Light/Warm Pills (Novice, Appliance, Mercenary, Food): High-saturation background or rich amber hue to guarantee white text contrast > 4.5:1.
  - Sizing: Content margin horizontal 8px, vertical 3px.

---

## 4. Inspection Window Architecture & Spatial Rules

### 4.1 Root Inspection Card Anatomy (`UnitInspectionWindow`, `ItemInspectionWindow`)
- **Total Card Width:** Standardized to `360px` (or `380px` when secondary glossary cards dock).
- **Layout Order (Vertical Column):**
  1. **Window Title (`NameLabel`):** Size `26px`, Bold, Tier-tinted or Charcoal, centered.
  2. **Trait Tag Row (`TraitTagsContainer`):** Compact flex-wrap row of 18px pills, centered.
  3. **Attack Row (`AttackRow`):** Size `20px`, Bold category tag + muted target hint `(Frontmost)`.
  4. **Description Block (`DescriptionLabel`):** **Full width** (320px–336px readable area). Size `22px`, `line_separation = 3`, `p_separation = 6`. Zero artificial horizontal splitting.
  5. **Equipped Items Block (`EquippedContainer`):** Section title `20px` Bold, item entries with `20px` title and `18px` body.
  6. **Recipe / Evolution Block (`RecipeContainer`):** Centered ingredient icons with `+` and `=` operator glyphs.
- **Removal of Redundant Thumbnail Straws:** Root inspection tooltips do not squeeze body descriptions beside duplicate miniature unit puppets. The player is already looking directly at the unit on the board. In modal merge preview (`ChoiceWindow`), the resulting unit is rendered cleanly centered in the dedicated preview container.

### 4.2 Glossary Micro-Cards (`EffectInspectionWindow`)
- **Standardized Width:** `260px` (expanded from 210px to accommodate larger 20px typography without excessive vertical wrapping).
- **Title (`NameLabel`):** `22px` Bold, colored with the canonical effect hex.
- **Description (`DescriptionLabel`):** `20px`, `line_separation = 3`, autowrap mode Word Smart.
- **Docking & Packing:** Positioned automatically to the right (or left fallback) of the root window with `8px` gap, clamped safely inside viewport margins (`16px`).

---

## 5. Description Parsing & Localization Laws

1. **No Raw BBCode in Source Strings:** Localization files (`localization/game.csv`) must contain clean, semantic text without hardcoded `[color=...]` tags.
2. **Single Source of Truth (`DescriptionParser`):** All keyword highlighting, trigger phrase coloring, and glossary term detection are performed dynamically at runtime by `DescriptionParser`.
3. **Punctuation Hygiene:** Punctuation (commas, periods, colons) must immediately follow closing words or tags without leading whitespace (e.g. `At Minigame End,` never `At Minigame End ,`).
4. **Current-Level Evaluation:** Ability numbers with slash progression (e.g. `1 / 2 / 3`) are evaluated to the inspected unit's exact current level via `DescriptionParser.resolve_level_scaling()`.
