//
//  OverlayStateRelay.swift
//  VisorPro
//
//  Isolated ObservableObject for high-frequency overlay state (swipe, hover).
//  This object is ONLY subscribed by overlay views, NOT by the dashboard.
//  This prevents dashboard re-renders from affecting overlay performance and vice versa.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class OverlayStateRelay: ObservableObject {
    static let shared = OverlayStateRelay()
    
    // MARK: - Swipe state (moved from MediaKeyManager)
    
    /// Current swipe offset per overlay, used by VisorProWindowManager to position panels
    /// and by ScrollSwipeModifier to track gesture progress.
    @Published var swipeOffsets: [String: CGFloat] = [:]
    
    /// Set of overlay IDs currently being swiped, prevents timer-based dismissal during active gesture.
    @Published var activeSwipeIds: Set<String> = []
    
    /// Whether the user is hovering a scrollable sub-view (e.g. clipboard history list in CopyOverlayView),
    /// which should prevent swipe-to-dismiss from intercepting scroll events.
    @Published var isHoveringScrollView: Bool = false
}
