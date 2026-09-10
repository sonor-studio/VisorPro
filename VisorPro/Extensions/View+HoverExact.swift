import SwiftUI

struct HoverExactModifier: ViewModifier {
    let action: (Bool) -> Void
    var cursor: NSCursor? = nil
    
    func body(content: Content) -> some View {
        content.background(
            HoverTrackingView(onHoverChange: action, cursor: cursor)
        )
    }
}

extension View {
    func onHoverExact(cursor: NSCursor? = nil, perform action: @escaping (Bool) -> Void = { _ in }) -> some View {
        self.modifier(HoverExactModifier(action: action, cursor: cursor))
    }
}

struct HoverTrackingView: NSViewRepresentable {
    var onHoverChange: (Bool) -> Void
    var cursor: NSCursor?

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onHoverChange = onHoverChange
        view.cursor = cursor
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onHoverChange = onHoverChange
        nsView.cursor = cursor
    }
}

class TrackingNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?
    var cursor: NSCursor?
    private var trackingArea: NSTrackingArea?
    private var lastHoverState: Bool?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if self.window == nil {
            if lastHoverState == true {
                lastHoverState = false
                DispatchQueue.main.async {
                    self.onHoverChange?(false)
                }
            }
        } else {
            checkHoverState()
        }
    }
    
    private var lastBounds: NSRect = .zero
    
    override func layout() {
        super.layout()
        if bounds != lastBounds {
            lastBounds = bounds
            updateTrackingAreas()
        }
        checkHoverState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways
        ]
        
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        self.trackingArea = area
        
        checkHoverState()
    }
    
    private func checkHoverState() {
        guard let window = self.window else { return }
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        let localPoint = self.convert(mouseLocation, from: nil)
        let isInside = self.bounds.contains(localPoint)
        
        if lastHoverState != isInside {
            lastHoverState = isInside
            DispatchQueue.main.async {
                self.onHoverChange?(isInside)
            }
        }
    }

    override func mouseMoved(with event: NSEvent) {
        if lastHoverState == true, let cursor = cursor {
            cursor.set()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if lastHoverState != true {
            lastHoverState = true
            DispatchQueue.main.async {
                self.onHoverChange?(true)
            }
        }
    }

    override func mouseExited(with event: NSEvent) {
        if lastHoverState != false {
            lastHoverState = false
            DispatchQueue.main.async {
                self.onHoverChange?(false)
            }
        }
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil // Let clicks pass through to views underneath
    }
}

class ClickMonitor {
    static let shared = ClickMonitor()
    var isHoveringPointer = false
    
    init() {
        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .leftMouseDown, .rightMouseDown]) { event in
            if ClickMonitor.shared.isHoveringPointer {
                DispatchQueue.main.async {
                    NSCursor.pointingHand.set()
                }
            }
            return event
        }
        
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
            if ClickMonitor.shared.isHoveringPointer {
                DispatchQueue.main.async {
                    NSCursor.pointingHand.set()
                }
            }
        }
    }
}

extension View {
    func pointingHandCursor() -> some View {
        self.onHoverExact(cursor: .pointingHand) { hovering in
            let _ = ClickMonitor.shared // Ensure ClickMonitor is active
            ClickMonitor.shared.isHoveringPointer = hovering
            
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
