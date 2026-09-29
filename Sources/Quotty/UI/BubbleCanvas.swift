import SwiftUI

public struct BubbleCanvas: View {
    public let startX: CGFloat
    public let endX: CGFloat
    public let height: CGFloat
    public let animTime: Double
    public let color: Color

    public init(startX: CGFloat, endX: CGFloat, height: CGFloat, animTime: Double, color: Color = Color.white) {
        self.startX = startX
        self.endX = endX
        self.height = height
        self.animTime = animTime
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            // Reduced from 8 to 5 bubbles for lower GPU usage
            let count = 5
            let span = max(10.0, endX - startX)
            
            for i in 0..<count {
                let fi = Double(i)
                let seed = fi * 1.37
                let speed = 0.5 + 0.5 * sin(seed * 3.0)
                let progress = (animTime * 0.35 * speed + seed).truncatingRemainder(dividingBy: 1.0)
                
                let x = startX + CGFloat(progress) * span
                let yWave = sin(animTime * 1.8 + fi) * 2.0
                let y = (height / 2.0) + CGFloat(yWave) - CGFloat(progress * 3.5)
                
                // Glass-like refractive bubbles — white with variable opacity
                let radius = CGFloat(1.0 + 1.0 * sin(seed * 7.0))
                let alpha = sin(progress * .pi) * 0.55
                
                let circleRect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: circleRect), with: .color(color.opacity(alpha)))
                
                // Subtle specular highlight on each bubble
                if radius > 1.2 {
                    let highlightRadius = radius * 0.4
                    let highlightRect = CGRect(
                        x: x - highlightRadius * 0.5,
                        y: y - radius + highlightRadius * 0.3,
                        width: highlightRadius,
                        height: highlightRadius
                    )
                    context.fill(Path(ellipseIn: highlightRect), with: .color(Color.white.opacity(alpha * 0.4)))
                }
            }
        }
    }
}
