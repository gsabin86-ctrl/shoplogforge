# ShopLog for iPhone

Native iPhone wrapper for the shared offline ShopLog interface.

## Behavior

- Uses persistent `WKWebView` storage inside the iPhone app container
- Keeps production records, orders, setups, and tools on the device
- Respects the status bar, Dynamic Island/notch, and home indicator
- Saves JSON, CSV, and Word exports to `On My iPhone/ShopLog/Exports`
- Uses the iOS document picker for JSON imports
- Opens CNC Toolbase links in the default browser

## Generate and run on a Mac

1. Install current Xcode from the Mac App Store.
2. Install XcodeGen: `brew install xcodegen`
3. Run `./generate-project.sh` inside this folder.
4. Open `ShopLog.xcodeproj` in Xcode.
5. Select your Apple development team under **Signing & Capabilities**.
6. Connect an iPhone, select it as the run destination, and press **Run**.

The bundle identifier is `com.texasswiss.shoplog`. Change it in `project.yml`
if that identifier is already registered to another Apple developer team.

## Distribution

An Apple Developer Program membership is required for TestFlight, App Store, or
managed business distribution. The final signed iPhone build must be created
with Xcode on macOS.

