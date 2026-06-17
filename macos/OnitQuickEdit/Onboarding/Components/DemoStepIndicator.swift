//
//  DemoStepIndicator.swift
//  Onit
//
//  Created by Kévin Naudin on 15/12/2025.
//

import SwiftUI

struct DemoStepIndicator: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 0) {
            StepCircle(label: String.localized("Select text", table: "Onboarding"), isCompleted: currentStep > 1, isActive: currentStep >= 1)
            StepLine(isCompleted: currentStep > 1)
            StepCircle(label: String.localized("Improve", table: "Onboarding"), isCompleted: currentStep > 2, isActive: currentStep >= 2)
            StepLine(isCompleted: currentStep > 2)
            StepCircle(label: String.localized("Insert", table: "Onboarding"), isCompleted: currentStep > 3, isActive: currentStep >= 3)
        }
    }
}

struct StepCircle: View {
    let label: String
    let isCompleted: Bool
    let isActive: Bool

    private let activeColor = Color.T_8.opacity(1)
    private let inactiveColor = Color.T_8.opacity(0.7)

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                if isCompleted {
                    Circle()
                        .fill(Color.lime400)
                        .frame(width: 16, height: 16)

                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.lime900)
                        .offset(x: 0.5)
                } else {
                    Circle()
                        .fill(isActive ? activeColor : inactiveColor)
                        .frame(width: 16, height: 16)
                }
            }

            Text(label)
                .font(.system(size: 15))
                .foregroundColor(isActive ? Color.S_0 : Color.S_0.opacity(0.4))
        }
    }
}

struct StepLine: View {
    let isCompleted: Bool
    
    private let lineColor = Color.T_6

    var body: some View {
        Rectangle()
            .fill(lineColor)
            .frame(width: 40, height: 1.5)
            .padding(.horizontal, 7)
    }
}
