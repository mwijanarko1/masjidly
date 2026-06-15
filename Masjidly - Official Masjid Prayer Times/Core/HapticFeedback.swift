import SwiftUI
import UIKit

enum HapticFeedback {
    static func buttonTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

struct HapticPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                HapticFeedback.buttonTap()
            }
    }
}

extension ButtonStyle where Self == HapticPlainButtonStyle {
    static var hapticPlain: HapticPlainButtonStyle { HapticPlainButtonStyle() }
}
