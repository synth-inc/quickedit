//
//  Shimmering.swift
//  Onit
//
//  Created by Kévin Naudin on 10/06/2026.
//

import SwiftUI

/// A view modifier that applies an animated "shimmer" to any view,
/// typically to show that an operation is in progress.
///
/// The content is masked by a translucent-opaque-translucent linear gradient
/// that sweeps across the view in a loop.
struct ShimmeringModifier: ViewModifier {

    /// The default sweep animation.
    static let defaultAnimation = Animation.linear(duration: 1.5)
        .delay(0.25)
        .repeatForever(autoreverses: false)

    /// The default gradient used as the animated mask.
    static let defaultGradient = Gradient(colors: [
        .black.opacity(0.3),  // translucent
        .black,               // opaque
        .black.opacity(0.3)   // translucent
    ])

    private let animation: Animation
    private let gradient: Gradient
    private let min, max: CGFloat

    @State private var isInitialState = true
    @Environment(\.layoutDirection) private var layoutDirection

    /// - Parameters:
    ///   - animation: A custom animation. Defaults to ``defaultAnimation``.
    ///   - gradient: A custom gradient. Defaults to ``defaultGradient``.
    ///   - bandSize: The size of the animated mask's "band", in unit points
    ///     beyond the gradient's edges. Defaults to 0.3.
    init(
        animation: Animation = Self.defaultAnimation,
        gradient: Gradient = Self.defaultGradient,
        bandSize: CGFloat = 0.3
    ) {
        self.animation = animation
        self.gradient = gradient
        self.min = 0 - bandSize
        self.max = 1 + bandSize
    }

    /// The start unit point of the gradient, adjusting for layout direction.
    private var startPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            isInitialState ? UnitPoint(x: max, y: min) : UnitPoint(x: 0, y: 1)
        } else {
            isInitialState ? UnitPoint(x: min, y: min) : UnitPoint(x: 1, y: 1)
        }
    }

    /// The end unit point of the gradient, adjusting for layout direction.
    private var endPoint: UnitPoint {
        if layoutDirection == .rightToLeft {
            isInitialState ? UnitPoint(x: 1, y: 0) : UnitPoint(x: min, y: max)
        } else {
            isInitialState ? UnitPoint(x: 0, y: 0) : UnitPoint(x: max, y: max)
        }
    }

    func body(content: Content) -> some View {
        content
            .mask(LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint))
            .animation(animation, value: isInitialState)
            .onAppear {
                // Delay the animation until the initial layout is established
                // to prevent animating the appearance of the view.
                DispatchQueue.main.async {
                    isInitialState = false
                }
            }
    }
}

extension View {

    /// Adds an animated shimmering effect to any view,
    /// typically to show that an operation is in progress.
    /// - Parameters:
    ///   - active: Convenience parameter to conditionally enable the effect. Defaults to `true`.
    ///   - animation: A custom animation. Defaults to ``ShimmeringModifier/defaultAnimation``.
    ///   - gradient: A custom gradient. Defaults to ``ShimmeringModifier/defaultGradient``.
    ///   - bandSize: The size of the animated mask's "band". Defaults to 0.3 unit points.
    @ViewBuilder
    func shimmering(
        active: Bool = true,
        animation: Animation = ShimmeringModifier.defaultAnimation,
        gradient: Gradient = ShimmeringModifier.defaultGradient,
        bandSize: CGFloat = 0.3
    ) -> some View {
        if active {
            modifier(ShimmeringModifier(animation: animation, gradient: gradient, bandSize: bandSize))
        } else {
            self
        }
    }
}
