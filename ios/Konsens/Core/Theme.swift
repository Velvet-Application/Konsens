import SwiftUI

extension Color {
    static let konsensBackground = Color(red: 5/255, green: 13/255, blue: 19/255)
    static let konsensPanel = Color(red: 11/255, green: 23/255, blue: 32/255)
    static let konsensPanelRaised = Color(red: 14/255, green: 30/255, blue: 41/255)
    static let konsensGreen = Color(red: 60/255, green: 231/255, blue: 209/255)
    static let konsensBlue = Color(red: 90/255, green: 167/255, blue: 255/255)
    static let konsensViolet = Color(red: 143/255, green: 92/255, blue: 255/255)
    static let konsensMuted = Color(red: 132/255, green: 147/255, blue: 163/255)
    static let konsensPositive = Color(red: 53/255, green: 220/255, blue: 139/255)
    static let konsensNegative = Color(red: 255/255, green: 97/255, blue: 115/255)
    static let konsensGold = Color(red: 255/255, green: 200/255, blue: 87/255)

    init(hex: UInt) {
        self.init(red: Double((hex >> 16) & 0xff) / 255, green: Double((hex >> 8) & 0xff) / 255, blue: Double(hex & 0xff) / 255)
    }
}

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.konsensPanel.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.07)))
    }
}

extension View {
    func panel() -> some View { modifier(PanelModifier()) }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.35)
            .foregroundStyle(Color.konsensGreen)
    }
}

struct KonsensMark: View {
    var compact = false
    var body: some View {
        HStack(spacing: 9) {
            Image("KonsensLogo")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 36 : 46, height: compact ? 36 : 46)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(Color.white.opacity(0.08)))
            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Konsens").font(.headline.bold())
                    Text("PRÉDIRE · APPRENDRE · INVESTIR")
                        .font(.system(size: 6.5, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(Color.konsensMuted)
                }
            }
        }
    }
}
