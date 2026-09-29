import SwiftUI
import AppKit

// MARK: - Glass Effect Configuration

/// Configuration model for Liquid Glass visual effect.
/// Inspired by Apple's spatial design language (visionOS → macOS convergence).
public struct GlassEffectConfiguration {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State
    public var cornerRadius: CGFloat
    public var tintColor: Color
    public var tintOpacity: Double
    public var borderWidth: CGFloat
    public var borderGradient: LinearGradient
    public var hasInnerGlow: Bool
    public var shadowRadius: CGFloat
    public var shadowOpacity: Double

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        cornerRadius: CGFloat = 14,
        tintColor: Color = .black,
        tintOpacity: Double = 0.35,
        borderWidth: CGFloat = 1.0,
        borderGradient: LinearGradient = LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.35), location: 0.0),
                .init(color: Color.white.opacity(0.10), location: 0.4),
                .init(color: Color.white.opacity(0.02), location: 0.8),
                .init(color: Color.clear, location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        hasInnerGlow: Bool = true,
        shadowRadius: CGFloat = 12,
        shadowOpacity: Double = 0.18
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.cornerRadius = cornerRadius
        self.tintColor = tintColor
        self.tintOpacity = tintOpacity
        self.borderWidth = borderWidth
        self.borderGradient = borderGradient
        self.hasInnerGlow = hasInnerGlow
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }

    public static let liquid = GlassEffectConfiguration(
        material: .hudWindow, // Used as a hint: will map to .ultraThinMaterial
        blendingMode: .behindWindow,
        state: .active,
        cornerRadius: 18,
        tintColor: Color(red: 10/255, green: 12/255, blue: 18/255),
        tintOpacity: 0.25, 
        borderWidth: 0.5,
        borderGradient: LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.4), location: 0.0),
                .init(color: Color.white.opacity(0.1), location: 0.2),
                .init(color: Color.clear, location: 0.5),
                .init(color: Color.white.opacity(0.1), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ),
        hasInnerGlow: false,
        shadowRadius: 16,
        shadowOpacity: 0.35
    )

    public static let settingsPanel = GlassEffectConfiguration(
        material: .popover, // Maps to .regularMaterial
        blendingMode: .behindWindow,
        state: .active,
        cornerRadius: 12,
        tintColor: Color(red: 10/255, green: 12/255, blue: 18/255),
        tintOpacity: 0.35,
        borderWidth: 0.5,
        borderGradient: LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.3), location: 0.0),
                .init(color: Color.white.opacity(0.05), location: 0.3),
                .init(color: Color.clear, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ),
        hasInnerGlow: false,
        shadowRadius: 12,
        shadowOpacity: 0.25
    )

    public static let card = GlassEffectConfiguration(
        material: .hudWindow,
        blendingMode: .withinWindow,
        state: .active,
        cornerRadius: 10,
        tintColor: .white,
        tintOpacity: 0.04,
        borderWidth: 0.5,
        borderGradient: LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.white.opacity(0.15), location: 0.0),
                .init(color: Color.clear, location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        ),
        hasInnerGlow: false,
        shadowRadius: 0,
        shadowOpacity: 0
    )
}

// MARK: - AppKit Backing View

public struct VisualEffectBackground: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public let state: NSVisualEffectView.State

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Force vibrantDark so the blur is deeply dark and high contrast
        view.appearance = NSAppearance(named: .vibrantDark)
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - Liquid Glass View Modifier

public struct GlassEffectModifier: ViewModifier {
    public let configuration: GlassEffectConfiguration
    public let opacity: Double

    public init(configuration: GlassEffectConfiguration, opacity: Double = 1.0) {
        self.configuration = configuration
        self.opacity = opacity
    }

    public func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Layer 1: Hardware-accelerated behind-window blur
                    VisualEffectBackground(
                        material: configuration.material,
                        blendingMode: configuration.blendingMode,
                        state: configuration.state
                    )
                    
                    // Layer 2: Subtle ambient tint
                    if configuration.tintOpacity > 0 {
                        configuration.tintColor
                            .opacity(configuration.tintOpacity * opacity)
                    }
                }
            )
            // SwiftUI's clipShape cleanly cuts the NSVisualEffectView without artifacts
            .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius))
            // Layer 3: Crisp specular border on top
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius)
                    .strokeBorder(configuration.borderGradient, lineWidth: configuration.borderWidth)
            )
    }
}

// MARK: - View Extension

public extension View {
    /// Applies Liquid Glass effect to the view.
    /// - Parameters:
    ///   - configuration: Glass effect preset (default: `.liquid`)
    ///   - opacity: Overall opacity multiplier for the tint layer (0.0–1.0)
    func glassEffect(_ configuration: GlassEffectConfiguration = .liquid, opacity: Double = 1.0) -> some View {
        self.modifier(GlassEffectModifier(configuration: configuration, opacity: opacity))
    }
}
