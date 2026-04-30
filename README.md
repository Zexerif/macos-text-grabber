# TextGrabber

A lightweight, native macOS utility for high-precision screen OCR.

## Features
- **Menu Bar Access**: Lightweight and tucked away.
- **Visual Selection**: Select any area of your screen and interact with the text.
- **Word-Level Precision**: Highlight specific words, phrases, or special characters.
- **"Live Text" Experience**: Real-time visual feedback and selection.
- **Privacy First**: All processing is done locally using Apple's Vision framework.

## 🔒 Privacy & Security

**Your data stays on your Mac.**
- **Zero Data Collection**: TextGrabber does not have any servers. It does not track you, and it doesn't even have the ability to connect to the internet.
- **Local Processing**: 100% of the text recognition is performed locally on your device using Apple's secure Vision framework.
- **Screen Recording Permission**: macOS requires this permission so the app can "see" the pixels in the specific area you select to find the text. TextGrabber **never** records your screen, saves videos, or monitors your activity in the background.

## 💻 System Compatibility

- **Intel Macs**: Supported natively.
- **Apple Silicon (M1-M5)**: Fully supported using Rosetta.
- **macOS Requirement**: Works on macOS 11.0 (Big Sur) and newer.

> [!NOTE]
> **What is Rosetta?**
> If you are on an M-series Mac, macOS may ask you to "Install Rosetta" the first time you open the app. Rosetta is a safe, official Apple tool that allows apps to run on any type of Mac chip. You only need to click "Install" once, and then the app will work perfectly every time.

## 🚀 Installation

The installation process is the same for **all** Mac users:

1.  **Download**: Get the latest `TextGrabber.zip`.
2.  **Unzip**: Double-click the file to reveal **TextGrabber.app**.
3.  **Install**: Drag **TextGrabber.app** into your **Applications** folder.
4.  **Open**: Double-click the app to launch it.
    - *Note: On the first launch, you may need to right-click and select "Open" to bypass macOS security.*
5.  **Permissions**: When prompted, grant **Screen Recording** permissions.

## 📖 Usage

1.  Click the **TextGrabber icon** in your menu bar (top right).
2.  Select **Capture Text**.
3.  Drag to select an area.
4.  In the window that appears, **drag your cursor** over the text to highlight and copy it.
5.  Check the bottom panel to see a preview of what you've copied!

## Developer Compilation

If you have Swift installed, you can build the app bundle yourself using:
```bash
./build_app.sh
```
This will generate a fresh `TextGrabber.app` and `TextGrabber.zip`.
