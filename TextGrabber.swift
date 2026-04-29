import AppKit
import Vision
import SwiftUI

// MARK: - Models
struct TokenObservation: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
}

// MARK: - SwiftUI Views
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
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        GeometryReader { geo in
                            ZStack(alignment: .topLeading) {
                                ForEach(tokens) { token in
                                    let rect = calculateRect(for: token.boundingBox, in: geo.size)
                                    HighlightBox(rect: rect, isSelected: selectedIds.contains(token.id))
                                        .onTapGesture { handleTap(on: token); copySelectedText() }
                                }
                                if let start = dragStart, let current = dragCurrent {
                                    SelectionRectView(start: start, end: current)
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if dragStart == nil {
                                            dragStart = value.startLocation
                                            if !NSEvent.modifierFlags.contains(.shift) { selectedIds.removeAll() }
                                        }
                                        dragCurrent = value.location
                                        updateSelection(geo: geo)
                                    }
                                    .onEnded { _ in
                                        dragStart = nil
                                        dragCurrent = nil
                                        copySelectedText()
                                    }
                            )
                        }
                    )
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(12)
                    .padding()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if showFeedback {
                        Label("Copied!", systemImage: "checkmark.circle.fill").foregroundColor(.green).bold()
                    } else {
                        Text("Highlight text to copy").font(.subheadline).foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Clear") { selectedIds.removeAll(); lastCopiedText = "" }.buttonStyle(.bordered)
                    Button("Done") {
                        // Just close the window, not the app
                        NSApp.keyWindow?.close()
                    }.buttonStyle(.borderedProminent)
                }
                
                if !lastCopiedText.isEmpty {
                    Text(lastCopiedText)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(3)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(6)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    func calculateRect(for box: CGRect, in size: CGSize) -> CGRect {
        let x = box.origin.x * size.width
        let y = (1 - box.origin.y - box.size.height) * size.height
        let w = box.size.width * size.width
        let h = box.size.height * size.height
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    func handleTap(on token: TokenObservation) {
        if NSEvent.modifierFlags.contains(.shift) {
            if selectedIds.contains(token.id) { selectedIds.remove(token.id) }
            else { selectedIds.insert(token.id) }
        } else { selectedIds = [token.id] }
    }
    
    func updateSelection(geo: GeometryProxy) {
        guard let start = dragStart, let current = dragCurrent else { return }
        let selectionRect = CGRect(
            x: min(start.x, current.x), y: min(start.y, current.y),
            width: abs(start.x - current.x), height: abs(start.y - current.y)
        )
        for token in tokens {
            let tokenRect = calculateRect(for: token.boundingBox, in: geo.size)
            if selectionRect.intersects(tokenRect) { selectedIds.insert(token.id) }
        }
    }
    
    func copySelectedText() {
        let selected = tokens.filter { selectedIds.contains($0.id) }
        let text = observationsToText(selected)
        if !text.isEmpty {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            lastCopiedText = text
            withAnimation { showFeedback = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showFeedback = false }
        }
    }
    
    func observationsToText(_ observations: [TokenObservation]) -> String {
        return observations.sorted { (a, b) -> Bool in
            if abs(a.boundingBox.origin.y - b.boundingBox.origin.y) < 0.02 {
                return a.boundingBox.origin.x < b.boundingBox.origin.x
            }
            return a.boundingBox.origin.y > b.boundingBox.origin.y
        }.map { $0.text }.joined(separator: " ")
    }
}

struct HighlightBox: View {
    let rect: CGRect
    let isSelected: Bool
    var body: some View {
        Rectangle()
            .fill(isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.001))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

struct SelectionRectView: View {
    let start: CGPoint
    let end: CGPoint
    var body: some View {
        let rect = CGRect(
            x: min(start.x, end.x), y: min(start.y, end.y),
            width: abs(start.x - end.x), height: abs(start.y - end.y)
        )
        Rectangle()
            .stroke(Color.accentColor, lineWidth: 1)
            .background(Color.accentColor.opacity(0.1))
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App is already an accessory due to LSUIElement in Info.plist
        setupStatusItem()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Capture")
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Capture Text", action: #selector(startCapture), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }
    
    @objc func startCapture() {
        let tempPath = "/tmp/textgrabber_capture.png"
        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-i", "-x", tempPath]
        task.terminationHandler = { _ in
            DispatchQueue.main.async { self.processCapturedImage(at: tempPath) }
        }
        try? task.run()
    }
    
    func processCapturedImage(at path: String) {
        let url = URL(fileURLWithPath: path)
        guard let image = NSImage(contentsOf: url) else { return }
        let requestHandler = VNImageRequestHandler(url: url, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            guard let results = request.results as? [VNRecognizedTextObservation] else { return }
            var tokens: [TokenObservation] = []
            for obs in results {
                guard let candidate = obs.topCandidates(1).first else { continue }
                let str = candidate.string
                let comps = str.components(separatedBy: .whitespaces)
                var searchIdx = str.startIndex
                for comp in comps {
                    if let range = str.range(of: comp, range: searchIdx..<str.endIndex) {
                        if let box = try? candidate.boundingBox(for: range) {
                            tokens.append(TokenObservation(text: comp, boundingBox: box.boundingBox))
                        }
                        searchIdx = range.upperBound
                    }
                }
            }
            DispatchQueue.main.async { self.showResultWindow(image: image, tokens: tokens) }
            try? FileManager.default.removeItem(atPath: path)
        }
        request.recognitionLevel = .accurate
        try? requestHandler.perform([request])
    }
    
    func showResultWindow(image: NSImage, tokens: [TokenObservation]) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.title = "TextGrabber"
        window.contentView = NSHostingView(rootView: OCRResultView(image: image, tokens: tokens))
        window.makeKeyAndOrderFront(nil)
        window.level = .floating
        window.isReleasedWhenClosed = false
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Main
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
