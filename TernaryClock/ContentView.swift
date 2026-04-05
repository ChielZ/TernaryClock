import SwiftUI

// MARK: - Ternary Time Model

struct TernaryTime {
    /// 9 trits representing HHH:MMM:SSS, each -1, 0, or 1
    let trits: [Int]
    /// Continuous ternary seconds since noon (for smooth analog hand movement)
    let continuousTotal: Double

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
        let continuous = sinceNoon / ternarySecondDuration
        var total = Int(floor(continuous))
        total = max(-9841, min(9841, total))
        return TernaryTime(trits: toBalancedTernary(total, digits: 9), continuousTotal: continuous)
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

// MARK: - Color Palette

struct ColorPalette {
    static let entries: [(name: String, hex: String)] = [
        ("Nordic Blue", "0F6385"),
        ("Summer Cyan", "358292"),
        ("Washed Teal", "88ACA2"),
        ("White Sand", "ECD9AF"),
        ("Light Bronze", "E5A065"),
        ("Burnt Peach", "E4723E"),
        ("Sunset Red", "DC4029"),
        ("Tangerine", "F08537"),
        ("Amber Glow", "F8A036"),
    ]

    static let defaultIndex = 3 // White Sand

    static func color(at index: Int) -> Color {
        Color(hex: entries[index].hex)
    }

    static func name(at index: Int) -> String {
        entries[index].name
    }
}

/// Fixed colors for the settings UI — always White Sand on black.
enum SettingsColors {
    static let foreground = Color(hex: "ECD9AF")
    static let background = Color.black
}

// MARK: - Main View

struct ContentView: View {
    @State private var showSettings = false
    @AppStorage("showLeadingZeros") private var showLeadingZeros = true
    @AppStorage("showDecimalValues") private var showDecimalValues = false
    @AppStorage("useBalancedDecimal") private var useBalancedDecimal = false
    @AppStorage("selectedColorIndex") private var selectedColorIndex = ColorPalette.defaultIndex
    @AppStorage("invertColors") private var invertColors = false
    @AppStorage("useAnalogDisplay") private var useAnalogDisplay = false

    private var clockForeground: Color {
        invertColors ? .black : ColorPalette.color(at: selectedColorIndex)
    }

    private var clockBackground: Color {
        invertColors ? ColorPalette.color(at: selectedColorIndex) : .black
    }

    var body: some View {
        timelineContent
            .statusBarHidden(true)
            .modifier(HideHomeIndicatorModifier())
    }

    @ViewBuilder
    private var timelineContent: some View {
        if useAnalogDisplay {
            TimelineView(.periodic(
                from: TernaryTime.noonToday(),
                by: TernaryTime.ternarySecondDuration / 27.0 // divide by 27 for sub-second ticks (~0.163s)
            )) { context in
                clockBody(time: TernaryTime.from(date: context.date))
            }
        } else {
            TimelineView(.periodic(
                from: TernaryTime.noonToday(),
                by: TernaryTime.ternarySecondDuration
            )) { context in
                clockBody(time: TernaryTime.from(date: context.date))
            }
        }
    }

    @ViewBuilder
    private func clockBody(time: TernaryTime) -> some View {
        ZStack {
            (showSettings ? SettingsColors.background : clockBackground)
                .ignoresSafeArea()

            if showSettings {
                SettingsView(
                    time: time,
                    showLeadingZeros: $showLeadingZeros,
                    showDecimalValues: $showDecimalValues,
                    useBalancedDecimal: $useBalancedDecimal,
                    selectedColorIndex: $selectedColorIndex,
                    invertColors: $invertColors,
                    useAnalogDisplay: $useAnalogDisplay,
                    clockForeground: clockForeground,
                    clockBackground: clockBackground,
                    onClose: { withAnimation { showSettings = false } }
                )
            } else {
                Color.clear
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation { showSettings = true }
                    }

                MainClockView(
                    time: time,
                    showLeadingZeros: showLeadingZeros,
                    showDecimalValues: showDecimalValues,
                    useBalancedDecimal: useBalancedDecimal,
                    useAnalogDisplay: useAnalogDisplay,
                    foregroundColor: clockForeground,
                    backgroundColor: clockBackground
                )
                .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Main Clock View

struct MainClockView: View {
    let time: TernaryTime
    let showLeadingZeros: Bool
    let showDecimalValues: Bool
    let useBalancedDecimal: Bool
    let useAnalogDisplay: Bool
    let foregroundColor: Color
    let backgroundColor: Color

    private let hPadding: CGFloat = 16

    var body: some View {
        if useAnalogDisplay {
            GeometryReader { geo in
                let safeW = geo.size.width - geo.safeAreaInsets.leading - geo.safeAreaInsets.trailing
                let safeH = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
                let side = (min(safeW, safeH) - 2 * hPadding) * 0.95
                AnalogClockView(
                    time: time,
                    faceColor: foregroundColor,
                    detailColor: backgroundColor
                )
                .frame(width: side, height: side)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
            .ignoresSafeArea()
        } else {
            GeometryReader { geo in
                let clockWidth = geo.size.width - 2 * hPadding
                let cellWidth = clockWidth / 11
                let decimalFontSize = max(16, cellWidth * 0.7)

                VStack(spacing: cellWidth * 0.6) {
                    ClockDisplayCanvas(
                        hours: time.hours,
                        minutes: time.minutes,
                        seconds: time.seconds,
                        showLeadingZeros: showLeadingZeros,
                        foregroundColor: foregroundColor
                    )
                    .aspectRatio(11.0 / 3.0, contentMode: .fit)
                    .padding(.horizontal, hPadding)

                    if showDecimalValues {
                        DecimalReadoutView(time: time, useBalancedDecimal: useBalancedDecimal, fontSize: decimalFontSize)
                            .foregroundStyle(foregroundColor)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    let time: TernaryTime
    @Binding var showLeadingZeros: Bool
    @Binding var showDecimalValues: Bool
    @Binding var useBalancedDecimal: Bool
    @Binding var selectedColorIndex: Int
    @Binding var invertColors: Bool
    @Binding var useAnalogDisplay: Bool
    let clockForeground: Color
    let clockBackground: Color
    let onClose: () -> Void

    private let uiFg = SettingsColors.foreground

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular {
                // iPad: side-by-side
                HStack(spacing: 0) {
                    leftPanel
                        .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(uiFg.opacity(0.15))
                        .frame(width: 1)

                    rightPanel
                        .frame(maxWidth: .infinity)
                }
            } else {
                // iPhone: stacked, scrollable
                ScrollView {
                    VStack(spacing: 0) {
                        clockPreview
                        controls
                        rightPanel
                    }
                }
            }
        }
        .font(.custom("Comfortaa", size: 16))
        .foregroundStyle(uiFg)
        .tint(uiFg)
        .onAppear { configureControlAppearance() }
    }

    private func configureControlAppearance() {
        let fg = UIColor(uiFg)

        let seg = UISegmentedControl.appearance()
        seg.selectedSegmentTintColor = fg.withAlphaComponent(0.25)
        seg.setTitleTextAttributes([
            .foregroundColor: fg,
            .font: UIFont(name: "Comfortaa", size: 16) ?? .systemFont(ofSize: 16)
        ], for: .normal)
        seg.setTitleTextAttributes([
            .foregroundColor: fg,
            .font: UIFont(name: "Comfortaa", size: 16) ?? .systemFont(ofSize: 16)
        ], for: .selected)
        seg.backgroundColor = fg.withAlphaComponent(0.08)
    }

    // MARK: Left panel (iPad)

    private var leftPanel: some View {
        VStack(spacing: 0) {
            clockPreview
                .frame(maxHeight: .infinity)

            Rectangle()
                .fill(uiFg.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 16)

            controls
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: Clock preview

    private var clockPreview: some View {
        ZStack {
            clockBackground

            VStack(spacing: 12) {
                if useAnalogDisplay {
                    AnalogClockView(
                        time: time,
                        faceColor: clockForeground,
                        detailColor: clockBackground
                    )
                    .padding(24)
                } else {
                    ClockDisplayCanvas(
                        hours: time.hours,
                        minutes: time.minutes,
                        seconds: time.seconds,
                        showLeadingZeros: showLeadingZeros,
                        foregroundColor: clockForeground
                    )
                    .aspectRatio(11.0 / 3.0, contentMode: .fit)
                    .padding(.horizontal, 16)
                }

                if showDecimalValues && !useAnalogDisplay {
                    DecimalReadoutView(time: time, useBalancedDecimal: useBalancedDecimal)
                        .foregroundStyle(clockForeground)
                }
            }
            .padding(.vertical, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture { onClose() }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("Show leading zeros", isOn: $showLeadingZeros)
                .toggleStyle(FlatToggleStyle(color: uiFg))
                .opacity(useAnalogDisplay ? 0 : 1)
                .allowsHitTesting(!useAnalogDisplay)
            Toggle("Show decimal values", isOn: $showDecimalValues)
                .toggleStyle(FlatToggleStyle(color: uiFg))
                .opacity(useAnalogDisplay ? 0 : 1)
                .allowsHitTesting(!useAnalogDisplay)

            Picker("Notation", selection: $useBalancedDecimal) {
                Text("Unbalanced").tag(false)
                Text("Balanced").tag(true)
            }
            .pickerStyle(.segmented)
            .opacity(showDecimalValues && !useAnalogDisplay ? 1 : 0)
            .allowsHitTesting(showDecimalValues && !useAnalogDisplay)

            Text("Color")
            colorSelector

            Toggle("Invert", isOn: $invertColors)
                .toggleStyle(FlatToggleStyle(color: uiFg))
            Toggle("Analog display", isOn: $useAnalogDisplay)
                .toggleStyle(FlatToggleStyle(color: uiFg))

            Button(action: onClose) {
                Text("Close settings")
                    .font(.custom("Comfortaa", size: 16))
                    .foregroundStyle(uiFg.opacity(1))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 8)
        }
        .padding(24)
    }

    // MARK: Color selector

    private var colorSelector: some View {
        HStack(spacing: 0) {
            ForEach(0..<ColorPalette.entries.count, id: \.self) { i in
                Circle()
                    .fill(ColorPalette.color(at: i))
                    .frame(
                        width: i == selectedColorIndex ? 20 : 12,
                        height: i == selectedColorIndex ? 20 : 12
                    )
                    .overlay(
                        Circle()
                            .stroke(uiFg.opacity(i == selectedColorIndex ? 0.8 : 0), lineWidth: 1.5)
                    )
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedColorIndex = i
                        }
                    }
            }
        }
    }

    // MARK: Right panel

    private var rightPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Ternary Timekeeping")
                    .font(.custom("Comfortaa", size: 24).weight(.bold))
                    .padding(.bottom, 4)

                infoParagraph(
                    "This is a balanced ternary clock. It divides the day into 27 hours. " +
                    "Each of those is divided into 27 minutes, which are in turn divided " +
                    "into 27 seconds. This means that the ternary hour is a bit shorter " +
                    "than a standard hour, while the ternary minute is about twice as long " +
                    "as a standard minute. The ternary second lasts for about 4.4 standard " +
                    "seconds. This is quite close to what psychologists call the " +
                    "\u{2018}extended present\u{2019}, the duration of time we experience " +
                    "as \u{2018}now\u{2019}."
                )

                infoParagraph(
                    "The display is made out of \u{2018}trits\u{2019}, ternary digits that " +
                    "can each have 3 values: \u{2018}/\u{2019}, \u{2018}|\u{2019} and " +
                    "\u{2018}\\\u{2019}. The lowest value is \u{2018}\\\u{2019}, the center " +
                    "value is \u{2018}|\u{2019} and the highest value is \u{2018}/\u{2019}. " +
                    "You can think of these as representing 0, 1, and 2, but there are " +
                    "other (and perhaps more fitting) ways of thinking about them as well, " +
                    "such as \u{2018}\u{2212}1, 0, +1\u{2019}, \u{2018}down, center, " +
                    "up\u{2019} or \u{2018}left, middle, right\u{2019}."
                )

                infoParagraph(
                    "Unbalanced number systems, like the standard decimal system or the " +
                    "binary system that computers use, do not have a center value. Their " +
                    "most basic ingredients are 0 and 1, and negative numbers need a special " +
                    "sign. In balanced ternary, this is different. You can think of it like " +
                    "using a compass: North and South are opposite directions, but neither " +
                    "of them is more fundamental than the other. In balanced ternary, you " +
                    "can use a single digit to denote the North Pole, the South Pole and " +
                    "the equator (the balance point)."
                )

                infoParagraph(
                    "As you add more digits, you can describe your North\u{2013}South " +
                    "position with increasing accuracy. This way of counting is very well " +
                    "suited for keeping track of things that rotate, like the passage of " +
                    "the day (which tracks the rotation of the Earth around its axis). In " +
                    "this clock, the day is divided into 19683 equal steps. At noon, all " +
                    "the digits are centered at \u{2018}|\u{2019}. At midnight, the display " +
                    "flips over from its highest value, \u{2018}///\u{00B7}///\u{00B7}///\u{2019} " +
                    "to its lowest value \u{2018}\\\\\\\u{00B7}\\\\\\\u{00B7}\\\\\\\u{2019} " +
                    "and the next day begins."
                )

                infoParagraph(
                    "Interestingly, the exact opposite of noon is not a \u{2018}tick\u{2019} " +
                    "of the clock but rather the moment halfway between the highest and " +
                    "lowest value. Midnight is a boundary that the clock approaches and then " +
                    "passes over but never quite lands on. This is a fundamental property of " +
                    "any balanced number system: there is only one precisely defined center, " +
                    "and on the opposite end of that is \u{2018}infinity\u{2019}, a value " +
                    "that cannot be expressed precisely as a number."
                )
            }
            .padding(24)
        }
    }

    private func infoParagraph(_ text: String) -> some View {
        Text(text)
            .font(.custom("Comfortaa", size: 16))
            .lineSpacing(16 * 0.1) // 10% extra line spacing
    }
}

// MARK: - Analog Clock View

struct AnalogClockView: View {
    let time: TernaryTime
    let faceColor: Color      // circle fill
    let detailColor: Color    // markers and hands

    // Hand lengths as fraction of radius
    var hourHandLength: CGFloat = 0.35
    var minuteHandLength: CGFloat = 0.52
    var secondHandLength: CGFloat = 0.69

    // Hand widths as fraction of radius
    var hourHandWidth: CGFloat = 0.025
    var minuteHandWidth: CGFloat = 0.025
    var secondHandWidth: CGFloat = 0.025

    var handOpacity: CGFloat = 0.7

    // Marker line data from SVG — each marker's lines as (x1,y1,x2,y2) in local coords, height=1200
    private static let markers: [(value: Int, width: CGFloat, lines: [(CGFloat, CGFloat, CGFloat, CGFloat)])] = [
        (12,  600, [(600,0, 600,1200), (600,0, 200,1200), (400,0, 0,1200)]),
        ( 9,  600, [(600,0, 600,1200), (400,0, 400,1200), (400,0, 0,1200)]),
        ( 6,  800, [(800,0, 800,1200), (400,0, 800,1200), (400,0, 0,1200)]),
        ( 3,  400, [(400,0, 400,1200), (400,0, 0,1200)]),
        ( 0,    0, [(0,0, 0,1200)]),
        (-3,  400, [(400,0, 400,1200), (0,0, 400,1200)]),
        (-6,  800, [(800,0, 800,1200), (800,0, 400,1200), (0,0, 400,1200)]),
        (-9,  600, [(600,0, 600,1200), (400,0, 400,1200), (0,0, 400,1200)]),
        (-12, 600, [(600,0, 600,1200), (200,0, 600,1200), (0,0, 400,1200)]),
    ]

    var body: some View {
        Canvas { context, size in
            let diameter = min(size.width, size.height)
            let radius = diameter / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Circle face
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius,
                                     width: diameter, height: diameter)
            context.fill(Circle().path(in: circleRect), with: .color(faceColor))

            // Markers
            let markerHeight = radius * 0.21
            let markerOuterR = radius * 0.825
            let markerLineWidth = markerHeight * 0.05
            let markerStyle = StrokeStyle(lineWidth: markerLineWidth, lineCap: .round)
            let markerShading = GraphicsContext.Shading.color(detailColor)

            for marker in Self.markers {
                let angle = CGFloat(marker.value) / 27.0 * 360.0
                drawMarker(marker.lines, markerWidth: marker.width, angle: angle,
                           center: center, outerR: markerOuterR, height: markerHeight,
                           style: markerStyle, shading: markerShading, in: context)
            }

            // Hands
            let handShading = GraphicsContext.Shading.color(detailColor.opacity(handOpacity))

            // Quantize to sub-second ticks (1/27th of a ternary second)
            let ct = CGFloat(floor(time.continuousTotal * 27.0) / 27.0)
            let hourAngle = ct / 19683.0 * 360.0    // one rotation per day
            let minuteAngle = ct / 729.0 * 360.0    // one rotation per ternary hour
            let secondAngle = ct / 27.0 * 360.0     // one rotation per ternary minute

            drawHand(.hour, angle: hourAngle, length: hourHandLength * radius,
                     width: hourHandWidth * radius, center: center, shading: handShading, in: context)
            drawHand(.minute, angle: minuteAngle, length: minuteHandLength * radius,
                     width: minuteHandWidth * radius, center: center, shading: handShading, in: context)
            drawHand(.second, angle: secondAngle, length: secondHandLength * radius,
                     width: secondHandWidth * radius, center: center, shading: handShading, in: context)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Marker drawing

    private func drawMarker(_ lines: [(CGFloat, CGFloat, CGFloat, CGFloat)],
                             markerWidth: CGFloat, angle: CGFloat,
                             center: CGPoint, outerR: CGFloat, height: CGFloat,
                             style: StrokeStyle, shading: GraphicsContext.Shading,
                             in context: GraphicsContext) {
        let scale = height / 1200.0
        let θ = angle * .pi / 180.0

        // Position marker center on the circle, but keep it upright (no rotation)
        let mx = center.x + outerR * sin(θ)
        let my = center.y - outerR * cos(θ)

        for (x1, y1, x2, y2) in lines {
            let px1 = (x1 - markerWidth / 2) * scale
            let py1 = (y1 - 600) * scale  // center vertically (600 = half of 1200)
            let px2 = (x2 - markerWidth / 2) * scale
            let py2 = (y2 - 600) * scale

            let p1 = CGPoint(x: mx + px1, y: my + py1)
            let p2 = CGPoint(x: mx + px2, y: my + py2)

            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)
            context.stroke(path, with: shading, style: style)
        }
    }

    // MARK: Hand drawing

    private enum HandType { case hour, minute, second }

    private func drawHand(_ type: HandType, angle: CGFloat, length: CGFloat,
                           width: CGFloat, center: CGPoint,
                           shading: GraphicsContext.Shading,
                           in context: GraphicsContext) {
        let path = handPath(type, length: length, width: width)
        let θ = angle * .pi / 180.0
        let transform = CGAffineTransform(rotationAngle: θ)
            .concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        context.fill(path.applying(transform), with: shading)
    }

    private func handPath(_ type: HandType, length: CGFloat, width: CGFloat) -> Path {
        let hw = width / 2
        var path = Path()

        // Start at right of center semicircle
        path.move(to: CGPoint(x: hw, y: 0))

        // Semicircle at center (rounded end extending below origin)
        path.addArc(center: .zero, radius: hw,
                     startAngle: .degrees(0), endAngle: .degrees(180),
                     clockwise: false)
        // Now at (-hw, 0)

        // Left edge up + outer termination
        switch type {
        case .second: // triangle tip
            path.addLine(to: CGPoint(x: -hw, y: -(length - width)))
            path.addLine(to: CGPoint(x: 0, y: -length))
            path.addLine(to: CGPoint(x: hw, y: -(length - width)))

        case .minute: // square tip
            path.addLine(to: CGPoint(x: -hw, y: -length))
            path.addLine(to: CGPoint(x: hw, y: -length))

        case .hour: // semicircle tip (rounded end extending outward)
            path.addLine(to: CGPoint(x: -hw, y: -(length - hw)))
            path.addArc(center: CGPoint(x: 0, y: -(length - hw)), radius: hw,
                         startAngle: .degrees(180), endAngle: .degrees(0),
                         clockwise: false)
        }

        // Right edge back down
        path.addLine(to: CGPoint(x: hw, y: 0))
        path.closeSubpath()
        return path
    }
}

// MARK: - Digital Clock Display Canvas

/// Draws the entire digital clock (all trit groups and dot separators) in a single Canvas.
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
    var useBalancedDecimal: Bool = true
    var fontSize: CGFloat = 32

    var body: some View {
        HStack(spacing: fontSize * 0.15) {
            Text(format(time.hoursDecimal))
            Text("\u{00B7}")
            Text(format(time.minutesDecimal))
            Text("\u{00B7}")
            Text(format(time.secondsDecimal))
        }
        .font(.custom("Comfortaa", size: fontSize))
        .opacity(0.5)
    }

    private func format(_ value: Int) -> String {
        if useBalancedDecimal {
            if value > 0 { return "+\(value)" }
            if value < 0 { return "\(value)" }
            return "0"
        } else {
            return "\(value + 13)"
        }
    }
}

// MARK: - Flat Toggle Style

struct FlatToggleStyle: ToggleStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()

            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 26)

                Circle()
                    .fill(color)
                    .frame(width: 22, height: 22)
                    .padding(2)
            }
            .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            .onTapGesture { configuration.isOn.toggle() }
        }
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
