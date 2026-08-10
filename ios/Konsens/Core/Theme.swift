import SwiftUI

extension Color {
    static let konsensBackground = Color(red: 7/255, green: 17/255, blue: 15/255)
    static let konsensPanel = Color(red: 14/255, green: 29/255, blue: 25/255)
    static let konsensGreen = Color(red: 66/255, green: 232/255, blue: 157/255)
    static let konsensMuted = Color(red: 126/255, green: 151/255, blue: 144/255)

    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(20).background(Color.konsensPanel.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08)))
    }
}

extension View { func panel() -> some View { modifier(PanelModifier()) } }

struct Eyebrow: View {
    let text: String
    var body: some View { Text(text).font(.system(size: 10, weight: .bold)).tracking(1.4).foregroundStyle(Color.konsensGreen) }
}
