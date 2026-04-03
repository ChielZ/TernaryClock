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

    /// Strips leading zero trits, keeping at least one trit.
    static func stripLeadingZeros(_ trits: [Int]) -> [Int] {
        let stripped = Array(trits.drop(while: { $0 == 0 }))
        return stripped.isEmpty ? [0] : stripped
    }
}

// MARK: - Main View

struct ContentView: View {
    @State private var showLeadingZeros = true

    var body: some View {
        TimelineView(.periodic(
            from: TernaryTime.noonToday(),
            by: TernaryTime.ternarySecondDuration
        )) { context in
            ClockFaceView(
                time: TernaryTime.from(date: context.date),
                showLeadingZeros: showLeadingZeros,
                onToggleZeros: { showLeadingZeros.toggle() }
            )
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Clock Face

struct ClockFaceView: View {
    let time: TernaryTime
    let showLeadingZeros: Bool
    let onToggleZeros: () -> Void

    private static let hPadding: CGFloat = 16
    private static let edgePad: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let layout = makeLayout(width: geo.size.width)

            VStack(spacing: 32) {
                Spacer()

                ClockDisplayCanvas(
                    hours: layout.hours,
                    minutes: layout.minutes,
                    seconds: layout.seconds
                )
                .frame(height: layout.displayHeight)
                .padding(.horizontal, Self.hPadding)

                DecimalReadoutView(time: time)

                Button(action: onToggleZeros) {
                    Text(showLeadingZeros ? "Hide leading zeros" : "Show leading zeros")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func displayTrits(_ trits: [Int]) -> [Int] {
        showLeadingZeros ? trits : TernaryTime.stripLeadingZeros(trits)
    }

    private func makeLayout(width: CGFloat) -> ClockLayout {
        let h = displayTrits(time.hours)
        let m = displayTrits(time.minutes)
        let s = displayTrits(time.seconds)
        return ClockLayout(
            hours: h, minutes: m, seconds: s,
            availableWidth: width,
            hPadding: Self.hPadding,
            edgePad: Self.edgePad
        )
    }
}

// MARK: - Layout

struct ClockLayout {
    let hours: [Int]
    let minutes: [Int]
    let seconds: [Int]
    let displayHeight: CGFloat

    init(hours: [Int], minutes: [Int], seconds: [Int],
         availableWidth: CGFloat, hPadding: CGFloat, edgePad: CGFloat) {
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds

        let canvasWidth = availableWidth - 2 * hPadding
        let tritCount = CGFloat(hours.count + minutes.count + seconds.count)
        let totalUnits = tritCount + 2 // 2 separator units
        let cellWidth = (canvasWidth - 2 * edgePad) / totalUnits
        displayHeight = cellWidth * 3 // 1:3 cell aspect ratio
    }
}

// MARK: - Clock Display Canvas

/// Draws the entire clock (all trit groups and dot separators) in a single Canvas,
/// eliminating clipping between groups.
struct ClockDisplayCanvas: View {
    let hours: [Int]
    let minutes: [Int]
    let seconds: [Int]

    private let edgePad: CGFloat = 6

    var body: some View {
        Canvas { context, size in
            let tritCount = CGFloat(hours.count + minutes.count + seconds.count)
            let totalUnits = tritCount + 2
            let cellWidth = (size.width - 2 * edgePad) / totalUnits
            let lineWidth = cellWidth * 0.15
            let vPad = lineWidth * 0.6
            let top = vPad
            let bottom = size.height - vPad
            let dotSize = lineWidth * 1.2
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round)

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
        var x = startX
        for trit in trits {
            var path = Path()
            switch trit {
            case 1: // /
                path.move(to: CGPoint(x: x + cellWidth, y: top))
                path.addLine(to: CGPoint(x: x, y: bottom))
            case -1: // \
                path.move(to: CGPoint(x: x, y: top))
                path.addLine(to: CGPoint(x: x + cellWidth, y: bottom))
            default: // |
                path.move(to: CGPoint(x: x + cellWidth / 2, y: top))
                path.addLine(to: CGPoint(x: x + cellWidth / 2, y: bottom))
            }
            context.stroke(path, with: .foreground, style: style)
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

#Preview {
    ContentView()
}
