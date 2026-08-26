import SwiftUI

extension Color {
    static let konsensBackground = Color(red: 6/255, green: 8/255, blue: 22/255)
    static let konsensPanel = Color(red: 16/255, green: 18/255, blue: 38/255)
    static let konsensPanelRaised = Color(red: 23/255, green: 25/255, blue: 52/255)
    static let konsensGreen = Color(red: 71/255, green: 238/255, blue: 178/255)
    static let konsensBlue = Color(red: 76/255, green: 154/255, blue: 255/255)
    static let konsensViolet = Color(red: 151/255, green: 82/255, blue: 255/255)
    static let konsensPink = Color(red: 255/255, green: 78/255, blue: 167/255)
    static let konsensOrange = Color(red: 255/255, green: 126/255, blue: 54/255)
    static let konsensMuted = Color(red: 143/255, green: 150/255, blue: 177/255)
    static let konsensPositive = Color(red: 55/255, green: 220/255, blue: 139/255)
    static let konsensNegative = Color(red: 255/255, green: 83/255, blue: 111/255)
    static let konsensGold = Color(red: 255/255, green: 207/255, blue: 74/255)

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
            .font(.system(size: 9, weight: .black, design: .rounded))
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
                .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).stroke(Color.white.opacity(0.10)))
            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text("KONSENS").font(.headline.black()).tracking(0.4)
                    Text("JOUE · MISE · INVESTIS · DOMINE")
                        .font(.system(size: 6.5, weight: .black, design: .rounded))
                        .tracking(0.75)
                        .foregroundStyle(Color.konsensGold)
                }
            }
        }
    }
}
