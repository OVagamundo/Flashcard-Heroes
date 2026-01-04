# Audio System Documentation

## Overview
The audio system in *Flashcard Heroes* is built around a central `AudioManager` singleton. It handles:
-   **SFX Playback**: Fire-and-forget sound effects with pitch variance for realism.
-   **Music Management**: Smooth crossfading between background music tracks.
-   **Volume Control**: Integrated with Godot's AudioServer buses (Master, Music, SFX).

## Technical Architecture

### 1. AudioManager (Global Scope)
-   **Script**: `res://scripts/AudioManager.gd`
-   **Access**: `AudioManager.play_sfx("id")` (global autoload/singleton access).
-   **Pooling**: Uses a pool of `AudioStreamPlayer` nodes to prevent instantiation stutter.
-   **Registry**: Loads sound resources from `res://assets/audio/` and maps them to string IDs.

### 2. Integration Pattern
-   **UI**: Button clicks are hooked in `GlobalInteractionRouter` or via custom button scripts.
-   **Combat**: `BattleAnimator` emits signals or calls `AudioManager` directly during animation events (Damage, Death, Summon).
-   **Shop**: Specialized shop logic triggers coin and gacha sounds.

---

## Asset Sourcing Guide

We use **Creative Commons Zero (CC0)** assets to ensure commercial safety. The primary source is **Kenney**, known for high-quality, cohesive game assets.

### Recommended Asset Packs

Please download the following packs and extract them into `res://assets/audio/`:

#### 1. UI Sounds (Clicks, Hovers, Alerts)
*   **Name**: Kenney UI Audio
*   **Source**: [Kenney.nl](https://kenney.nl/assets/ui-audio) or [OpenGameArt Direct](https://opengameart.org/content/ui-audio-0)
*   **Target Folder**: `res://assets/audio/sfx/ui/`
*   **Files Needed**:
    -   `click1.ogg` -> `ui_click`
    -   `switch1.ogg` -> `ui_hover`
    -   `error1.ogg` -> `ui_error`

#### 2. RPG Combat Sounds (Hits, Magic)
*   **Name**: Kenney RPG Audio
*   **Source**: [Kenney.nl](https://kenney.nl/assets/rpg-audio)
*   **Target Folder**: `res://assets/audio/sfx/combat/`
*   **Files Needed**:
    -   `chop.ogg` / `handleCoins.ogg` (repurposed) -> `combat_hit`
    -   `footstep00.ogg` -> `combat_step`

#### 3. Casino/Gacha Sounds (Chips, Cards, Dice)
*   **Name**: Kenney Casino Audio
*   **Source**: [Kenney.nl](https://kenney.nl/assets/casino-audio) or [OpenGameArt Direct](https://opengameart.org/content/casino-audio-0)
*   **Target Folder**: `res://assets/audio/sfx/shop/`
*   **Files Needed**:
    -   `chipLay1.ogg` -> `coin_land`
    -   `cardSlide1.ogg` / `cardPlace1.ogg` -> `ui_card_flip`
    -   `dieThrow1.ogg` -> `shop_reroll`

### Directory Structure
```
res://
  assets/
    audio/
      bgm/      # Background music files
      sfx/      # Sound effects
        ui/
        combat/
        shop/
```

## Adding New Sounds
1.  Place the `.ogg` or `.wav` file in the appropriate folder.
2.  Open `scripts/SoundRegistry.gd` (or `AudioManager.gd`).
3.  Add the mapping: `"my_new_sound": preload("res://assets/audio/sfx/my_file.ogg")`.
4.  Call it in code: `AudioManager.play_sfx("my_new_sound")`.
