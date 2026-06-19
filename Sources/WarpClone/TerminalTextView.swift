import SwiftUI
import AppKit

struct TerminalTextView: NSViewRepresentable {
    var text: String
    var fontName: String
    var fontSize: Double

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.font = NSFont(name: fontName, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        let parser = ANSIParser()
        let attributed = NSMutableAttributedString()
        for span in parser.parse(text) {
            attributed.append(NSAttributedString(string: span.text, attributes: attributes(for: span.style)))
        }
        textView.textStorage?.setAttributedString(attributed)
        textView.font = NSFont(name: fontName, size: fontSize) ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }

    private func attributes(for style: TerminalStyle) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor.labelColor,
            .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: style.bold ? .bold : .regular)
        ]
        if let foreground = style.foreground {
            attributes[.foregroundColor] = nsColor(foreground)
        }
        if let background = style.background {
            attributes[.backgroundColor] = nsColor(background)
        }
        if style.italic {
            attributes[.obliqueness] = 0.15
        }
        if style.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attributes
    }

    private func nsColor(_ terminalColor: TerminalColor) -> NSColor {
        switch terminalColor.kind {
        case .rgb(let red, let green, let blue):
            return NSColor(
                calibratedRed: CGFloat(red) / 255,
                green: CGFloat(green) / 255,
                blue: CGFloat(blue) / 255,
                alpha: 1
            )
        case .palette(let value):
            let base: [NSColor] = [
                .black, .systemRed, .systemGreen, .systemYellow,
                .systemBlue, .systemPink, .systemTeal, .white,
                .darkGray, .systemRed, .systemGreen, .systemYellow,
                .systemBlue, .systemPink, .systemTeal, .lightGray
            ]
            if value < base.count { return base[value] }
            let level = CGFloat(value % 24) / 23
            return NSColor(calibratedWhite: level, alpha: 1)
        }
    }
}
