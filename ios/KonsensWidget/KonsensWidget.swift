import WidgetKit
import SwiftUI

struct KonsensWealthEntry: TimelineEntry {
    let date: Date
    let wealth: Int
    let performance: Double
}

struct KonsensWealthProvider: TimelineProvider {
    func placeholder(in context: Context) -> KonsensWealthEntry { .init(date: .now, wealth: 1000, performance: 0) }
    func getSnapshot(in context: Context, completion: @escaping (KonsensWealthEntry) -> Void) { completion(.init(date: .now, wealth: 1000, performance: 0)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<KonsensWealthEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: "group.com.konsens.beta")
        let wealth = defaults?.integer(forKey: "konsens_widget_wealth") ?? 1000
        let performance = defaults?.double(forKey: "konsens_widget_performance") ?? 0
        let entry = KonsensWealthEntry(date: .now, wealth: wealth == 0 ? 1000 : wealth, performance: performance)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct KonsensWealthWidgetView: View {
    let entry: KonsensWealthEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color(red: 0.05, green: 0.12, blue: 0.16))
                    Text("K")
                        .font(.system(size: 17, weight: .black, design: .rounded).italic())
                        .foregroundStyle(LinearGradient(colors: [.mint, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                }.frame(width: 31, height: 31)
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis").font(.caption).foregroundStyle(.mint)
            }
            Text("Patrimoine").font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(entry.wealth.formatted()).font(.title2.monospacedDigit().bold())
                Text("Koins").font(.caption2).foregroundStyle(.secondary)
            }
            Text(String(format: "%+.1f%%", entry.performance))
                .font(.caption.bold()).foregroundStyle(entry.performance >= 0 ? Color.green : Color.red)
            Spacer(minLength: 0)
            Text("Konsens · simulation").font(.system(size: 8)).foregroundStyle(.secondary)
        }
        .containerBackground(for: .widget) { Color(red: 0.03, green: 0.07, blue: 0.10) }
        .widgetURL(URL(string: "konsens://wealth"))
    }
}

@main
struct KonsensWealthWidget: Widget {
    let kind = "KonsensWealthWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KonsensWealthProvider()) { entry in
            KonsensWealthWidgetView(entry: entry)
        }
        .configurationDisplayName("Patrimoine Konsens")
        .description("Suis ton patrimoine virtuel et ta performance en Koins.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
