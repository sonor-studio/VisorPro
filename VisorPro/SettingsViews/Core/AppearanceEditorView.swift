import SwiftUI
import Combine

struct CircleGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Appearance Editor View
/// A visual overlay customization page with full-bleed preview background
/// and floating popover controls arranged around a centered overlay preview.
struct AppearanceEditorView: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @Environment(\.colorScheme) var colorScheme
    
    // Popover state
    @State private var showGlowPopover = false
    @State private var showDismissPopover = false
    @State private var showBehaviorPopover = false
    
    // AppStorage bindings for appearance options
    @AppStorage("enableSwipeToDismiss") private var enableSwipeToDismiss = true
    @AppStorage("enableCloseButton") private var enableCloseButton = true
    @AppStorage("closeButtonOnRight") private var closeButtonOnRight = false
    @AppStorage("reverseSwipeDirection") private var reverseSwipeDirection = false
    @AppStorage("overlayAnimationType") private var overlayAnimationType: String = "default"
    @AppStorage("enableBouncyExpansion") private var enableBouncyExpansion = true
    @AppStorage("notificationDuration") private var notificationDuration = 3.0
    @AppStorage("PremiumLicenseKey") private var savedLicenseKey = ""
    
    @State private var animationTrigger = false
    @State private var dismissTrigger = false
    @State private var isPreviewPlaying = false
    @State private var skipExitAnimation = false
    @State private var previewDismissTrigger = false
    @State private var scrollMonitor: Any?
    @State private var previewSwipeOffset: CGFloat = 0
    @State private var isDismissingSwipe = false
    @State private var previewForceStopTrigger = false
    @State private var ignoreUntilNewGesture = false
    @State private var isHoveringPreview = false
    
    enum PreviewOverlayType: String, CaseIterable {
        case volume, brightness, media, keyboard
    }
    @State private var currentPreviewOverlay: PreviewOverlayType = .volume
    private var previewTypes = PreviewOverlayType.allCases
    private var currentPreviewIndex: Int {
        previewTypes.firstIndex(of: currentPreviewOverlay) ?? 0
    }
    
    @ViewBuilder
    private var currentOverlayView: some View {
        switch currentPreviewOverlay {
        case .volume:
            VolumeOverlayView(isPreview: true).id("volume")
        case .brightness:
            BrightnessOverlayView(isPreview: true).id("brightness")
        case .media:
            MediaOverlayView(isPreview: true).id("media")
        case .keyboard:
            KeyboardBrightnessOverlayView(isPreview: true).id("keyboard")
        }
    }

    
    private func triggerPreviewAnimation() {
        animationTrigger.toggle()
    }
    
    var body: some View {
        ZStack {
            // MARK: Full-bleed preview background
            PreviewBackgroundView(minHeight: 500, fullBleed: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            // Dim scrim for readability
            Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05)
            
            // Tap-catcher behind all content to dismiss popovers
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissPopovers()
                }
            
            // MARK: Content layout
            VStack(spacing: 0) {
                // Top: Theme buttons
                themeButtons
                    .padding(.top, 20)
                
                Spacer()
                
                // Above overlay: Corner radius
                cornerRadiusControl
                    .padding(.bottom, 16)
                
                // Center: Overlay preview with arrows
                ZStack {
                    HStack {
                        Button {
                            let idx = currentPreviewIndex - 1
                            if idx >= 0 {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPreviewOverlay = previewTypes[idx]
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.primary.opacity(0.05))
                                .nativeGlassBackground()
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                        }
                        .buttonStyle(CircleGlassButtonStyle())
                        .opacity(currentPreviewIndex > 0 ? 1.0 : 0.3)
                        .disabled(currentPreviewIndex == 0)
                        
                        Spacer()
                        
                        Button {
                            let idx = currentPreviewIndex + 1
                            if idx < previewTypes.count {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    currentPreviewOverlay = previewTypes[idx]
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 36, height: 36)
                                .background(Color.primary.opacity(0.05))
                                .nativeGlassBackground()
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.15), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.2), radius: 5, y: 2)
                        }
                        .buttonStyle(CircleGlassButtonStyle())
                        .opacity(currentPreviewIndex < previewTypes.count - 1 ? 1.0 : 0.3)
                        .disabled(currentPreviewIndex == previewTypes.count - 1)
                    }
                    .padding(.horizontal, 40)
                    
                    PreviewAnimationWrapper(
                        animType: overlayAnimationType, 
                        playTrigger: animationTrigger,
                        dismissTrigger: dismissTrigger,
                        isPlaying: $isPreviewPlaying,
                        skipExitAnimation: $skipExitAnimation,
                        forceStopTrigger: $previewForceStopTrigger
                    ) {
                        currentOverlayView
                            .applyTheme(mediaKeyManager.overlayTheme)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    .offset(y: previewSwipeOffset)
                    .opacity(max(0.0, 1.0 - (abs(previewSwipeOffset) / 60.0)))
                    .frame(height: 140)
                    .onHover { isHoveringPreview = $0 } // Keep space reserved
                }

                
                Spacer()
                
                // Bottom: Action buttons
                bottomControls
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
        }
        .navigationTitle("Appearance")
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PreviewDismissTriggered"))) { _ in
            if !isPreviewPlaying {
                isPreviewPlaying = true
            }
            dismissTrigger.toggle()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                if self.previewSwipeOffset != 0 { self.previewSwipeOffset = 0 }
                if self.skipExitAnimation { self.skipExitAnimation = false }
            }
            // Blokujemy możliwość kolejnego swipe'a (isDismissingSwipe) aż do pełnego zakończenia wjazdu!
            // Eliminuje to dublowanie animacji i glitche wywołane poruszeniem gładzika podczas wjazdu.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.isDismissingSwipe { self.isDismissingSwipe = false }
            }
        }
        .onAppear {
            setupPreviewScrollMonitor()
        }
        .onDisappear {
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    private func dismissPopovers() {
        showGlowPopover = false
        showDismissPopover = false
        showBehaviorPopover = false
    }
    
    // MARK: - Theme Buttons (simple pills, no preview cards)
    private var themeButtons: some View {
        HStack(spacing: 10) {
            themeButton(title: "System", icon: "circle.lefthalf.filled", value: "system")
            themeButton(title: "Dark", icon: "moon.fill", value: "dark")
            themeButton(title: "Light", icon: "sun.max.fill", value: "light")
        }
    }
    
    private func themeButton(title: String, icon: String, value: String) -> some View {
        let isSelected = mediaKeyManager.overlayTheme == value
        return Button {
            mediaKeyManager.overlayTheme = value
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .buttonStyle(InteractiveGlassButtonStyle(isActive: isSelected))
    }
    
    // MARK: - Bottom Controls (action buttons only)
    private var bottomControls: some View {
        HStack {
            // Left: Inner Glow + Animation
            VStack(alignment: .leading, spacing: 12) {
                FloatingActionButton(
                    icon: "sparkles",
                    label: "Inner Glow",
                    isActive: showGlowPopover
                ) {
                    showGlowPopover.toggle()
                }
                .popover(isPresented: $showGlowPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    glowPopoverContent
                        .padding(14)
                }
                
                animationControl
            }
            
            Spacer()
            
            // Right: Behavior & Close
            VStack(alignment: .trailing, spacing: 12) {
                FloatingActionButton(
                    icon: "slider.horizontal.3",
                    label: "Behavior",
                    isActive: showBehaviorPopover
                ) {
                    showBehaviorPopover.toggle()
                }
                .popover(isPresented: $showBehaviorPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    behaviorPopoverContent
                        .padding(14)
                }
                
                FloatingActionButton(
                    icon: "xmark.circle",
                    label: "Close & Dismiss",
                    isActive: showDismissPopover
                ) {
                    showDismissPopover.toggle()
                }
                .popover(isPresented: $showDismissPopover, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    dismissPopoverContent
                        .padding(14)
                }
            }
        }
    }
    
    // MARK: - Corner Radius inline control (above overlay)
    private var cornerRadiusControl: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.roundedtop")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Corners")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
            
            Slider(
                value: $mediaKeyManager.cornerRoundingMultiplier,
                in: 0.6...1.0,
                step: 0.05
            )
            .frame(width: 100)
            
            Text("\(Int(mediaKeyManager.cornerRoundingMultiplier * 100))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .nativeGlassBackground()
        
    }
    
    // MARK: - Animation inline control
    private var animationControl: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Animation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Picker("", selection: $overlayAnimationType) {
                    Text("Slide").tag("default")
                    Text("Scale").tag("scale")
                    Text("Fluid").tag("fluid_bounce")
                    Text("Droplet").tag("fluid_drop")
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .frame(width: 90)
                .onChange(of: overlayAnimationType) { _, _ in
                    triggerPreviewAnimation()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .nativeGlassBackground()
            
            
            Button {
                if isPreviewPlaying {
                    // Natychmiastowe zatrzymanie bez animacji
                    isPreviewPlaying = false
                    previewForceStopTrigger.toggle()
                    withAnimation(nil) {
                        previewSwipeOffset = 0
                    }
                    skipExitAnimation = false
                    isDismissingSwipe = false
                } else {
                    triggerPreviewAnimation()
                }
            } label: {
                Image(systemName: isPreviewPlaying ? "square.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(InteractiveCircleGlassButtonStyle())
        }
    }

    
    
    @State private var previewDebounceTimer: Timer?
    
    private func setupPreviewScrollMonitor() {
        var localScrollDelta: CGFloat = 0
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            guard UserDefaults.standard.bool(forKey: "enableSwipeToDismiss") else { return event }
            guard self.isHoveringPreview else { return event }
            
            let phase = event.phase
            let momentum = event.momentumPhase
            let isTrackpad = event.hasPreciseScrollingDeltas
            let rawDelta = event.scrollingDeltaY
            let reverseSwipe = UserDefaults.standard.bool(forKey: "reverseSwipeDirection")
            let delta = reverseSwipe ? rawDelta : -rawDelta
            
            // Tylko gładziki wysyłają .began. Używamy tego do pewnego odblokowania gestu.
            if phase == .began {
                if self.ignoreUntilNewGesture { self.ignoreUntilNewGesture = false }
                localScrollDelta = 0
                if self.previewSwipeOffset != 0 { self.previewSwipeOffset = 0 }
            }
            
            if !self.ignoreUntilNewGesture && !self.isDismissingSwipe {
                if abs(delta) > 0.5 {
                    localScrollDelta += delta
                }
                
                var calculatedOffset = localScrollDelta
                if calculatedOffset > 0 {
                    if localScrollDelta > 0 { localScrollDelta = 0 }
                    calculatedOffset = 0
                } else if calculatedOffset < -12 {
                    calculatedOffset += 12
                } else {
                    calculatedOffset = 0
                }
                
                if self.previewSwipeOffset != calculatedOffset {
                    self.previewSwipeOffset = calculatedOffset
                }
                
                if calculatedOffset < -60 {
                    self.isDismissingSwipe = true
                    self.skipExitAnimation = true
                    self.ignoreUntilNewGesture = true
                    localScrollDelta = 0
                    
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.previewSwipeOffset = -300
                    }
                    
                    NotificationCenter.default.post(name: NSNotification.Name("PreviewDismissTriggered"), object: nil)
                }
            }
            
            let isEnding = (phase == .ended || phase == .cancelled || momentum == .ended || momentum == .cancelled)
            let isEmptyPhase = (phase.rawValue == 0 && momentum.rawValue == 0)
            
            if isEnding || isEmptyPhase {
                previewDebounceTimer?.invalidate()
                previewDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
                    DispatchQueue.main.async {
                        // Dla zwykłych myszek (które nie wysyłają .began) odblokowujemy timerem.
                        // Gładziki trzymają blokadę inercji aż do momentu ponownego dotknięcia (.began).
                        if !isTrackpad {
                            if self.ignoreUntilNewGesture { self.ignoreUntilNewGesture = false }
                        }
                        
                        guard !self.isDismissingSwipe else { return }
                        guard !self.ignoreUntilNewGesture else { return } // Nie resetuj, jeśli czekamy na .began
                        
                        localScrollDelta = 0
                        if self.previewSwipeOffset != 0 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                self.previewSwipeOffset = 0
                            }
                        }
                    }
                }
            }
            
            return event
        }
    }

    // MARK: - Glow Popover Content
    private var glowPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Enable Inner Glow")
                            .font(.system(size: 13, weight: .medium))
                        if savedLicenseKey.isEmpty {
                            premiumBadge
                        }
                    }
                    Text("Colorful background glow behind the glass.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 20)
                Toggle("", isOn: Binding(
                    get: { mediaKeyManager.enableGlowEffect },
                    set: { if !savedLicenseKey.isEmpty { mediaKeyManager.enableGlowEffect = $0 } }
                ))
                .disabled(savedLicenseKey.isEmpty)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            
            if mediaKeyManager.enableGlowEffect {
                Divider()
                
                HStack {
                    Text("Show Glow In")
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 20)
                    Picker("", selection: $mediaKeyManager.glowEffectTheme) {
                        Text("Both").tag("both")
                        Text("Dark").tag("dark")
                        Text("Light").tag("light")
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                
                HStack {
                    Text("Glow on Expanded")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $mediaKeyManager.glowOnExpanded)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                
                HStack {
                    Text("Intensity")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Slider(value: $mediaKeyManager.glowIntensity, in: 0.1...2.0, step: 0.1)
                        .frame(width: 120)
                }
            }
        }
        .frame(width: 280)
    }
    
    // MARK: - Dismiss Popover Content
    @AppStorage("keepCloseButtonWhenExpanded") private var keepCloseButtonWhenExpanded = true
    
    // MARK: - Behavior Popover Content
    private var behaviorPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Display duration
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Display duration")
                        .font(.system(size: 13, weight: .medium))
                    Text("How long the overlay stays visible.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 20)
                HStack(spacing: 8) {
                    Slider(value: $notificationDuration, in: 1...10, step: 1)
                        .frame(width: 80)
                    Text("\(Int(notificationDuration))s")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
            
            Divider()
            
            // Maximum tiles
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Maximum overlays")
                            .font(.system(size: 13, weight: .medium))
                        if savedLicenseKey.isEmpty {
                            premiumBadge
                        }
                    }
                    Text("Maximum number of tiles shown at once.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 20)
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(mediaKeyManager.maxSimultaneousNotifications) },
                        set: { if !savedLicenseKey.isEmpty { mediaKeyManager.maxSimultaneousNotifications = Int($0) } }
                    ), in: 1...5, step: 1)
                    .disabled(savedLicenseKey.isEmpty)
                    .frame(width: 80)
                    
                    Text("\(mediaKeyManager.maxSimultaneousNotifications)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
            
            Divider()
            
            // Bouncy expansion
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bouncy expansion")
                        .font(.system(size: 13, weight: .medium))
                    Text("Spring effect when overlay expands.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 20)
                Toggle("", isOn: $enableBouncyExpansion)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
        .frame(width: 320)
    }

    private var dismissPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show close button")
                        .font(.system(size: 13, weight: .medium))
                    Text("'X' button to quickly dismiss the overlay.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 20)
                Toggle("", isOn: $enableCloseButton)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            if enableCloseButton {
                Divider()
                
                HStack {
                    Text("Button position")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Picker("", selection: $closeButtonOnRight) {
                        Text("Left").tag(false)
                        Text("Right").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }
                
                HStack {
                    Text("Keep visible when expanded")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $keepCloseButtonWhenExpanded)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swipe to dismiss")
                        .font(.system(size: 13, weight: .medium))
                    Text("Swipe overlay towards screen edge.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer(minLength: 20)
                Toggle("", isOn: $enableSwipeToDismiss)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
            
            if enableSwipeToDismiss {
                HStack {
                    Text("Invert swipe direction")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: $reverseSwipeDirection)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .padding(.leading, 12)
            }
        }
        .frame(width: 280)
    }
    
    // MARK: - Premium Badge
    private var premiumBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
            Text("Premium")
                .fontWeight(.bold)
        }
        .font(.system(size: 9))
        .foregroundColor(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Color.green)
        .cornerRadius(3)
    }
}

// MARK: - Preview Animation Wrapper

struct InteractiveCircleGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(macOS 26.0, *) {
            configuration.label
                .background(Color.accentColor.opacity(0.8), in: .circle)
                .glassEffect(.regular, in: .circle)
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        } else {
            configuration.label
                .background(Color.accentColor, in: Circle())
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
        }
    }
}

/// A wrapper that perfectly mimics `PanelContentView` and `VisorProWindowManager` animations
/// for the preview mode, ensuring 1:1 parity with real window transitions.
struct DropletClipModifier: ViewModifier {
    let animType: String
    let cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        if animType == "fluid_drop" {
            content.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content
        }
    }
}

class PreviewAnimationState: ObservableObject {
    @Published var tokenId = UUID()
}

struct PreviewAnimationWrapper<Content: View>: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    var animType: String
    var playTrigger: Bool
    var dismissTrigger: Bool
    @Binding var isPlaying: Bool
    @Binding var skipExitAnimation: Bool
    @Binding var forceStopTrigger: Bool
    @ViewBuilder var content: Content
    
    private var targetCornerRadius: CGFloat {
        (52.0 / 2.0) * CGFloat(mediaKeyManager.cornerRoundingMultiplier)
    }
    
    @State private var appearScaleX: CGFloat = 1.0
    @State private var appearScaleY: CGFloat = 1.0
    @State private var appearBlur: CGFloat = 0.0
    @State private var appearOffset: CGFloat = 0.0
    @State private var appearOpacity: Double = 1.0
    @State private var appearCornerRadius: CGFloat = 26.0
    @StateObject private var animState = PreviewAnimationState()
    
    var body: some View {
        content
            .modifier(DropletClipModifier(animType: animType, cornerRadius: appearCornerRadius))
            .scaleEffect(x: appearScaleX, y: appearScaleY)
            .blur(radius: appearBlur)
            .offset(y: appearOffset)
            .opacity(appearOpacity)
            .onChange(of: playTrigger) { _, _ in
                playCycle()
            }
            .onChange(of: dismissTrigger) { _, _ in
                runExitAnimation(thenEnter: true)
            }
            .onChange(of: mediaKeyManager.cornerRoundingMultiplier) { _, _ in
                if !isPlaying {
                    appearCornerRadius = targetCornerRadius
                }
            }
            .onChange(of: forceStopTrigger) { _, _ in
                animState.tokenId = UUID()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    appearScaleX = 1.0
                    appearScaleY = 1.0
                    appearBlur = 0.0
                    appearOffset = 0.0
                    appearOpacity = 1.0
                    appearCornerRadius = targetCornerRadius
                    isPlaying = false
                }
            }
            .onAppear {
                appearScaleX = 1.0
                appearScaleY = 1.0
                appearBlur = 0.0
                appearOffset = 0.0
                appearOpacity = 1.0
                appearCornerRadius = targetCornerRadius
            }
    }
    
    private func playCycle() {
        isPlaying = true
        runExitAnimation(thenEnter: true)
    }
    
    private func runExitAnimation(thenEnter: Bool = false) {
        let stateRef = self.animState
        let currentToken = UUID()
        stateRef.tokenId = currentToken
        
        NotificationCenter.default.post(name: NSNotification.Name("PreviewWillExit"), object: nil)
        if !thenEnter {
            isPlaying = false
        }
        
        if skipExitAnimation {
            appearOpacity = 0.0
            if thenEnter {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    guard stateRef.tokenId == currentToken else { return }
                    self.runEntryAnimation()
                }
            }
            return
        }
        
        if animType == "scale" {
            withAnimation(.easeIn(duration: 0.2)) {
                appearScaleX = 0.6
                appearScaleY = 0.6
                appearBlur = 15.0
                appearOpacity = 0.0
            }
        } else if animType == "fluid_bounce" {
            withAnimation(.easeIn(duration: 0.2)) {
                appearScaleX = 0.3
                appearScaleY = 0.3
                appearBlur = 0.0
                appearOffset = -50
                appearOpacity = 0.0
            }
        } else if animType == "fluid_drop" {
            // First: fluidly retracts from full overlay into the small circular droplet (22x22 circle)
            withAnimation(.spring(response: 0.26, dampingFraction: 0.75)) {
                appearScaleX = 0.0846
                appearScaleY = 0.4231
                appearBlur = 5.0
                appearCornerRadius = 26.0
            }
            // Seamlessly starts shooting up while still condensing into the droplet (at 0.10s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                guard stateRef.tokenId == currentToken else { return }
                withAnimation(.easeIn(duration: 0.20)) {
                    appearOffset = -50
                    appearOpacity = 0.0
                }
            }
        } else {
            withAnimation(.easeIn(duration: 0.2)) {
                appearOffset = -50
                appearOpacity = 0.0
            }
        }
        
        let exitDelay = (animType == "fluid_drop") ? 0.38 : 0.45
        if thenEnter {
            DispatchQueue.main.asyncAfter(deadline: .now() + exitDelay) {
                guard stateRef.tokenId == currentToken else { return }
                self.runEntryAnimation()
            }
        }
    }
    
    private func runEntryAnimation() {
        let stateRef = self.animState
        let currentToken = stateRef.tokenId
        
        if animType == "scale" {
            appearScaleX = 0.6
            appearScaleY = 0.6
            appearBlur = 15.0
            appearOffset = 0.0
            appearOpacity = 0.0
        } else if animType == "fluid_bounce" {
            appearScaleX = 0.3
            appearScaleY = 0.3
            appearBlur = 0.0
            appearOffset = -40
            appearOpacity = 0.0
        } else if animType == "fluid_drop" {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                // Exact small 22x22 circular dot (260 * 0.0846 = 22, 52 * 0.4231 = 22)
                appearScaleX = 0.0846
                appearScaleY = 0.4231
                appearBlur = 5.0
                appearCornerRadius = 26.0
                appearOffset = -50
                appearOpacity = 0.0
            }
        } else {
            appearScaleX = 1.0
            appearScaleY = 1.0
            appearBlur = 0.0
            appearOffset = -40
            appearOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard stateRef.tokenId == currentToken else { return }
            
            if animType == "fluid_drop" {
                // Drop slides down from top edge over 0.28s
                withAnimation(.easeOut(duration: 0.28)) {
                    appearOffset = 0.0
                    appearOpacity = 1.0
                }
                // Seamlessly starts expanding near the end of sliding out (at 0.12s) while still in downward motion!
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    guard stateRef.tokenId == currentToken else { return }
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.68)) {
                        appearScaleX = 1.0
                        appearScaleY = 1.0
                        appearBlur = 0.0
                        appearCornerRadius = targetCornerRadius
                    }
                }
            } else if animType != "scale" {
                withAnimation(.easeOut(duration: 0.15)) {
                    appearOffset = 0.0
                    appearOpacity = 1.0
                }
            }
            
            if animType == "scale" {
                withAnimation(.easeOut(duration: 0.15)) {
                    appearOpacity = 1.0
                }
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                    appearScaleX = 1.0
                    appearScaleY = 1.0
                    appearBlur = 0.0
                }
            } else if animType == "fluid_bounce" {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) {
                    appearScaleX = 1.0
                    appearScaleY = 1.0
                }
            } else if animType != "fluid_drop" {
                withAnimation(.easeOut(duration: 0.15)) {
                    appearOffset = 0.0
                    appearOpacity = 1.0
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                guard stateRef.tokenId == currentToken else { return }
                isPlaying = false
            }
        }
    }
}
