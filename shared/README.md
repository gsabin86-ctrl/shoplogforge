# Shared ShopLog app

`shoplog.html` is the shared offline ShopLog interface used by both mobile
wrappers:

- `android/assets/shoplog.html`
- `ios/ShopLog/Resources/shoplog.html`

Platform build scripts copy this file into their app bundle. Keep browser-side
features in the shared file and platform-only behavior in the native wrappers.

