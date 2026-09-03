import SwiftUI

public struct BubbleCanvas: View {
    public let startX: CGFloat
    public let endX: CGFloat
    public let height: CGFloat
    public let animTime: Double
    public let color: Color

    public init(startX: CGFloat, endX: CGFloat, height: CGFloat, animTime: Double, color: Color = Color(red: 150/255, green: 224/255, blue: 176/255)) {
        self.startX = startX
        self.endX = endX
        self.height = height
        self.animTime = animTime
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let count = 8
            let span = max(10.0, endX - startX)
            
            for i in 0..<count {
                let fi = Double(i)
                let seed = fi * 1.37
                let speed = 0.5 + 0.5 * sin(seed * 3.0)
                let progress = (animTime * 0.4 * speed + seed).truncatingRemainder(dividingBy: 1.0)
                
                let x = startX + CGFloat(progress) * span
                let yWave = sin(animTime * 2.0 + fi) * 2.5
                let y = (height / 2.0) + CGFloat(yWave) - CGFloat(progress * 4.0)
                
                let radius = CGFloat(1.2 + 0.8 * sin(seed * 7.0))
                // Fade in near start, fade out near end
                let alpha = sin(progress * .pi) * 0.7
                
                let circleRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: circleRect), with: .color(color.opacity(alpha)))
            }
        }
    }
}
