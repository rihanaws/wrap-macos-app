import Foundation

struct TerminalColor: Equatable, Codable {
    enum Kind: Equatable, Codable {
        case palette(Int)
        case rgb(Int, Int, Int)
    }

    var kind: Kind
}

struct TerminalStyle: Equatable, Codable {
    var foreground: TerminalColor?
    var background: TerminalColor?
    var bold = false
    var dim = false
    var italic = false
    var underline = false
}

struct TerminalSpan: Equatable, Codable {
    var text: String
    var style: TerminalStyle
}

final class ANSIParser {
    func parse(_ input: String) -> [TerminalSpan] {
        var spans: [TerminalSpan] = []
        var style = TerminalStyle()
        var buffer = ""
        var index = input.startIndex

        func flush() {
            guard !buffer.isEmpty else { return }
            spans.append(TerminalSpan(text: buffer, style: style))
            buffer.removeAll(keepingCapacity: true)
        }

        while index < input.endIndex {
            let char = input[index]
            if char == "\u{1B}" {
                let next = input.index(after: index)
                guard next < input.endIndex, input[next] == "[" else {
                    buffer.append(char)
                    index = input.index(after: index)
                    continue
                }
                var sequenceEnd = input.index(after: next)
                while sequenceEnd < input.endIndex, !isFinalByte(input[sequenceEnd]) {
                    sequenceEnd = input.index(after: sequenceEnd)
                }
                guard sequenceEnd < input.endIndex else { break }
                let final = input[sequenceEnd]
                let params = String(input[input.index(after: next)..<sequenceEnd])
                flush()
                apply(params: params, final: final, style: &style)
                index = input.index(after: sequenceEnd)
            } else {
                buffer.append(char)
                index = input.index(after: index)
            }
        }
        flush()
        return spans
    }

    private func isFinalByte(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return scalar.value >= 0x40 && scalar.value <= 0x7E
    }

    private func apply(params: String, final: Character, style: inout TerminalStyle) {
        guard final == "m" else { return }
        var values = params
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { Int($0) ?? 0 }
        if values.isEmpty { values = [0] }

        var i = 0
        while i < values.count {
            let value = values[i]
            switch value {
            case 0:
                style = TerminalStyle()
            case 1:
                style.bold = true
            case 2:
                style.dim = true
            case 3:
                style.italic = true
            case 4:
                style.underline = true
            case 22:
                style.bold = false
                style.dim = false
            case 23:
                style.italic = false
            case 24:
                style.underline = false
            case 30...37:
                style.foreground = TerminalColor(kind: .palette(value - 30))
            case 40...47:
                style.background = TerminalColor(kind: .palette(value - 40))
            case 90...97:
                style.foreground = TerminalColor(kind: .palette(value - 90 + 8))
            case 100...107:
                style.background = TerminalColor(kind: .palette(value - 100 + 8))
            case 39:
                style.foreground = nil
            case 49:
                style.background = nil
            case 38, 48:
                let isForeground = value == 38
                if i + 2 < values.count, values[i + 1] == 5 {
                    let color = TerminalColor(kind: .palette(values[i + 2]))
                    if isForeground { style.foreground = color } else { style.background = color }
                    i += 2
                } else if i + 4 < values.count, values[i + 1] == 2 {
                    let color = TerminalColor(kind: .rgb(values[i + 2], values[i + 3], values[i + 4]))
                    if isForeground { style.foreground = color } else { style.background = color }
                    i += 4
                }
            default:
                break
            }
            i += 1
        }
    }
}
