import SwiftUI

struct HoverExactModifier: ViewModifier {
    let action: (Bool) -> Void
    
    func body(content: Content) -> some View {
        content.background(
            HoverTrackingView(onHoverChange: action)
        )
    }
}

extension View {
    func onHoverExact(perform action: @escaping (Bool) -> Void) -> some View {
        self.modifier(HoverExactModifier(action: action))
    }
}

struct HoverTrackingView: NSViewRepresentable {
    var onHoverChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onHoverChange = onHoverChange
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onHoverChange = onHoverChange
    }
}

class TrackingNSView: NSView {
    var onHoverChange: ((Bool) -> Void)?
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
    
    override func layout() {
        super.layout()
        checkHoverState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways
            // removed .inVisibleRect to avoid SwiftUI layer-backed bugs
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
