import SwiftUI

// MARK: - Ternary Time Model

struct TernaryTime {
    /// 9 trits representing HHH:MMM:SSS, each -1, 0, or 1
    let trits: [Int]

    var hours: [Int] { Array(trits[0..<3]) }
    var minutes: [Int] { Array(trits[3..<6]) }
    var seconds: [Int] { Array(trits[6..<9]) }

    var hoursDecimal: Int { Self.tritsToDecimal(hours) }
    var minutesDecimal: Int { Self.tritsToDecimal(minutes) }
    var secondsDecimal: Int { Self.tritsToDecimal(seconds) }

    /// Duration of one ternary second in real seconds (~4.39s).
    static let ternarySecondDuration: TimeInterval = 86400.0 / 19683.0

    static func now() -> TernaryTime { from(date: Date()) }

    /// Computes ternary time from a Date, using full sub-second precision.
    /// Noon in the local timezone = 0:0:0.
    static func from(date: Date) -> TernaryTime {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let realSecs = date.timeIntervalSince(startOfDay)
        let sinceNoon = realSecs - 43200.0
        var total = Int(floor(sinceNoon / ternarySecondDuration))
        total = max(-9841, min(9841, total))
        return TernaryTime(trits: toBalancedTernary(total, digits: 9))
    }

    /// Noon today — always ternary second 0, used to anchor the periodic schedule.
    static func noonToday() -> Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(43200)
    }

    /// Converts an integer to balanced ternary with the given number of digits (most significant first).
    static func toBalancedTernary(_ n: Int, digits: Int) -> [Int] {
        var trits = [Int]()
        var v = n
        for _ in 0..<digits {
            var r = v % 3
            v /= 3
            if r > 1 { r -= 3; v += 1 }
            if r < -1 { r += 3; v -= 1 }
            trits.append(r)
        }
        return trits.reversed()
    }

    static func tritsToDecimal(_ trits: [Int]) -> Int {
        trits.reduce(0) { $0 * 3 + $1 }
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var showSettings = false
    @AppStorage("showLeadingZeros") private var showLeadingZeros = true
    @AppStorage("foregroundColorHex") private var foregroundColorHex = "D9CBAE"
    @AppStorage("backgroundColorHex") private var backgroundColorHex = "000000"

    private var foregroundColor: Binding<Color> {
        Binding(
            get: { Color(hex: foregroundColorHex) },
            set: { foregroundColorHex = $0.toHex() }
        )
    }

    private var backgroundColor: Binding<Color> {
        Binding(
            get: { Color(hex: backgroundColorHex) },
            set: { backgroundColorHex = $0.toHex() }
        )
    }

    var body: some View {
        TimelineView(.periodic(
            from: TernaryTime.noonToday(),
            by: TernaryTime.ternarySecondDuration
        )) { context in
            let time = TernaryTime.from(date: context.date)

            ZStack {
                backgroundColor.wrappedValue
                    .ignoresSafeArea()

                MainClockView(
                    time: time,
                    showLeadingZeros: showLeadingZeros,
                    foregroundColor: foregroundColor.wrappedValue
                )
                .onTapGesture {
                    withAnimation { showSettings = true }
                }

                if showSettings {
                    Color.clear
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation { showSettings = false }
                        }

                    SettingsCard(
                        showLeadingZeros: $showLeadingZeros,
                        foregroundColor: foregroundColor,
                        backgroundColor: backgroundColor
                    )
                    .transition(.opacity)
                }
            }
        }
        .statusBarHidden(true)
        .modifier(HideHomeIndicatorModifier())
    }
}

// MARK: - Main Clock View

/// Full-screen view showing only the ternary clock, perfectly centered within the safe area.
struct MainClockView: View {
    let time: TernaryTime
    let showLeadingZeros: Bool
    let foregroundColor: Color

    private let hPadding: CGFloat = 16

    var body: some View {
        ClockDisplayCanvas(
            hours: time.hours,
            minutes: time.minutes,
            seconds: time.seconds,
            showLeadingZeros: showLeadingZeros,
            foregroundColor: foregroundColor
        )
        .aspectRatio(11.0 / 3.0, contentMode: .fit)
        .padding(.horizontal, hPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Settings Card

struct SettingsCard: View {
    @Binding var showLeadingZeros: Bool
    @Binding var foregroundColor: Color
    @Binding var backgroundColor: Color
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 20) {
            Toggle("Leading zeros", isOn: $showLeadingZeros)
            ColorPicker("Foreground", selection: $foregroundColor, supportsOpacity: false)
            ColorPicker("Background", selection: $backgroundColor, supportsOpacity: false)

            Divider()

            Button {
                showInfo = true
            } label: {
                Label("About Ternary Clock", systemImage: "info.circle")
            }
        }
        .padding(24)
        .contentShape(Rectangle())
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 500)
        .padding(.horizontal, 32)
        .sheet(isPresented: $showInfo) {
            InfoView()
        }
    }
}

// MARK: - Info View

struct InfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("How to read it",
                        "The day is divided into 27 hours of 27 minutes of 27 seconds. " +
                        "One ternary second is roughly 4.4 standard seconds — close to what " +
                        "psychologists call the \"extended present,\" the duration of time " +
                        "we experience as now.",

                        "Noon is the center of the day: 0\u{2009}·\u{2009}0\u{2009}·\u{2009}0. " +
                        "Morning hours are negative, counting up toward zero. " +
                        "Afternoon hours are positive, counting away from it. " +
                        "Midnight is not a number — it falls between ticks, in the gap " +
                        "where +13 wraps to −13 and one day becomes the next.",

                        "Each digit is drawn as a line: / for +1, | for zero, \\ for −1. " +
                        "Any number and its negative are mirror images of each other."
                    )

                    section("Why balanced ternary?",
                        "Binary — the foundation of modern computing — has no center. " +
                        "Zero sits at the edge, and negative numbers need a special sign. " +
                        "Balanced ternary puts zero at the center, with positive and negative " +
                        "values extending symmetrically from it. Negative numbers aren't marked; " +
                        "they arise naturally from the digits.",

                        "This symmetry connects to open questions in physics about the nature " +
                        "of time and the relationship between the discrete and the continuous. " +
                        "Binary encodes a world of sharp boundaries. Balanced ternary encodes " +
                        "a world with a center. Experiencing time through this lens — where the " +
                        "day pivots around noon rather than resetting at midnight — offers a " +
                        "different, and perhaps more natural, sense of its passing."
                    )
                }
                .padding(24)
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, _ paragraphs: String...) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Clock Display Canvas

/// Draws the entire clock (all trit groups and dot separators) in a single Canvas.
/// Layout is always 9 trits + 2 separators; when showLeadingZeros is false,
/// leading zero trits are simply not drawn.
struct ClockDisplayCanvas: View {
    let hours: [Int]
    let minutes: [Int]
    let seconds: [Int]
    let showLeadingZeros: Bool
    var foregroundColor: Color = .primary

    private let totalUnits: CGFloat = 11

    var body: some View {
        Canvas { context, size in
            let roughCellWidth = size.width / totalUnits
            let lineWidth = roughCellWidth * 0.15
            let edgePad = lineWidth / 2 + 2
            let cellWidth = (size.width - 2 * edgePad) / totalUnits
            let actualLineWidth = cellWidth * 0.15
            let vPad = actualLineWidth * 0.6
            let top = vPad
            let bottom = size.height - vPad
            let dotSize = actualLineWidth * 1.2
            let style = StrokeStyle(lineWidth: actualLineWidth, lineCap: .round)
            let shading = GraphicsContext.Shading.color(foregroundColor)

            var x = edgePad

            x = drawTrits(hours, at: x, cellWidth: cellWidth,
                          top: top, bottom: bottom, style: style, shading: shading, in: context)
            x = drawDot(at: x, width: cellWidth, dotSize: dotSize,
                        midY: size.height / 2, shading: shading, in: context)
            x = drawTrits(minutes, at: x, cellWidth: cellWidth,
                          top: top, bottom: bottom, style: style, shading: shading, in: context)
            x = drawDot(at: x, width: cellWidth, dotSize: dotSize,
                        midY: size.height / 2, shading: shading, in: context)
            _ = drawTrits(seconds, at: x, cellWidth: cellWidth,
                          top: top, bottom: bottom, style: style, shading: shading, in: context)
        }
    }

    private func drawTrits(_ trits: [Int], at startX: CGFloat, cellWidth: CGFloat,
                           top: CGFloat, bottom: CGFloat, style: StrokeStyle,
                           shading: GraphicsContext.Shading,
                           in context: GraphicsContext) -> CGFloat {
        let firstSignificant = showLeadingZeros
            ? 0
            : (trits.firstIndex(where: { $0 != 0 }) ?? (trits.count - 1))

        var x = startX
        for (i, trit) in trits.enumerated() {
            if i >= firstSignificant {
                var path = Path()
                switch trit {
                case 1:
                    path.move(to: CGPoint(x: x + cellWidth, y: top))
                    path.addLine(to: CGPoint(x: x, y: bottom))
                case -1:
                    path.move(to: CGPoint(x: x, y: top))
                    path.addLine(to: CGPoint(x: x + cellWidth, y: bottom))
                default:
                    path.move(to: CGPoint(x: x + cellWidth / 2, y: top))
                    path.addLine(to: CGPoint(x: x + cellWidth / 2, y: bottom))
                }
                context.stroke(path, with: shading, style: style)
            }
            x += cellWidth
        }
        return x
    }

    private func drawDot(at startX: CGFloat, width: CGFloat, dotSize: CGFloat,
                         midY: CGFloat, shading: GraphicsContext.Shading,
                         in context: GraphicsContext) -> CGFloat {
        let cx = startX + width / 2
        let rect = CGRect(x: cx - dotSize / 2, y: midY - dotSize / 2,
                          width: dotSize, height: dotSize)
        context.fill(Circle().path(in: rect), with: shading)
        return startX + width
    }
}

// MARK: - Decimal Readout

struct DecimalReadoutView: View {
    let time: TernaryTime

    var body: some View {
        HStack(spacing: 4) {
            Text(format(time.hoursDecimal))
            Text(":")
            Text(format(time.minutesDecimal))
            Text(":")
            Text(format(time.secondsDecimal))
        }
        .font(.system(.title3, design: .monospaced))
        .foregroundStyle(.secondary)
    }

    private func format(_ value: Int) -> String {
        if value > 0 { return "+\(value)" }
        if value < 0 { return "\(value)" }
        return " 0"
    }
}

// MARK: - Color Hex Conversion

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    func toHex() -> String {
        let components = UIColor(self).cgColor.components ?? [0, 0, 0]
        let r = components.count > 0 ? components[0] : 0
        let g = components.count > 1 ? components[1] : 0
        let b = components.count > 2 ? components[2] : 0
        return String(format: "%02X%02X%02X",
                      Int(round(r * 255)),
                      Int(round(g * 255)),
                      Int(round(b * 255)))
    }
}

// MARK: - iOS Version Compatibility

struct HideHomeIndicatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.persistentSystemOverlays(.hidden)
        } else {
            content
        }
    }
}

#Preview {
    ContentView()
}
