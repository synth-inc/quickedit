//
//  Backgrounds.swift
//  Onit
//
//  Created by Loyd Kim on 7/29/25.
//

import SwiftUI

struct GlassBackground: View {
    var body: some View {
        Rectangle()
            .fill(.thinMaterial)
            .opacity(0.5)
    }
}

struct Backgrounds {
    struct BrushedGlass: NSViewRepresentable {
        /// `.behindWindow` blurs whatever is behind the window (desktop included) —
        /// right for floating overlays. Views hosted inside a regular window should
        /// pass `.withinWindow` so the material blends with the window's own
        /// background instead of the desktop.
        var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

        private func setVisualEffectView(_ visualEffectView: NSVisualEffectView) {
            visualEffectView.material = .hudWindow /// Set macOS HUD material as the window background.
            visualEffectView.blendingMode = blendingMode
            visualEffectView.state = .active /// Persist glass-like appearance.
        }
        
        func makeNSView(context: Self.Context) -> NSVisualEffectView {
            let visualEffectView = NSVisualEffectView()
            setVisualEffectView(visualEffectView)
            return visualEffectView
        }
        
        func updateNSView(_ visualEffectView: NSVisualEffectView, context: Self.Context) {
            setVisualEffectView(visualEffectView)
        }
    }
}
