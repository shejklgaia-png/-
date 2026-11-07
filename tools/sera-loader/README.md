# SERA Loader — Android 15 test app

This is an **experimental build**, not yet verified on an Xperia 1 V.

## What it does
- Displays a temporary, non-interactive SERA loading overlay.
- Allows accessibility interactions to reach the Godot editor beneath the overlay, using `FLAG_NOT_TOUCHABLE` and window alpha `0.78` (below Android 12+ maximum obscuring opacity `0.8`).
- Automatically times out after 120 seconds. A notification has an emergency **Close** action.
- Does not change any existing Termux or Godot files. The Automate flow remains responsible for sync, Godot launching, and hiding the overlay.

## Build
- JDK 17, Android SDK 35, Gradle 8.13, Android Gradle Plugin 8.13.2.
- `gradle :app:assembleDebug` from this folder.
- Output: `app/build/outputs/apk/debug/app-debug.apk`.
- To build using your existing SERA GitHub repo: unzip this project into `tools/sera-loader` and copy `.github/workflows/sera-loader-build.yml` to the repository root `.github/workflows/sera-loader-build.yml`. Push the commit; Actions builds the APK. The `install_into_sera_repo.sh` script automates those operations with clean-tree checks.

## Install and first run
1. Install APK, open **SERA Loader** from the app drawer.
2. Tap **重ねて表示を許可** and enable the SERA Loader app in Android Settings.
3. Return and tap **ロード画面をテスト表示**. It should overlay your home screen but allow taps through it. Use the notification **閉じる**, reopen the app to stop, or allow it to timeout.
4. If the screen blocks interactions, stop the service immediately and report the result; do not continue to integrate with Automate.

## Automate integration (after test)
Wire a new flow or extend `SERA_Launch`:

1. **App start**
   - Package: `dev.sera.loader`
   - Activity class: `dev.sera.loader.OverlayLaunchActivity`
   - Action: `android.intent.action.MAIN` (optional / leave blank preferred)
   - Data URI, MIME type, Category, Extras: empty
2. **Delay** Exact `0.5` seconds, Wake up No.
3. Existing **Service start** calls the original Termux `SERA_start` in background mode, unchanged.
4. **App foreground** Immediately, Package `org.godotengine.editor.v4`, Activity class `org.godotengine.editor.GodotGame`. YES -> step 6, NO -> step 5.
5. **App foreground** When changed, same package/class, YES -> step 6, NO -> step 5 (only wait for it to become foreground).
6. **Broadcast send**
   - Package `dev.sera.loader`
   - Receiver class `dev.sera.loader.HideReceiver` (if available; otherwise leave blank and use Package)
   - Action `dev.sera.loader.HIDE` (plain text; if fx enabled quote it)
   - Data URI/MIME type/Category/Extras/Flags: empty/default

Do not use `App start` to open `MainActivity` in the everyday flow. That is the setup/test screen. Use `OverlayLaunchActivity`.

## Limitations
- Android's `TYPE_APPLICATION_OVERLAY` is below system UI and may be hidden by the system or other apps.
- Activity `GodotGame` indicates screen transition, NOT actual rendered frame completion.
- The mask is semitransparent, not fully opaque. Attempts at full opacity can block touch-through on Android 12+.
- Because the app is unsigned-release/debug-signed, the APK should be treated as a test APK, not a production distribution.
- Workflows are not modified automatically by this ZIP; nothing is installed on the phone until you install the APK.
