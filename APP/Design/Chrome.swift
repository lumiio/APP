import Foundation
import SwiftUI

/// iOS 26 gives every app the real Liquid Glass chrome: a glass navigation bar
/// with an automatic back control, and a glass tab bar. On those systems we
/// hand the chrome back to UIKit/SwiftUI instead of drawing our own.
enum AppChrome {
    static var usesSystemBars: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }
}

struct AdaptiveNavChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content.toolbar(.hidden, for: .navigationBar)
        }
    }
}

extension View {
    func adaptiveNavChrome() -> some View { modifier(AdaptiveNavChrome()) }
}
