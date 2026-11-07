# SERA Loader 0.3: electronic pixel-rise overlay

An experimental Android 15 build, isolated from existing SERA game, Godot, Termux, GitHub sync, and Automate files. The old 78% app overlay is retained.

## Why Accessibility?
Android 12+ normally restricts touches through an opaque standard overlay, but TYPE_ACCESSIBILITY_OVERLAY is a trusted window type. This version shows an opaque overlay with FLAG_NOT_TOUCHABLE and FLAG_NOT_FOCUSABLE. It does not inspect or record accessibility events, retrieve the screen, or inject gestures. Use it only if you approve enabling its sensitive Android Accessibility setting.

## Install & test
1. Download SERA-Loader-debug-apk from the Build SERA Loader APK workflow, unzip and install.
2. Debug signatures may change between GitHub Actions builds: if upgrading fails, uninstall the older SERA Loader app only (no game data is stored in it), then install the new APK.
3. Open SERA Loader, press 3 to open Accessibility Settings. Enable SERA Loader 全画面表示. Sideloaded apps may require app info > menu > allow restricted settings.
4. Return to the loader app and confirm the status says connected. Press 4 to start the fully opaque test.
5. Check that taps can reach apps on the home screen underneath, and that Automate's existing Godot editor steps still work. Full-screen overlays may interfere with screenshot-driven automation even when normal touch passes through.
6. To dismiss, use the notification Close action if available, the Loader app stop button, turn off the Accessibility service, or let the 120-second timeout expire.
7. Do not modify the Automate launch workflow until the above passes.

## Automate wiring after the manual test
- App start: Package dev.sera.loader; Activity class dev.sera.loader.OverlayLaunchActivity; other fields blank.
- Delay: Exact; 0.5 seconds; Wake up No.
- Existing Termux Service start runs the existing SERA_start script with RUN_COMMAND_BACKGROUND=true.
- App foreground: check Package org.godotengine.editor.v4; Activity class org.godotengine.editor.GodotGame; first Immediately, then When changed until YES.
- Broadcast send on YES: Package dev.sera.loader; Receiver class dev.sera.loader.HideReceiver; Action dev.sera.loader.HIDE; others blank/default.
- GodotGame signals an Activity switch, not rendered-frame readiness.

If accessibility is disabled, OverlayLaunchActivity opens the app setup screen instead of attempting an untrusted overlay.


## v0.3: digital waterfall background

- A procedurally rendered background fills from the **bottom to the top** with large square digital pixels over about 3.6 seconds.
- Light-blue, deep-blue, cyan, and white square particles stream upward continuously, even once the screen has filled.
- The central SERA helmet icon, typography, indicator, opacity and placement are **unchanged**.
- Uses the Android Canvas API (no video decoder, network dependency, or third-party libraries).
- The view schedules approximately 30 frames per second and stops drawing when removed.
- Existing accessibility touch-through, manual dismiss, 120-second timeout, Automate show/hide broadcast and Git sync are unchanged.
- If the build uses a new debug signing key, uninstall only the previous SERA Loader test app and then install the updated APK; user-enabled accessibility permission may need re-enabling.

### Manual verification
1. Tap the existing "4 完全不透明ロード画面をテスト" button.
2. Verify the first frames are dark and square particles rise from the bottom, progressively covering the background.
3. Confirm the face icon stays fixed at center and text/progress are visible.
4. Confirm the overlay is still opaque but taps pass through to apps behind it.
5. Run the existing Automate SERA_Launch_Loader after confirming a manual test, then verify the usual GodotGame-triggered dismissal.


## v0.4: staged blue fill then training grid

Replaces the continuous confetti particle waterfall from v0.3 with exactly two finite animation phases:

1. About 1.9 seconds: closely spaced vertical stripes climb from the bottom. Only their ragged, moving tips have three short layers of white, pale blue and cyan; all completed pixels below are **uniform solid blue** (#195AA2).
2. 0.3 seconds: the entire background holds **solid blue** with no white, particles, grid or shading.
3. About 1.55 seconds: a square dark grid grows from the bottom with a slightly irregular leading edge. The grid color (#111821) and square proportions are based on the actual SERA training ground's unshaded 4-meter grid in scripts/main.gd. On the loader, screen-space cell spacing is 64dp.
4. Final: solid #195AA2 blue with #111821 square lines. There is **no movement, noise, glow, gradient, flicker, or animation** after the full grid is revealed.

The existing centered helmet graphic, captions and loading progress bar are not changed. The accessibility overlay and Automate integration continue to use the previous API and package/activity. The animation auto-stops drawing after 3.75s.

Development: source is PixelRiseView.java. Durations and palette are constants at the top.


## v0.5 – Blue-only background, gradient, micro-particles

The solid charcoal fullscreen backing has been replaced by a blue gradient.
The original digital columns form a brighter three-stop blue gradient,
retaining three uneven white-to-cyan leading stripes. Small 2–7dp square
particles and faint edge highlights make both formation phases more detailed.
The training-room square grid has brief cyan/white illuminated edges as it
builds upward. After the original 3.75-second timeline completes, ALL
particle/glint animation stops, leaving only the static blue gradient
and dark square training grid (#111821). Full opacity, the central SERA
helmet/logo, other UI, 120s timeout, accessibility service and Automate
show/hide commands are unchanged.
