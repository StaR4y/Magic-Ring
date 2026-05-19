import SwiftUI

struct SparklineView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(.white.opacity(0.055))

                SparklineShape(values: normalizedValues)
                    .stroke(
                        tint.gradient,
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                    .animation(.easeOut(duration: 0.32), value: normalizedValues)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 23)
    }

    private var normalizedValues: [Double] {
        values.map { min(max($0, 0), 1) }
    }
}

private struct SparklineShape: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else {
            return Path()
        }

        let stepX = rect.width / CGFloat(values.count - 1)
        var path = Path()

        for index in values.indices {
            let x = CGFloat(index) * stepX
            let y = rect.maxY - CGFloat(values[index]) * rect.height
            let point = CGPoint(x: x, y: y)

            if index == values.startIndex {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}
