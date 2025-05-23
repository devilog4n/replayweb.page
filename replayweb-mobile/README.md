# ReplayWeb iOS

A **native iOS** port of [ReplayWeb.page](https://github.com/webrecorder/replayweb.page),  
using a **Custom URL-Scheme Handler** (`app://`) in SwiftUI to serve all assets and WARC archives  
with full Service-Worker support.

---

## Features

- Bundle web assets under `www/`  
- Custom `WKURLSchemeHandler` (`AppSchemeHandler.swift`)  
- Secure origin hack for `app://` registration  
- SwiftUI `WebView` loader at `app://index.html`  
- Task-driven development via TaskMaster AI MCP  

---

## Prerequisites

- **macOS 12+** with **Xcode 14+**  
- **CocoaPods**  
- **Node.js 16+** & **npm**  
- **TaskMaster AI CLI** (`npm install -g task-master-ai`)  
- Your TaskMaster API keys configured in `.env` or Windsurf’s `mcp_config.json`

---

## Setup

1. **Clone this repo & web assets**  
   ```bash
   git clone https://github.com/your-org/replayweb-ios.git
   git clone https://github.com/webrecorder/replayweb.page.git ../replayweb.page
   ```

2. **Build web assets**  
   ```bash
   cd ../replayweb.page
   npm install
   npm run build
   cp -R dist/* ../replayweb-ios/www/
   ```

3. **Initialize TaskMaster**  
   ```bash
   cd ../replayweb-ios
   task-master init
   task-master parse-prd --input=scripts/ios_replayweb_prd.txt
   task-master list
   ```

4. **Work through tasks**  
   ```bash
   task-master next
   task-master generate <TASK_ID>
   # implement code...
   task-master set-status --id=<TASK_ID> --status=done
   ```

---

## Build & Run (iOS)

1. **Install JS deps & Capacitor plugins**  
   ```bash
   npm install
   npm install @capacitor/core @capacitor/cli @capacitor/ios @capacitor-community/http
   ```

2. **Add iOS platform & copy assets**  
   ```bash
   npx cap add ios
   npx cap copy ios
   ```

3. **CocoaPods & open Xcode**  
   ```bash
   cd ios/App
   pod install
   open App.xcworkspace
   ```

4. **Run in Xcode**  
   Select a simulator or device and click **Run**.  
   In the Xcode console you should see:
   ```
   Local HTTP server running at app://index.html
   ```
   and the app’s WKWebView will load your offline ReplayWeb UI.

---

## Project Layout

```text
replayweb-ios/
├─ ios/
│  ├─ App/
│  │  ├─ AppDelegate.swift
│  │  ├─ ContentView.swift
│  │  ├─ AppSchemeHandler.swift
│  │  ├─ Info.plist
│  │  └─ ReplayWeb.xcodeproj
│  └─ Podfile
├─ www/
│  ├─ index.html
│  ├─ js/
│  │  ├─ app.js
│  │  └─ server.js
│  └─ warc-data/
├─ scripts/
│  └─ ios_replayweb_prd.md
├─ .taskmasterconfig
├─ capacitor.config.json
└─ package.json
```

---

## Notes & Troubleshooting

- **Secure-scheme hack**  
  We use the private API `_registerURLSchemeAsSecure:` to treat `app://` as a secure origin so Service Workers run.  
  This is undocumented and may risk App Store review. Consider [App-Bound Domains](https://developer.apple.com/documentation/bundled_web_content/) as an alternative.

- **WARC files**  
  All `.warc` archives to replay must live in `Documents/warc-data/`. Copy them on first-launch or download them at runtime.

- **Service Worker failures**  
  If you see “Service Worker registration failed,” ensure your `WKURLSchemeHandler` registration (and secure-scheme hack) occurs **before** any `WKWebView` is created.

- **Updating web assets**  
  After rebuilding `replayweb.page`, rerun:
  ```bash
  cp -R ../replayweb.page/dist/* www/
  npx cap copy ios
  ```
  then rebuild in Xcode.

Happy coding! 🚀
