# Drag Delay Investigation Conclusion

## The Core Finding
After extensive investigation and multiple attempted fixes (hacks, deferred updates, simulated input), the issue has been identified as an **OS-level behavior specific to macOS "Three Finger Drag"**.

### Evidence
1.  **Symptom**: ~1s delay after "release" (lifting fingers) before the drop registers visually.
2.  **Reproduction**: The user observes similar delay behavior when dragging files in macOS Finder using the same gesture.
3.  **Mechanism**: The "Three Finger Drag" accessibility feature in macOS introduces a delay after lifting fingers to distinguish between a "stop drag" and a "lift to reposition fingers" (clutching). The OS holds the mouse button "down" virtually for a short period (~500ms-1s) in case the user puts their fingers back down to continue dragging.
4.  **Why "Mouse Move" Fixed It**: Moving the mouse (or tapping) immediately signals to the OS that the drag gesture is definitely over or that a new action has started, forcing the virtual mouse button release.

## Conclusion
The delay is **native macOS behavior** intended to improve usability for trackpad users. It is **not a bug in the game**. Any attempt to "fix" this in-game would require fighting the OS's input emulation, which is unreliable and bad practice.

## Action Taken
- [x] Identified OS-level cause.
- [ ] Rollback "Warp Hacks" and synthetic input attempts (cleaning up the codebase).
- [ ] Verified that Click-and-Click is the recommended workaround for instant interaction on trackpads.
