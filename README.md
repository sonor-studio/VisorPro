# VisorPro

VisorPro is an advanced, lightweight macOS utility designed to elevate your system experience by providing sleek, customizable on-screen displays (OSD) and trackers for everyday system events. Say goodbye to the native macOS volume and brightness overlays, and embrace a modern aesthetic that seamlessly integrates with your workspace.

## ✨ Features

- **Custom OSD Overlays**: Beautifully redesigned, non-intrusive visual indicators for Volume, Display Brightness, and Keyboard Brightness.
- **System Trackers**: Real-time monitoring for Battery, Wi-Fi, Bluetooth, Peripherals, and Mac System states (CPU, RAM).
- **Media Controls**: Enhanced visual feedback when playing/pausing or skipping media.
- **Menu Bar Integration**: Runs quietly in your menu bar (as an accessory app) with easy access to a rich Settings dashboard.
- **Highly Customizable**: Personalize the look, feel, and behavior through a robust split-view Settings interface.
- **Lightweight & Native**: Built entirely with Swift and SwiftUI for a minimal footprint and maximum performance.

## 🖼️ Overlay Styles

VisorPro offers multiple themes and layouts to match your preference. Below are previews of the available overlay styles:

### Dark Mode
![Dark Overlay](VisorPro/Resources/overlay-dark.png)

### Light Mode
![Light Overlay](VisorPro/Resources/overlay-light.png)

### Expanded View
![Expanded Overlay](VisorPro/Resources/overlay-expanded.png)

## 🚀 Requirements

- **macOS**: macOS 14.0 (Sonoma) or newer.
- **Xcode**: Xcode 15.0 or newer (required to build apps targeting the macOS 14 SDK).

## 🛠 Installation

Currently, VisorPro is available by building from the source:

1. Clone this repository:
   ```bash
   git clone https://github.com/sonor-studio/VisorPro.git
   ```
2. Open `VisorPro.xcodeproj` in Xcode.
3. Select your Mac as the build destination.
4. Build and Run the project (`Cmd + R`).

## 🔓 Gatekeeper Workaround (Unsigned App)

Because VisorPro is an independent, open-source project and is not signed with a paid Apple Developer account certificate, macOS Gatekeeper may block it upon the first launch. You might see a warning that the app is from an "unidentified developer" or is "damaged and can't be opened."

This is standard macOS behavior for unsigned apps. **To safely bypass this and open VisorPro:**

### Method 1: Right-Click (Easiest)
1. Open **Finder** and navigate to where the built VisorPro app is located.
2. **Right-click** (or hold `Control` and click) on the VisorPro app icon.
3. Select **Open** from the context menu.
4. A warning dialog will appear. Click **Open** again to launch the app.
*(You only need to do this the very first time. Afterward, it will open normally.)*

### Method 2: System Settings
1. Try to open the app normally. If a warning dialog appears, click **OK**.
2. Open **System Settings** > **Privacy & Security**.
3. Scroll down to the **Security** section.
4. You should see a message stating that VisorPro was blocked. Click the **Open Anyway** button.
5. Provide your Mac password if prompted, and click **Open** on the final warning dialog.

### Method 3: Terminal (For "Damaged" errors)
If macOS insists the app is "damaged and should be moved to the Trash," you can remove the quarantine attribute via Terminal:
```bash
xattr -cr /Applications/VisorPro.app
```
*(Make sure to adjust the path if your app is located elsewhere, such as in your Xcode build folder).*

## 🤝 Contributing

We welcome contributions! Please open an issue or submit a pull request if you have ideas, bug reports, or feature requests.

## 📄 License

This project is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License (CC BY-NC-SA 4.0) - see the [LICENSE.txt](LICENSE.txt) file for details. 
