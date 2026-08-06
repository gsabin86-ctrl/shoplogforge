# ShopLog Android

Offline Android WebView wrapper for the self-contained ShopLog app.

- Application ID: `com.texasswiss.shoplog`
- Minimum Android: 8.0 (API 26)
- ShopLog data stays in the app's local WebView storage.
- The app respects Android status, camera-cutout, and navigation safe areas.
- Backups, CSV files, and Word setup sheets save to `Downloads/ShopLog`.
- Import opens Android's document picker.
- Web links such as CNC Toolbase open in the default browser.

Run `build.ps1` to create `build/ShopLog-Android.apk`. The script uses
`ANDROID_SDK_ROOT` and `JAVA_HOME` when set; local Codex toolchain paths are
detected automatically in the original workspace.
