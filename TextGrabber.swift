import AppKit
import Vision
import SwiftUI

// MARK: - Models
struct TokenObservation: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

// MARK: - Selection View
struct SelectionOverlayView: View {
    @State private var startPoint: CGPoint?
    @State private var currentPoint: CGPoint?
    var onSelectionComplete: (CGRect) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.3).edgesIgnoringSafeArea(.all)
            if let start = startPoint, let current = currentPoint {
                let rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
                Rectangle().fill(Color.white.opacity(0.001)).border(Color.white, width: 2).frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY).blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if startPoint == nil { startPoint = value.startLocation }
                    currentPoint = value.location
                }
                .onEnded { value in
                    guard let start = startPoint else { return }
                    let rect = CGRect(x: min(start.x, value.location.x), y: min(start.y, value.location.y), width: abs(start.x - value.location.x), height: abs(start.y - value.location.y))
                    onSelectionComplete(rect)
                }
        )
    }
}

// MARK: - Result View
struct OCRResultView: View {
    let image: NSImage
    @State var tokens: [TokenObservation]
    @State private var selectedIds = Set<UUID>()
    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var lastCopiedText = ""
    @State private var showFeedback = false
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fit)
                    .overlay(
                        GeometryReader { geo in
                            ZStack(alignment: .topLeading) {
                                ForEach(tokens) { token in
                                    let rect = calculateRect(for: token.boundingBox, in: geo.size)
                                    HighlightBox(rect: rect, isSelected: selectedIds.contains(token.id))
                                        .onTapGesture { handleTap(on: token); copySelectedText() }
                                }
                                if let start = dragStart, let current = dragCurrent { SelectionRectView(start: start, end: current) }
                            }
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                                if dragStart == nil { dragStart = value.startLocation; if !NSEvent.modifierFlags.contains(.shift) { selectedIds.removeAll() } }
                                dragCurrent = value.location
                                updateSelection(geo: geo)
                            }.onEnded { _ in dragStart = nil; dragCurrent = nil; copySelectedText() })
                        }
                    )
                    .background(Color.black.opacity(0.05)).cornerRadius(12).padding()
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if showFeedback { Label("Copied!", systemImage: "checkmark.circle.fill").foregroundColor(.green).bold() }
                    else { Text("Highlight text to copy").font(.subheadline).foregroundColor(.secondary) }
                    Spacer()
                    Button("Clear") { selectedIds.removeAll(); lastCopiedText = "" }.buttonStyle(.bordered)
                    Button("Done") { NSApp.keyWindow?.close() }.buttonStyle(.borderedProminent)
                }.padding(.bottom, 4)
                if !lastCopiedText.isEmpty {
                    Text(lastCopiedText).font(.system(.caption, design: .monospaced)).lineLimit(3).padding(8).frame(maxWidth: .infinity, alignment: .leading).background(Color.primary.opacity(0.05)).cornerRadius(6)
                }
            }.padding().background(.ultraThinMaterial)
        }.frame(minWidth: 800, minHeight: 600)
    }
    
    func calculateRect(for box: CGRect, in size: CGSize) -> CGRect {
        CGRect(x: box.origin.x * size.width, y: (1 - box.origin.y - box.size.height) * size.height, width: box.size.width * size.width, height: box.size.height * size.height)
    }
    func handleTap(on token: TokenObservation) {
        if NSEvent.modifierFlags.contains(.shift) { if selectedIds.contains(token.id) { selectedIds.remove(token.id) } else { selectedIds.insert(token.id) } }
        else { selectedIds = [token.id] }
    }
    func updateSelection(geo: GeometryProxy) {
        guard let start = dragStart, let current = dragCurrent else { return }
        let selectionRect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y), width: abs(start.x - current.x), height: abs(start.y - current.y))
        for token in tokens { if selectionRect.intersects(calculateRect(for: token.boundingBox, in: geo.size)) { selectedIds.insert(token.id) } }
    }
    func copySelectedText() {
        let text = tokens.filter { selectedIds.contains($0.id) }.sorted { (a, b) -> Bool in
            if abs(a.boundingBox.origin.y - b.boundingBox.origin.y) < 0.02 { return a.boundingBox.origin.x < b.boundingBox.origin.x }
            return a.boundingBox.origin.y > b.boundingBox.origin.y
        }.map { $0.text }.joined(separator: " ")
        if !text.isEmpty { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string); lastCopiedText = text; withAnimation { showFeedback = true }; DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showFeedback = false } }
    }
}

struct HighlightBox: View { let rect: CGRect; let isSelected: Bool; var body: some View { Rectangle().fill(isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.001)).frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY) } }
struct SelectionRectView: View { let start: CGPoint; let end: CGPoint; var body: some View { let rect = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(start.x - end.x), height: abs(start.y - end.y)); Rectangle().stroke(Color.accentColor, lineWidth: 1).background(Color.accentColor.opacity(0.1)).frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY) } }

// MARK: - Help View
struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Use").font(.headline)
                    Text("1. Click the TextGrabber icon in your menu bar.\n2. Select 'Capture Text' (or press Cmd+C).\n3. Drag to select any area of your screen.\n4. Highlight the recognized text in the result window to copy it.")
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("📸 Seeing only your wallpaper?").font(.headline).foregroundColor(.orange)
                    Text("This is a common macOS permission quirk. If your screenshots are missing windows and only show the desktop background:")
                    Text("1. Go to the menu icon and select 'Reset Permissions'.\n2. The app will quit. Launch it again from your Applications folder.\n3. Grant 'Screen Recording' permission when prompted.\n4. If it doesn't prompt, manually enable it in System Settings > Privacy & Security > Screen Recording.")
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("🔒 Gatekeeper Warning").font(.headline)
                    Text("Since this app is not signed with a paid Apple Developer certificate, you must Right-Click > Open it the very first time you launch it.")
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    Button("Got it") { NSApp.keyWindow?.close() }.buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
        }
        .frame(width: 450, height: 500)
    }
}

// Frees the result window from memory when the user closes it.
class ResultWindowDelegate: NSObject, NSWindowDelegate {
    var onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var selectionWindow: NSWindow?
    var resultWindow: NSWindow?
    var resultWindowDelegate: ResultWindowDelegate? // must be held strongly (NSWindow.delegate is weak)
    
    func applicationDidFinishLaunching(_ notification: Notification) { 
        print("[TextGrabber] App launched and status item initialized")
        setupStatusItem() 
    }
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Capture")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Text", action: #selector(startCapture), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Help & Troubleshooting", action: #selector(showHelp), keyEquivalent: "/"))
        menu.addItem(NSMenuItem(title: "Reset Permissions...", action: #selector(resetPermissions), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
        
        checkPermissions()
    }
    
    var helpWindow: NSWindow?
    @objc func showHelp() {
        if helpWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 450, height: 500), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.center()
            window.title = "TextGrabber Help"
            window.contentView = NSHostingView(rootView: HelpView())
            window.isReleasedWhenClosed = false
            helpWindow = window
        }
        helpWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func checkPermissions() {
        // We let the system trigger the prompt naturally when we first capture,
        // but we provide the Reset menu as a manual escape hatch.
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                print("[TextGrabber] WARNING: Screen Recording permission not granted.")
            }
        }
    }
    
    @objc func resetPermissions() {
        let alert = NSAlert()
        alert.messageText = "Reset Screen Recording Permissions?"
        alert.informativeText = "This will reset the permission for TextGrabber. The app will quit, and you will need to grant permission again on next launch."
        alert.addButton(withTitle: "Reset and Quit")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
            proc.arguments = ["reset", "ScreenCapture", "com.zexerif.TextGrabberPro"]
            try? proc.run()
            NSApp.terminate(nil)
        }
    }
    
    @objc func startCapture() {
        print("[TextGrabber] Starting capture...")
        DispatchQueue.main.async {
            // Clear any existing selection window before starting a new one.
            self.selectionWindow?.orderOut(nil)
            self.selectionWindow = nil
            
            guard let screen = NSScreen.main else {
                print("[TextGrabber] Error: No main screen found")
                return
            }
            
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.backgroundColor = .clear
            window.isOpaque = false
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // We use a local strong reference to ensure the window stays alive during setup.
            window.contentView = NSHostingView(rootView: SelectionOverlayView { [weak self, weak window] rect in
                guard let self = self, let window = window else { return }
                
                print("[TextGrabber] Selection completed (local): \(rect)")
                
                // Convert local window rect to global screen coordinates (top-left origin).
                // CGWindowListCreateImage and screencapture both expect global coordinates.
                guard let screen = window.screen else { return }
                let primaryScreen = NSScreen.screens[0]
                let primaryHeight = primaryScreen.frame.height
                
                // globalX = screen origin X + local X
                // globalY = (primary height - screen maxY) + local Y
                let globalRect = CGRect(
                    x: screen.frame.origin.x + rect.origin.x,
                    y: (primaryHeight - screen.frame.maxY) + rect.origin.y,
                    width: rect.width,
                    height: rect.height
                )
                
                let windowID = CGWindowID(window.windowNumber)
                
                // CRITICAL: Capture BEFORE hiding the window.
                self.captureArea(rect: globalRect, belowWindowID: windowID)
                
                // Now hide and cleanup.
                window.orderOut(nil)
                if self.selectionWindow === window {
                    self.selectionWindow = nil
                }
            })
            
            window.makeKeyAndOrderFront(nil)
            self.selectionWindow = window
            NSApp.activate(ignoringOtherApps: true)
            print("[TextGrabber] Overlay window displayed")
        }
    }
    
    func captureArea(rect: CGRect, belowWindowID: CGWindowID) {
        print("[TextGrabber] Capturing area \(rect) below window \(belowWindowID)...")
        if let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            belowWindowID,
            .bestResolution
        ) {
            if cgImage.width > 4 && cgImage.height > 4 {
                print("[TextGrabber] CGWindowList capture successful (\(cgImage.width)x\(cgImage.height))")
                let image = NSImage(cgImage: cgImage, size: rect.size)
                performOCR(on: cgImage, image: image)
                return
            } else {
                print("[TextGrabber] CGWindowList returned empty image, falling back...")
            }
        } else {
            print("[TextGrabber] CGWindowListCreateImage returned nil, falling back...")
        }
        
        // Fallback: screencapture CLI
        captureViaScreencapture(rect: rect)
    }

    func captureViaScreencapture(rect: CGRect) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("tg_\(Int(Date().timeIntervalSince1970)).png")
        let regionArg = "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        proc.arguments = ["-x", "-R", regionArg, tmp.path]
        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let img = NSImage(contentsOf: tmp),
                      let tiff = img.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiff),
                      let cgImage = bitmap.cgImage else {
                    print("[TextGrabber] screencapture fallback failed")
                    return
                }
                self?.performOCR(on: cgImage, image: img)
                try? FileManager.default.removeItem(at: tmp)
            }
        }
        try? proc.run()
    }
    
    func performOCR(on cgImage: CGImage, image: NSImage) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] (request, error) in
                guard let results = request.results as? [VNRecognizedTextObservation] else { return }
                var tokens: [TokenObservation] = []
                for obs in results {
                    guard let candidate = obs.topCandidates(1).first else { continue }
                    let str = candidate.string
                    
                    // Use a regex to split by whitespace instead of .byWords.
                    // This ensures punctuation (%, !, ?, etc.) is included in the tokens.
                    let range = NSRange(str.startIndex..., in: str)
                    if let regex = try? NSRegularExpression(pattern: "\\S+") {
                        regex.enumerateMatches(in: str, range: range) { match, _, _ in
                            guard let matchRange = match?.range,
                                  let swiftRange = Range(matchRange, in: str) else { return }
                            
                            let substring = String(str[swiftRange])
                            if let box = try? candidate.boundingBox(for: swiftRange) {
                                tokens.append(TokenObservation(text: substring, boundingBox: box.boundingBox))
                            }
                        }
                    }
                }
                DispatchQueue.main.async { self?.showResultWindow(image: image, tokens: tokens) }
            }
            request.recognitionLevel = .accurate; request.usesLanguageCorrection = false
            try? requestHandler.perform([request])
        }
    }
    
    func showResultWindow(image: NSImage, tokens: [TokenObservation]) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.center(); window.title = "TextGrabber"
        window.contentView = NSHostingView(rootView: OCRResultView(image: image, tokens: tokens))
        window.makeKeyAndOrderFront(nil); window.level = .floating
        // Use a delegate to nil our refs when the window closes, so memory is freed.
        // NSWindow.delegate is weak, so we must hold resultWindowDelegate strongly ourselves.
        resultWindowDelegate = ResultWindowDelegate { [weak self] in
            self?.resultWindow = nil
            self?.resultWindowDelegate = nil
        }
        window.delegate = resultWindowDelegate
        self.resultWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
// Ensure the delegate is held strongly in the global scope
var globalDelegate: AppDelegate? = delegate
app.delegate = globalDelegate
app.run()
