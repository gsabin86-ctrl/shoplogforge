# ShopLog Forge

Phone-first production tracking and ECAS-20 machine setup sheets.

## Run the app

No build or package installation is required. Open `index.html` directly, or
serve this folder with any static web server.

For example:

```bash
npx serve .
```

Then open the local URL shown in the terminal.

## Included features

- Production, OEE, orders, machines, and downtime tracking
- Permanent editable tool library
- ECAS-20 setup sheets with 1–24 available stations
- Tool assignments pulled from the master library
- Expandable saved setup reviews
- Completed setup sorting by part number and program number
- CNC Toolbase search links
- JSON and CSV exports with optional folder-aware saving

App data is stored in the browser on the device where it is entered. Export
regular backups from ShopLog, especially before clearing browser data or moving
to another device.

## Android app

The `android/` folder contains the offline Android wrapper. It bundles ShopLog
inside a permanent app installation so refreshes do not depend on temporary
file-browser access. Android exports are written to `Downloads/ShopLog`, and
JSON imports use the system file picker.

The build requires Android Platform 36, Build Tools 36.0.0, and Java 17 or
newer. Run `android/build.ps1` to create `android/build/ShopLog-Android.apk`.
