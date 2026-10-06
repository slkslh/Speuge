import SwiftUI
import Charts

/// Live download/upload history, drawn with Swift Charts (macOS 13+).
public struct LiveHistoryChart: View {
    let history: [SpeedSample]
    let base: UnitBase
    /// Charts need an explicit height inside a Form.
    let height: CGFloat

    public init(history: [SpeedSample], base: UnitBase = .binary1024, height: CGFloat = 140) {
        self.history = history
        self.base = base
        self.height = height
    }

    public var body: some View {
        let peak = max(history.map { max($0.download, $0.upload) }.max() ?? 0, 1024)

        Chart {
            ForEach(history) { sample in
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Speed", sample.download)
                )
                .foregroundStyle(by: .value("Direction", "Download"))

                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value("Speed", sample.upload)
                )
                .foregroundStyle(by: .value("Direction", "Upload"))
            }
        }
        .chartForegroundStyleScale([
            "Download": Semantic.download,
            "Upload": Semantic.upload
        ])
        .chartYScale(domain: 0...peak)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bytesPerSecond = value.as(Double.self) {
                        Text(SpeedFormatter.format(bytesPerSecond: bytesPerSecond, base: base).fullString)
                            .monospacedDigit()
                    }
                }
            }
        }
        .chartLegend(position: .top, alignment: .trailing)
        .frame(height: height)
        .accessibilityLabel("Network activity over the last 60 seconds")
    }
}
