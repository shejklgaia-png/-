# SERA Loader 0.2: opaque Accessibility Overlay test

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
