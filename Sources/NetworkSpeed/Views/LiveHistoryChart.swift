import SwiftUI
import AppKit

public struct LiveHistoryChart: View {
    let history: [SpeedSample]
    let base: UnitBase
    let height: CGFloat
    let showGridLabels: Bool
    
    public init(
        history: [SpeedSample],
        base: UnitBase = .binary1024,
        height: CGFloat = 58,
        showGridLabels: Bool = false
    ) {
        self.history = history
        self.base = base
        self.height = height
        self.showGridLabels = showGridLabels
    }
    
    public var body: some View {
        let maxDown = history.map(\.download).max() ?? 1024
        let maxUp = history.map(\.upload).max() ?? 1024
        let peakSpeed = max(max(maxDown, maxUp), 1024)
        let peakFormatted = SpeedFormatter.format(bytesPerSecond: peakSpeed, base: base)
        let midFormatted = SpeedFormatter.format(bytesPerSecond: peakSpeed / 2, base: base)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(showGridLabels ? "Real-Time Activity (60s)" : "Activity (60s)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text("Download")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Upload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    Canvas { context, size in
                        guard history.count > 1 else { return }
                        
                        let width = size.width
                        let h = size.height
                        let stepX = width / CGFloat(max(history.count - 1, 1))
                        
                        // Background grid lines (25%, 50%, 75%)
                        let gridPercentages: [CGFloat] = showGridLabels ? [0.25, 0.5, 0.75] : [0.5]
                        for pct in gridPercentages {
                            var gridPath = Path()
                            gridPath.move(to: CGPoint(x: 0, y: h * pct))
                            gridPath.addLine(to: CGPoint(x: width, y: h * pct))
                            context.stroke(
                                gridPath,
                                with: .color(Color(nsColor: .separatorColor).opacity(0.2)),
                                style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                            )
                        }
                        
                        func buildPoints(selector: (SpeedSample) -> Double) -> [CGPoint] {
                            var points: [CGPoint] = []
                            for (idx, sample) in history.enumerated() {
                                let val = selector(sample)
                                let ratio = CGFloat(min(val / peakSpeed, 1.0))
                                let y = h - (ratio * (h - 6)) - 3
                                let x = CGFloat(idx) * stepX
                                points.append(CGPoint(x: x, y: y))
                            }
                            return points
                        }
                        
                        let downPoints = buildPoints { $0.download }
                        let upPoints = buildPoints { $0.upload }
                        
                        // Download area
                        var downArea = Path()
                        if let first = downPoints.first {
                            downArea.move(to: CGPoint(x: first.x, y: h))
                            downArea.addLine(to: first)
                            for pt in downPoints.dropFirst() {
                                downArea.addLine(to: pt)
                            }
                            if let last = downPoints.last {
                                downArea.addLine(to: CGPoint(x: last.x, y: h))
                            }
                            downArea.closeSubpath()
                            
                            let downGrad = Gradient(colors: [
                                Color.blue.opacity(0.22),
                                Color.blue.opacity(0.02)
                            ])
                            context.fill(downArea, with: .linearGradient(downGrad, startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                        }
                        
                        // Download line (Apple Blue)
                        var downLine = Path()
                        if let first = downPoints.first {
                            downLine.move(to: first)
                            for pt in downPoints.dropFirst() {
                                downLine.addLine(to: pt)
                            }
                            context.stroke(
                                downLine,
                                with: .color(Color.blue),
                                style: StrokeStyle(lineWidth: showGridLabels ? 2.0 : 1.5, lineCap: .round, lineJoin: .round)
                            )
                        }
                        
                        // Upload line (Apple Orange)
                        var upLine = Path()
                        if let first = upPoints.first {
                            upLine.move(to: first)
                            for pt in upPoints.dropFirst() {
                                upLine.addLine(to: pt)
                            }
                            context.stroke(
                                upLine,
                                with: .color(Color.orange),
                                style: StrokeStyle(lineWidth: showGridLabels ? 2.0 : 1.5, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .frame(height: height)
                    
                    if showGridLabels {
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(peakFormatted.fullString)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(midFormatted.fullString)
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0 B/s")
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 58, height: height, alignment: .trailing)
                        .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
            }
            
            if showGridLabels {
                HStack {
                    Text("60s ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("30s ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Now")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 4)
            }
        }
    }
}
