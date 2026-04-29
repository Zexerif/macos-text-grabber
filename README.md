# TextGrabber

A lightweight, native macOS utility for high-precision screen OCR.

## Features
- **Menu Bar Access**: Lightweight and tucked away.
- **Visual Selection**: Select any area of your screen and interact with the text.
- **Word-Level Precision**: Highlight specific words, phrases, or special characters.
- **"Live Text" Experience**: Real-time visual feedback and selection.
- **Privacy First**: All processing is done locally using Apple's Vision framework.

## Installation for Non-Technical Users

1.  **Download**: Get the latest `TextGrabber.zip`.
2.  **Unzip**: Double-click the file to reveal **TextGrabber.app**.
3.  **Install**: Drag **TextGrabber.app** into your **Applications** folder.
4.  **Open**: Double-click the app to launch it.
    - *Note: On the first launch, you may need to right-click and select "Open" to bypass macOS security checks for non-notarized apps.*
5.  **Permissions**: When prompted, grant **Screen Recording** permissions so the app can see the area you select.

## Usage

1.  Click the **TextGrabber icon** (a small square with text) in your menu bar (top right).
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
