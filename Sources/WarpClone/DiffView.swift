import SwiftUI

struct DiffView: View {
    let diffText: String

    @State private var pendingHunkAction: DiffHunkAction?

    private var rows: [DiffRow] {
        DiffParser.parse(diffText)
    }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                switch row.kind {
                case .fileHeader:
                    fileHeader(row.text)
                case .hunkHeader:
                    hunkHeader(row)
                case .addition, .deletion, .context, .noNewline:
                    diffLine(row)
                }
            }
        }
        .textSelection(.enabled)
        .confirmationDialog(
            pendingHunkAction?.title ?? "Hunk Action",
            isPresented: Binding(
                get: { pendingHunkAction != nil },
                set: { if !$0 { pendingHunkAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("OK") { pendingHunkAction = nil }
        } message: {
            Text("Patch application is not implemented yet.")
        }
    }

    private func fileHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.06))
    }

    private func hunkHeader(_ row: DiffRow) -> some View {
        HStack(spacing: 8) {
            Text(row.text)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 12)
            Button("Revert Hunk") {
                pendingHunkAction = DiffHunkAction(title: "Revert Hunk")
            }
            .font(.system(size: 10))
            Button("Apply Hunk") {
                pendingHunkAction = DiffHunkAction(title: "Apply Hunk")
            }
            .font(.system(size: 10))
        }
        .buttonStyle(.bordered)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.10))
    }

    private func diffLine(_ row: DiffRow) -> some View {
        HStack(spacing: 0) {
            Text(row.oldLineNumber.map(String.init) ?? "")
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(row.newLineNumber.map(String.init) ?? "")
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .padding(.trailing, 8)

            Text(row.text)
                .foregroundStyle(row.prefixColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 11, design: .monospaced))
        .padding(.vertical, 1)
        .padding(.trailing, 8)
        .background(row.backgroundColor)
    }
}

private struct DiffHunkAction: Identifiable {
    let id = UUID()
    let title: String
}

private struct DiffRow: Identifiable {
    enum Kind {
        case fileHeader
        case hunkHeader
        case addition
        case deletion
        case context
        case noNewline
    }

    let id = UUID()
    let kind: Kind
    let text: String
    let oldLineNumber: Int?
    let newLineNumber: Int?

    var backgroundColor: Color {
        switch kind {
        case .addition:
            return Color.green.opacity(0.13)
        case .deletion:
            return Color.red.opacity(0.13)
        case .noNewline:
            return Color.secondary.opacity(0.04)
        default:
            return Color.clear
        }
    }

    var prefixColor: Color {
        switch kind {
        case .addition:
            return .green
        case .deletion:
            return .red
        case .noNewline:
            return .secondary
        default:
            return .primary
        }
    }
}

private enum DiffParser {
    static func parse(_ text: String) -> [DiffRow] {
        var rows: [DiffRow] = []
        var oldLine: Int?
        var newLine: Int?

        for line in text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("diff --git") || line.hasPrefix("index ") || line.hasPrefix("--- ") || line.hasPrefix("+++ ") {
                rows.append(DiffRow(kind: .fileHeader, text: line, oldLineNumber: nil, newLineNumber: nil))
                continue
            }

            if line.hasPrefix("@@") {
                let starts = parseHunkStarts(line)
                oldLine = starts.old
                newLine = starts.new
                rows.append(DiffRow(kind: .hunkHeader, text: line, oldLineNumber: nil, newLineNumber: nil))
                continue
            }

            if line.hasPrefix("\\") {
                rows.append(DiffRow(kind: .noNewline, text: line, oldLineNumber: nil, newLineNumber: nil))
                continue
            }

            if line.hasPrefix("+") {
                rows.append(DiffRow(kind: .addition, text: line, oldLineNumber: nil, newLineNumber: newLine))
                newLine = newLine.map { $0 + 1 }
                continue
            }

            if line.hasPrefix("-") {
                rows.append(DiffRow(kind: .deletion, text: line, oldLineNumber: oldLine, newLineNumber: nil))
                oldLine = oldLine.map { $0 + 1 }
                continue
            }

            rows.append(DiffRow(kind: .context, text: line, oldLineNumber: oldLine, newLineNumber: newLine))
            oldLine = oldLine.map { $0 + 1 }
            newLine = newLine.map { $0 + 1 }
        }

        return rows
    }

    private static func parseHunkStarts(_ line: String) -> (old: Int?, new: Int?) {
        let parts = line.split(separator: " ")
        let oldPart = parts.first { $0.hasPrefix("-") }
        let newPart = parts.first { $0.hasPrefix("+") }
        return (parseStart(oldPart), parseStart(newPart))
    }

    private static func parseStart(_ part: Substring?) -> Int? {
        guard let part else { return nil }
        let body = part.dropFirst()
        let start = body.split(separator: ",").first ?? body[...]
        return Int(start)
    }
}
