import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    struct SelectionStyle {
        let fontSize: Double
        let colorKey: String
        let isBold: Bool
        let isItalic: Bool
        let isUnderlined: Bool
    }

    @Binding var text: String
    @Binding var fontSize: Double
    @Binding var textColor: Color
    @Binding var textColorKey: String
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var isUnderlined: Bool
    @Binding var applyStyleRevision: Int
    let onSelectionStyleChange: (SelectionStyle) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSelectionStyleChange: onSelectionStyleChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isRichText = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.usesFindPanel = true
        textView.backgroundColor = .clear
        textView.delegate = context.coordinator
        textView.textContainerInset = NSSize(width: 4, height: 8)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        textView.string = text
        let style = currentStyle()
        textView.typingAttributes = style.attributes
        context.coordinator.lastAppliedStyle = style
        context.coordinator.lastAppliedRevision = applyStyleRevision

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else {
            return
        }

        if textView.string != text {
            textView.string = text
        }

        let style = currentStyle()
        if context.coordinator.lastAppliedRevision != applyStyleRevision {
            applyStyleChange(to: textView, style: style)
            context.coordinator.lastAppliedStyle = style
            context.coordinator.lastAppliedRevision = applyStyleRevision
        }
    }

    private func currentStyle() -> Coordinator.TextStyle {
        var font = NSFont.systemFont(ofSize: fontSize, weight: isBold ? .bold : .regular)
        if isItalic, let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) as NSFont? {
            font = italicFont
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(textColor),
            .underlineStyle: isUnderlined ? NSUnderlineStyle.single.rawValue : 0
        ]

        return Coordinator.TextStyle(attributes: attributes)
    }

    private func applyStyleChange(to textView: NSTextView, style: Coordinator.TextStyle) {
        let selectedRange = textView.selectedRange()

        if selectedRange.length > 0 {
            textView.textStorage?.beginEditing()
            textView.textStorage?.addAttributes(style.attributes, range: selectedRange)
            textView.textStorage?.endEditing()
        }

        textView.typingAttributes = style.attributes
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        struct TextStyle: Equatable {
            let attributes: [NSAttributedString.Key: Any]

            static func == (lhs: TextStyle, rhs: TextStyle) -> Bool {
                guard
                    let lhsFont = lhs.attributes[.font] as? NSFont,
                    let rhsFont = rhs.attributes[.font] as? NSFont,
                    let lhsColor = lhs.attributes[.foregroundColor] as? NSColor,
                    let rhsColor = rhs.attributes[.foregroundColor] as? NSColor,
                    let lhsUnderline = lhs.attributes[.underlineStyle] as? Int,
                    let rhsUnderline = rhs.attributes[.underlineStyle] as? Int
                else {
                    return false
                }

                return lhsFont == rhsFont && lhsColor == rhsColor && lhsUnderline == rhsUnderline
            }
        }

        @Binding var text: String
        let onSelectionStyleChange: (SelectionStyle) -> Void
        weak var textView: NSTextView?
        var lastAppliedStyle: TextStyle?
        var lastAppliedRevision: Int = 0

        init(text: Binding<String>, onSelectionStyleChange: @escaping (SelectionStyle) -> Void) {
            _text = text
            self.onSelectionStyleChange = onSelectionStyleChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else {
                return
            }
            text = textView.string
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView else {
                return
            }

            let attrs = selectedAttributes(in: textView)
            let style = styleFromAttributes(attrs)
            onSelectionStyleChange(style)
        }

        private func selectedAttributes(in textView: NSTextView) -> [NSAttributedString.Key: Any] {
            let selectedRange = textView.selectedRange()
            let length = textView.textStorage?.length ?? 0

            if selectedRange.length > 0, selectedRange.location < length,
               let attrs = textView.textStorage?.attributes(at: selectedRange.location, effectiveRange: nil) {
                return attrs
            }

            if selectedRange.location > 0, selectedRange.location - 1 < length,
               let attrs = textView.textStorage?.attributes(at: selectedRange.location - 1, effectiveRange: nil) {
                return attrs
            }

            return textView.typingAttributes
        }

        private func styleFromAttributes(_ attrs: [NSAttributedString.Key: Any]) -> SelectionStyle {
            let font = (attrs[.font] as? NSFont) ?? NSFont.systemFont(ofSize: 16)
            let traits = NSFontManager.shared.traits(of: font)
            let isBold = traits.contains(.boldFontMask)
            let isItalic = traits.contains(.italicFontMask)

            let underlineValue = attrs[.underlineStyle] as? Int ?? 0
            let isUnderlined = underlineValue != 0

            let color = attrs[.foregroundColor] as? NSColor ?? .black
            let colorKey = colorKeyForNSColor(color)

            return SelectionStyle(
                fontSize: font.pointSize,
                colorKey: colorKey,
                isBold: isBold,
                isItalic: isItalic,
                isUnderlined: isUnderlined
            )
        }

        private func colorKeyForNSColor(_ color: NSColor) -> String {
            let rgb = color.usingColorSpace(.deviceRGB) ?? .black
            let red = rgb.redComponent
            let green = rgb.greenComponent
            let blue = rgb.blueComponent

            if red > 0.7, green < 0.4, blue < 0.4 {
                return "red"
            }
            if green > 0.5, red < 0.5, blue < 0.5 {
                return "green"
            }
            if blue > 0.6, red < 0.5, green < 0.6 {
                return "blue"
            }
            return "black"
        }
    }
}
