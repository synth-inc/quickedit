//
//  DemoTextBox.swift
//  Onit
//
//  Created by Kévin Naudin on 15/12/2025.
//

import SwiftUI
import AppKit

/// Selection info including text and screen bounds
struct DemoTextSelection {
    let text: String
    let range: NSRange
    let screenBounds: CGRect
}

struct DemoTextBox: View {
    @Binding var text: String
    let onSelectionChanged: (DemoTextSelection?) -> Void

    private let backgroundColor = Color.special1
    private let borderColor = Color.T_3

    var body: some View {
        DemoTextView(
            text: $text,
            onSelectionChanged: onSelectionChanged
        )
        .frame(width: 452, height: 205)
        .background(backgroundColor)
        .addBorder(
            cornerRadius: 14,
            stroke: borderColor,
            dotted: true
        )
    }
}

struct DemoTextView: NSViewRepresentable {
    @Binding var text: String
    let onSelectionChanged: (DemoTextSelection?) -> Void

    func makeNSView(context: Self.Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.string = text
        textView.font = .systemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.S_0
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        
        textView.textContainerInset = NSSize(width: 15, height: 15)
        textView.delegate = context.coordinator

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: NSColor.S_0,
            .paragraphStyle: paragraphStyle
        ]
        textView.typingAttributes = attributes

        if !text.isEmpty {
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            textView.textStorage?.setAttributedString(attributedString)
        }

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Self.Context) {
        let textView = nsView.documentView as! NSTextView
        if textView.string != text {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: NSColor.S_0,
                .paragraphStyle: paragraphStyle
            ]

            let attributedString = NSAttributedString(string: text, attributes: attributes)
            textView.textStorage?.setAttributedString(attributedString)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: DemoTextView

        init(_ parent: DemoTextView) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            let range = textView.selectedRange()

            if range.length > 0 {
                let selectedText = (textView.string as NSString).substring(with: range)

                if let screenBounds = getSelectionScreenBounds(textView: textView, range: range) {
                    let selection = DemoTextSelection(
                        text: selectedText,
                        range: range,
                        screenBounds: screenBounds
                    )
                    
                    parent.onSelectionChanged(selection)
                }
            } else {
                parent.onSelectionChanged(nil)
            }
        }

        @MainActor
        private func getSelectionScreenBounds(textView: NSTextView, range: NSRange) -> CGRect? {
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                return nil
            }

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // Adjust for text container inset
            boundingRect.origin.x += textView.textContainerInset.width
            boundingRect.origin.y += textView.textContainerInset.height

            let windowRect = textView.convert(boundingRect, to: nil)

            guard let window = textView.window else { return nil }
            
            let screenRect = window.convertToScreen(windowRect)

            return screenRect
        }
    }
}
