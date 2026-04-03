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
    @State private var showLeadingZeros = true

    var body: some View {
        TimelineView(.periodic(
            from: TernaryTime.noonToday(),
            by: TernaryTime.ternarySecondDuration
        )) { context in
            let time = TernaryTime.from(date: context.date)

            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                MainClockView(time: time, showLeadingZeros: showLeadingZeros)
                    .onTapGesture(count: 2) {
                        withAnimation { showSettings = true }
                    }

                if showSettings {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            withAnimation { showSettings = false }
                        }

                    SettingsCard(
                        time: time,
                        showLeadingZeros: $showLeadingZeros
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

/// Full-screen view showing only the ternary clock, perfectly centered.
struct MainClockView: View {
    let time: TernaryTime
    let showLeadingZeros: Bool

    private let hPadding: CGFloat = 16

    var body: some View {
        GeometryReader { geo in
            let layout = ClockLayout(availableWidth: geo.size.width, hPadding: hPadding)

            ClockDisplayCanvas(
                hours: time.hours,
                minutes: time.minutes,
                seconds: time.seconds,
                showLeadingZeros: showLeadingZeros
            )
            .frame(width: geo.size.width - 2 * hPadding, height: layout.displayHeight)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Settings Card

struct SettingsCard: View {
    let time: TernaryTime
    @Binding var showLeadingZeros: Bool

    var body: some View {
        VStack(spacing: 20) {
            ClockDisplayCanvas(
                hours: time.hours,
                minutes: time.minutes,
                seconds: time.seconds,
                showLeadingZeros: showLeadingZeros
            )
            .aspectRatio(11.0 / 3.0, contentMode: .fit)

            DecimalReadoutView(time: time)

            Divider()

            Toggle("Leading zeros", isOn: $showLeadingZeros)
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 500)
        .padding(.horizontal, 32)
    }
}

// MARK: - Layout

struct ClockLayout {
    let displayHeight: CGFloat

    /// Always 9 trits + 2 separators = 11 units.
    private static let totalUnits: CGFloat = 11

    init(availableWidth: CGFloat, hPadding: CGFloat) {
        let canvasWidth = availableWidth - 2 * hPadding
        let roughCellWidth = canvasWidth / Self.totalUnits
        let lineWidth = roughCellWidth * 0.15
        let edgePad = lineWidth / 2 + 2
        let cellWidth = (canvasWidth - 2 * edgePad) / Self.totalUnits
        displayHeight = cellWidth * 3
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

            var x = edgePad

            x = drawTrits(hours, at: x, cellWidth: cellWidth,
                          top: top, bottom: bottom, style: style, in: context)
            x = drawDot(at: x, width: cellWidth, dotSize: dotSize,
                        midY: size.height / 2, in: context)
            x = drawTrits(minutes, at: x, cellWidth: cellWidth,
                          top: top, bottom: bottom, style: style, in: context)
            x = drawDot(at: x, width: cellWidth, dotSize: dotSize,
                        midY: size.height / 2, in: context)
            _ = drawTrits(seconds, at: x, cellWidth: cellWidth,
                          top: top, bottom: bottom, style: style, in: context)
        }
    }

    private func drawTrits(_ trits: [Int], at startX: CGFloat, cellWidth: CGFloat,
                           top: CGFloat, bottom: CGFloat, style: StrokeStyle,
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
                context.stroke(path, with: .foreground, style: style)
            }
            x += cellWidth
        }
        return x
    }

    private func drawDot(at startX: CGFloat, width: CGFloat, dotSize: CGFloat,
                         midY: CGFloat, in context: GraphicsContext) -> CGFloat {
        let cx = startX + width / 2
        let rect = CGRect(x: cx - dotSize / 2, y: midY - dotSize / 2,
                          width: dotSize, height: dotSize)
        context.fill(Circle().path(in: rect), with: .foreground)
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
