import SwiftUI
import ApplicationServices
import Combine

struct WelcomeScreen: View {
    @EnvironmentObject var mediaKeyManager: MediaKeyManager
    @AppStorage("hasCompletedWelcome") private var hasCompletedWelcome = false
    @State private var currentTab = UserDefaults.standard.bool(forKey: "hasCompletedWelcome") ? 6 : 0
    @State private var isTrusted = checkAXIsProcessTrustedReliably()
    @State private var goForward: Bool = true
    @State private var window: NSWindow?
    
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        let activeTransition = AnyTransition.asymmetric(
            insertion: .move(edge: goForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: goForward ? .leading : .trailing).combined(with: .opacity)
        )
        
        ZStack {
            VisualEffectView(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            if currentTab == 0 {
                firstScreen
                    .transition(activeTransition)
            } else if currentTab == 1 {
                themeScreen
                    .transition(activeTransition)
            } else if currentTab == 2 {
                tutorialScreenOne
                    .transition(activeTransition)
            } else if currentTab == 3 {
                tutorialScreenTwo
                    .transition(activeTransition)
            } else if currentTab == 4 {
                tutorialScreenClickActions
                    .transition(activeTransition)
            } else if currentTab == 5 {
                tutorialScreenThree
                    .transition(activeTransition)
            } else {
                permissionsScreen
                    .transition(activeTransition)
            }

        }
        .frame(width: 600, height: 500)
        .overlay(
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    HStack {
                        Spacer()
                        if currentTab < 6 {
                            Button("Skip") {
                                if isTrusted {
                                    hasCompletedWelcome = true
                                } else {
                                    goForward = true
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        currentTab = 6
                                    }
                                }
                            }
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .padding(.trailing, 30)
                            .padding(.bottom, 56)
                        }
                    }
                    
                    if currentTab < 7 {
                        HStack(spacing: 8) {
                            ForEach(0..<7) { index in
                                Circle()
                                    .fill(currentTab == index ? Color.primary : Color.secondary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
        )
        .background(WindowAccessor(window: $window))

        .onChange(of: window) { _, newWindow in
            if let w = newWindow {
                w.isOpaque = false
                w.backgroundColor = .clear
                w.styleMask.remove(.resizable)
                w.styleMask.remove(.miniaturizable)
                w.minSize = NSSize(width: 600, height: 500)
                w.setContentSize(NSSize(width: 600, height: 500))
                w.center()
            }
        }
        .onReceive(timer) { _ in
            let trusted = checkAXIsProcessTrustedReliably()
            if isTrusted != trusted {
                withAnimation(.spring()) {
                    isTrusted = trusted
                }
                if !trusted && hasCompletedWelcome {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 6
                    }
                }
            }
            mediaKeyManager.syncPermissions()
        }
    }
    
    var firstScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 4) {
                Text("Welcome to VisorPro")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                
                Text("A new dimension of OSD notifications for macOS.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "bell.badge.fill", color: .blue, title: "Modern OSD", description: "Elegant notifications for volume, brightness, or battery status changes.")
                FeatureRow(icon: "slider.horizontal.3", color: .purple, title: "Full Customization", description: "Enable and disable features in Settings according to your needs.")
                FeatureRow(icon: "sparkles", color: .orange, title: "Native Experience", description: "Seamlessly integrates with macOS for a frictionless experience.")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.1))
            )
            .padding(.horizontal, 10)
            
            Spacer(minLength: 16)
            }
            .frame(maxHeight: .infinity)
            
            Button(action: {
                goForward = true
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    currentTab = 1
                }
            }) {
                Text("Continue")
                    .font(.headline)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    var themeScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.indigo)
                    .frame(width: 56, height: 56)
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                Text("Choose a Theme")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Select the appearance of the overlays. You can change this later in Settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 16)
            
            HStack(spacing: 20) {
                ThemeSelectionCard(title: "System", themeValue: "system", isSelected: mediaKeyManager.overlayTheme == "system") {
                    mediaKeyManager.overlayTheme = "system"
                }
                ThemeSelectionCard(title: "Dark", themeValue: "dark", isSelected: mediaKeyManager.overlayTheme == "dark") {
                    mediaKeyManager.overlayTheme = "dark"
                }
                ThemeSelectionCard(title: "Light", themeValue: "light", isSelected: mediaKeyManager.overlayTheme == "light") {
                    mediaKeyManager.overlayTheme = "light"
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer(minLength: 16)
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                Button(action: {
                    goForward = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 0
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    goForward = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 2
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var tutorialScreenOne: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
            Spacer(minLength: 0)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
                    .frame(width: 56, height: 56)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                Text("Expandable Overlays")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Click on the overlay to expand it or perform an action. For example, clicking the speaker icon mutes the sound, while clicking the rest of the overlay expands it to show more options.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)
            
            AnimatedTutorialOne()
                .applyTheme(mediaKeyManager.overlayTheme)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.1))
                )
            
            Spacer(minLength: 8)
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                Button(action: {
                    goForward = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 1
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    goForward = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 3
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var tutorialScreenTwo: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple)
                    .frame(width: 56, height: 56)
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                Text("Smooth Control")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Hold and drag anywhere on the overlay to smoothly adjust values, such as volume or brightness. It's an intuitive way to control your Mac directly from the notification.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)
            
            AnimatedTutorialTwo()
                .applyTheme(mediaKeyManager.overlayTheme)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.1))
                )
            
            Spacer(minLength: 16)
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                Button(action: {
                    goForward = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 2
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    goForward = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 4
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    
    var tutorialScreenClickActions: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange)
                    .frame(width: 56, height: 56)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                Text("Click Actions")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Not all overlays expand. Some simply perform an action when clicked, like toggling a feature on or off.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)
            
            AnimatedTutorialClickActions()
                .applyTheme(mediaKeyManager.overlayTheme)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.1))
                )
            
            Spacer(minLength: 16)
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                Button(action: {
                    goForward = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 3
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    goForward = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 5
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var tutorialScreenThree: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pink)
                    .frame(width: 56, height: 56)
                Image(systemName: "timer")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                Text("Timeout Indicators")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("Some overlays use their border as a timer to show when they will disappear. You can still interact with them before they vanish! Hovering over the overlay or expanding it will pause the timer.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 8)
            
            AnimatedTutorialThree()
                .applyTheme(mediaKeyManager.overlayTheme)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.1))
                )
            
            Spacer(minLength: 16)
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                Button(action: {
                    goForward = false
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 4
                    }
                }) {
                    Text("Back")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button(action: {
                    goForward = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        currentTab = 6
                    }
                }) {
                    Text("Continue")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var permissionsScreen: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
            Spacer(minLength: 0)
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange)
                    .frame(width: 56, height: 56)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                Text("Permissions Required")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                Text("For VisorPro to work correctly in the background and respond to system media keys, Accessibility permissions must be granted.")
                    .multilineTextAlignment(.center)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
                
                Text("macOS requires these permissions to monitor function keys. Your data is completely secure.")
                    .multilineTextAlignment(.center)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 40)
            }
            .padding(.bottom, 8)
            
            VStack(spacing: 10) {
                if isTrusted {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 36))
                        Text("Permissions granted!")
                            .font(.headline)
                        
                        if !trustedAtLaunchGlobal {
                            Text("A restart is required for all features to work correctly.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    VStack(spacing: 8) {
                        Button(action: {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                            
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                Text("Open System Settings")
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Text("Find VisorPro in System Settings and enable the toggle next to the app icon.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity)
                }
            }
            .frame(minHeight: 90)
            
            Spacer(minLength: 10)
            }
            .frame(maxHeight: .infinity)
            
            HStack(spacing: 16) {
                if !hasCompletedWelcome {
                    Button(action: {
                        goForward = false
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            currentTab = 4
                        }
                    }) {
                        Text("Back")
                            .font(.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                
                Button(action: {
                    hasCompletedWelcome = true
                    UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
                    
                    if isTrusted && !trustedAtLaunchGlobal {
                        let process = Process()
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                        process.arguments = ["-n", Bundle.main.bundlePath]
                        try? process.run()
                        NSApplication.shared.terminate(nil)
                    }
                }) {
                    Text((isTrusted && !trustedAtLaunchGlobal) ? "Relaunch" : "Finish")
                        .font(.headline)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isTrusted)
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 30)
        .padding(.bottom, 50)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MockDeviceRowView: View {
    let name: String
    let isCurrent: Bool
    
    var body: some View {
        HStack {
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
            if isCurrent {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct AnimatedTutorialOne: View {
    @State private var isExpanded = false
    @State private var cursorOffset = CGSize(width: 50, height: 100)
    @State private var cursorScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: $isExpanded,
                showProgressBar: true,
                progress: 0.65,
                barColor: .blue,
                fillCenter: false,
                isMuted: false,
                supportDragGesture: false,
                isExpandable: true,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 26, height: 24)
                        MarqueeText(text: "MacBook Pro Speakers", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        Spacer(minLength: 8)
                        AnimatablePercentageText(progress: 0.65, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: {
                    VStack(alignment: .leading, spacing: 4) {
                        MockDeviceRowView(name: "MacBook Pro Speakers", isCurrent: true)
                        MockDeviceRowView(name: "AirPods Pro", isCurrent: false)
                    }
                    .padding(.top, 2)
                    .padding(.horizontal, 11)
                }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 260)
            .allowsHitTesting(false)

            Image(nsImage: NSCursor.arrow.image)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                .scaleEffect(cursorScale, anchor: .topLeading)
                .offset(cursorOffset)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        isExpanded = false
        cursorOffset = CGSize(width: 0, height: 80)
        
        // Move to overlay
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            cursorOffset = CGSize(width: 40, height: 10)
        }
        
        // First click (expand)
        withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
            cursorScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring()) {
                isExpanded = true
            }
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 1.0
            }
        }
        
        // Second click (collapse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 0.8
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.1) {
            withAnimation(.spring()) {
                isExpanded = false
            }
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 1.0
            }
        }
        
        // Move away
        withAnimation(.easeInOut(duration: 1.0).delay(4.0)) {
            cursorOffset = CGSize(width: 120, height: 100)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            runAnimation()
        }
    }
}

struct AnimatedTutorialTwo: View {
    @State private var progress: CGFloat = 0.65
    @State private var cursorOffset = CGSize(width: 0, height: 80)
    @State private var cursorScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: .constant(false),
                showProgressBar: true,
                progress: progress,
                barColor: .blue,
                fillCenter: false,
                isMuted: false,
                supportDragGesture: false,
                isExpandable: false,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: progress > 0.33 ? "speaker.wave.2.fill" : "speaker.wave.1.fill")
                            .font(.system(size: 18, weight: .medium))
                            .frame(width: 26, height: 24)
                            .animation(nil, value: progress > 0.33)
                        MarqueeText(text: "MacBook Pro Speakers", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        Spacer(minLength: 8)
                        AnimatablePercentageText(progress: progress, isTopTitle: true, color: .primary, isPluggedIn: false, customText: "%d%")
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: { EmptyView() }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 260)
            .allowsHitTesting(false)

            Image(nsImage: NSCursor.arrow.image)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                .scaleEffect(cursorScale, anchor: .topLeading)
                .offset(cursorOffset)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        withAnimation(nil) {
            progress = 0.65
        }
        cursorOffset = CGSize(width: 40, height: 80)
        
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            cursorOffset = CGSize(width: 40, height: 10)
        }
        
        withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
            cursorScale = 0.8
        }
        
        withAnimation(.easeInOut(duration: 1.0).delay(1.6)) {
            cursorOffset = CGSize(width: -60, height: 10)
            progress = 0.25
        }
        
        withAnimation(.easeOut(duration: 0.1).delay(2.6)) {
            cursorScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 1.0).delay(3.0)) {
            cursorOffset = CGSize(width: 60, height: 80)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            runAnimation()
        }
    }
}

struct AnimatedTutorialThree: View {
    @State private var progress: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.9

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: .constant(false),
                showProgressBar: true,
                progress: progress,
                barColor: .indigo,
                fillCenter: false,
                isMuted: false,
                customWidth: 230,
                supportDragGesture: false,
                isExpandable: false,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bluetooth Connected")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                
                            MarqueeText(text: "AirPods Pro", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: { EmptyView() }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 230)
            .allowsHitTesting(false)
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        withAnimation(nil) {
            progress = 1.0
            opacity = 0.0
            scale = 0.9
        }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5)) {
            opacity = 1.0
            scale = 1.0
        }
        
        withAnimation(.linear(duration: 2.0).delay(0.9)) {
            progress = 0.0
        }
        
        withAnimation(.easeIn(duration: 0.2).delay(3.0)) {
            opacity = 0.0
            scale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            runAnimation()
        }
    }
}


struct AnimatedTutorialClickActions: View {
    @State private var isOn = true
    @State private var cursorOffset = CGSize(width: 50, height: 100)
    @State private var cursorScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            UniversalOverlayView(
                isPreview: true,
                isExpanded: .constant(false),
                showProgressBar: true,
                progress: 1.0,
                barColor: isOn ? .mint : .secondary,
                fillCenter: false,
                isMuted: false,
                customWidth: 230,
                supportDragGesture: false,
                isExpandable: false,
                expandUpwards: false,
                disableTimeoutMode: true,
                baseContent: {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: isOn ? "capslock.fill" : "capslock")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.primary)
                            .frame(width: 26, height: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keyboard")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                                
                            MarqueeText(text: isOn ? "Caps Lock ON" : "Caps Lock OFF", font: .system(size: 14, weight: .semibold, design: .rounded), foregroundColor: .primary)
                        }
                        Spacer(minLength: 8)
                    }
                    .padding(.horizontal, 23)
                },
                expandedContent: { EmptyView() }
            )
            .environmentObject(MediaKeyManager.shared)
            .frame(width: 230)
            .allowsHitTesting(false)

            Image(nsImage: NSCursor.arrow.image)
                .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                .scaleEffect(cursorScale, anchor: .topLeading)
                .offset(cursorOffset)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .onAppear {
            runAnimation()
        }
    }
    
    func runAnimation() {
        isOn = true
        cursorOffset = CGSize(width: 0, height: 80)
        
        // Move to overlay
        withAnimation(.easeInOut(duration: 1.0).delay(0.5)) {
            cursorOffset = CGSize(width: 20, height: 10)
        }
        
        // First click (turn off)
        withAnimation(.easeOut(duration: 0.1).delay(1.5)) {
            cursorScale = 0.8
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring()) {
                isOn = false
            }
            withAnimation(.easeOut(duration: 0.1)) {
                cursorScale = 1.0
            }
        }
        
        // Move away
        withAnimation(.easeInOut(duration: 1.0).delay(2.5)) {
            cursorOffset = CGSize(width: 80, height: 100)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            runAnimation()
        }
    }
}
