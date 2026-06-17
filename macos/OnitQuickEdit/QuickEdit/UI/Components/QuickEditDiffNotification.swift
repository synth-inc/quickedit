//
//  QuickEditDiffNotification.swift
//  Onit
//
//  Created by Kévin Naudin on 12/17/2025.
//

import SwiftUI

/// Notification banner shown when diff view is enabled, informing user to turn it off to edit
struct QuickEditDiffNotification: View {

    @ObservedObject var state: QuickEditState

    @State private var isHovered: Bool = false
    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        if state.isDiffNotificationVisible {
            HStack(alignment: .center, spacing: 6) {
                Circle()
                    .fill(Color.orange500)
                    .frame(width: 7, height: 7)
                
                HStack(alignment: .center, spacing: 3) {
                    Text(String.localized("Turn off", table: "QuickEdit"))
                        .styleText(size: 12, weight: .medium, color: Color.S_0)

                    Image(.charmDiff)
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: 13, height: 13)
                        .foregroundColor(Color.S_0)

                    Text(String.localized("Diff view to edit", table: "QuickEdit"))
                        .styleText(size: 12, weight: .medium, color: Color.S_0)
                }
                
                Spacer()
                
                if isHovered {
                    Button(action: {
                        dismissNotification()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.S_0)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange500.opacity(0.1))
            .onHover { hovering in
                isHovered = hovering
                
                if hovering {
                    dismissTask?.cancel()
                    dismissTask = nil
                } else {
                    startAutoDismissTimer()
                }
            }
            .onAppear {
                startAutoDismissTimer()
            }
            .onDisappear {
                dismissTask?.cancel()
                dismissTask = nil
            }
        }
    }

    // MARK: - Private Methods

    private func startAutoDismissTimer() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            if !Task.isCancelled {
                dismissNotification()
            }
        }
    }

    private func dismissNotification() {
        state.isDiffNotificationDismissed = true
    }
}
