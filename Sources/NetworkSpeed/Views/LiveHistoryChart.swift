import SwiftUI

public struct LiveHistoryChart: View {
    let history: [SpeedSample]
    let base: UnitBase
    
    public init(history: [SpeedSample], base: UnitBase = .binary1024) {
        self.history = history
        self.base = base
    }
    
    public var body: some View {
        let maxDown = history.map(\.download).max() ?? 1024
        let maxUp = history.map(\.upload).max() ?? 1024
        let peakSpeed = max(max(maxDown, maxUp), 1024)
        
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Activity (60s)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text("Download")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text("Upload")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            ZStack(alignment: .topTrailing) {
                Canvas { context, size in
                    guard history.count > 1 else { return }
                    
                    let width = size.width
                    let height = size.height
                    let stepX = width / CGFloat(max(history.count - 1, 1))
                    
                    // Background grid line (mid line)
                    var midPath = Path()
                    midPath.move(to: CGPoint(x: 0, y: height * 0.5))
                    midPath.addLine(to: CGPoint(x: width, y: height * 0.5))
                    context.stroke(midPath, with: .color(Color(nsColor: .separatorColor).opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    
                    func buildPoints(selector: (SpeedSample) -> Double) -> [CGPoint] {
                        var points: [CGPoint] = []
                        for (idx, sample) in history.enumerated() {
                            let val = selector(sample)
                            let ratio = CGFloat(min(val / peakSpeed, 1.0))
                            let y = height - (ratio * (height - 4)) - 2
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
                        downArea.move(to: CGPoint(x: first.x, y: height))
                        downArea.addLine(to: first)
                        for pt in downPoints.dropFirst() {
                            downArea.addLine(to: pt)
                        }
                        if let last = downPoints.last {
                            downArea.addLine(to: CGPoint(x: last.x, y: height))
                        }
                        downArea.closeSubpath()
                        
                        let downGrad = Gradient(colors: [
                            Color.blue.opacity(0.18),
                            Color.blue.opacity(0.02)
                        ])
                        context.fill(downArea, with: .linearGradient(downGrad, startPoint: .zero, endPoint: CGPoint(x: 0, y: height)))
                    }
                    
                    // Download line (Apple Blue)
                    var downLine = Path()
                    if let first = downPoints.first {
                        downLine.move(to: first)
                        for pt in downPoints.dropFirst() {
                            downLine.addLine(to: pt)
                        }
                        context.stroke(downLine, with: .color(Color.blue), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                    
                    // Upload line (Apple Orange)
                    var upLine = Path()
                    if let first = upPoints.first {
                        upLine.move(to: first)
                        for pt in upPoints.dropFirst() {
                            upLine.addLine(to: pt)
                        }
                        context.stroke(upLine, with: .color(Color.orange), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(height: 58)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
            }
        }
    }
}
