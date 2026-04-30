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

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var selectionWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) { setupStatusItem() }
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Capture")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Text", action: #selector(startCapture), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func startCapture() {
        DispatchQueue.main.async {
            self.selectionWindow?.close()
            guard let screen = NSScreen.main else { return }
            let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.backgroundColor = .clear; window.isOpaque = false
            window.level = .screenSaver
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.contentView = NSHostingView(rootView: SelectionOverlayView { [weak self] rect in
                // Capture everything BELOW our overlay window by passing its ID.
                // This excludes the overlay from the screenshot without hiding it first,
                // so there's no race condition with the compositor.
                let windowID = CGWindowID(window.windowNumber)
                self?.selectionWindow?.orderOut(nil)
                self?.captureArea(rect: rect, belowWindowID: windowID)
            })
            window.makeKeyAndOrderFront(nil)
            self.selectionWindow = window
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func captureArea(rect: CGRect, belowWindowID: CGWindowID) {
        // Capture all windows BELOW our selection overlay (excluding it).
        // .optionOnScreenBelowWindow with our window ID means the overlay is
        // never in the image — no hiding, no delay, no race condition.
        //
        // SwiftUI drag coords use top-left origin. CGWindowListCreateImage also
        // uses top-left origin for the primary screen. No coordinate flip needed.
        if let cgImage = CGWindowListCreateImage(
            rect,
            .optionOnScreenBelowWindow,
            belowWindowID,
            .bestResolution
        ), cgImage.width > 4 {
            let image = NSImage(cgImage: cgImage, size: rect.size)
            performOCR(on: cgImage, image: image)
        } else {
            // Fallback: screencapture CLI (macOS 14+ where CGWindowListCreateImage may fail)
            captureViaScreencapture(rect: rect)
        }
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
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }
            var tokens: [TokenObservation] = []
            for obs in results {
                guard let candidate = obs.topCandidates(1).first else { continue }
                let str = candidate.string
                str.enumerateSubstrings(in: str.startIndex..., options: .byWords) { substring, range, _, _ in
                    if let substring = substring, let box = try? candidate.boundingBox(for: range) {
                        tokens.append(TokenObservation(text: substring, boundingBox: box.boundingBox))
                    }
                }
            }
            DispatchQueue.main.async { self.showResultWindow(image: image, tokens: tokens) }
        }
        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }
    
    func showResultWindow(image: NSImage, tokens: [TokenObservation]) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 700), styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.center(); window.title = "TextGrabber"; window.contentView = NSHostingView(rootView: OCRResultView(image: image, tokens: tokens)); window.makeKeyAndOrderFront(nil); window.level = .floating; window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
