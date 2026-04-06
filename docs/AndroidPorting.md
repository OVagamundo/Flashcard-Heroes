# Android Porting & Mobile Optimization

This document tracks specialized techniques used to ensure consistent performance and visual fidelity on Android and other mobile platforms.

## 1. UI Rendering Isolation (SubViewport)

To resolve common mobile rendering issues such as dithered artifacts, incorrect background scaling, and platform-specific shader glitches, the application utilizes a **SubViewport Isolation** technique.

### Implementation
Instead of rendering the UI directly to the root window, the main game content is nested within a `SubViewport`:
```
Main.tscn
└── ContentArea (SubViewportContainer)
    └── SubViewport
        ├── SceneBackground (FullScreen)
        └── VBoxContainer (Centering Layout)
```

### Benefits
- **Opaque Backgrounds**: Ensures the background image spans the entire screen, including areas that might be treated as "safe zones" or "notches" by different mobile OS versions, preventing grey or dithered bars.
- **Shader Stability**: High-precision post-processing shaders (like Glow) are more stable when rendered within a fixed-size `SubViewport` before being composited to the screen.
- **Input Parity**: Touch coordinates are correctly mapped to UI elements without needing manual offsets for OS bars.

## 2. Platform Detection

Specialized logic is gated via `OS.has_feature("mobile")`:
- **Cursor System**: Custom software cursors are disabled on mobile by default (`CursorManager.gd`).
- **Touch-to-Hover**: Hover logic (Inspection windows) is adapted to touch behavior using **Long Press** detection in `InputUtils.gd`.

## 3. Performance Optimization

- **VCR Decoupling**: The simulation-at-start (VCR) model reduces per-frame CPU load during heavy combat turns, which is critical for maintaining 60 FPS on lower-end mobile devices.
