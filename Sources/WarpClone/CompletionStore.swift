import Foundation
import SwiftUI

enum CompletionKind: String, CaseIterable {
    case command = "command"
    case git = "git"
    case path = "path"
    case history = "history"
}

struct CompletionItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let displayText: String
    let kind: CompletionKind
    let icon: String
    let description: String?
}

@MainActor
final class CompletionStore: ObservableObject {
    @Published var suggestions: [CompletionItem] = []
    @Published var selectedIndex = 0
    @Published var isVisible = false

    @AppStorage("warpclone_commandHistory") private var storedHistory = ""

    private let fileManager: FileManager
    private(set) var commandHistory: [CompletionItem] = []

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        loadHistory()
    }

    func updateSuggestions(for input: String, workingDirectory: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hide()
            return
        }

        var results: [CompletionItem] = []
        let parts = input.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        let firstWord = parts.first ?? trimmed
        let lastWord = currentToken(in: input)

        if parts.count == 1, !input.hasSuffix(" ") {
            results.append(contentsOf: commandHistory.filter {
                $0.text.localizedCaseInsensitiveContains(firstWord)
            })
            results.append(contentsOf: Self.commands.filter {
                $0.text.localizedCaseInsensitiveContains(firstWord)
            })
        }

        if firstWord == "git" {
            let subcommand = parts.count > 1 && !input.hasSuffix(" ") ? parts[1] : ""
            results.append(contentsOf: Self.gitSubcommands.filter {
                subcommand.isEmpty || $0.displayText.localizedCaseInsensitiveContains(subcommand)
            })
        }

        if shouldSuggestPaths(input: input, token: lastWord) {
            results.append(contentsOf: suggestPaths(prefix: lastWord, workingDirectory: workingDirectory))
        }

        let unique = uniqueItems(results)
        let sorted = unique.sorted { left, right in
            let leftStarts = left.text.localizedCaseInsensitiveHasPrefix(lastWord)
            let rightStarts = right.text.localizedCaseInsensitiveHasPrefix(lastWord)
            if leftStarts != rightStarts { return leftStarts }
            if left.kind != right.kind { return left.kind.sortRank < right.kind.sortRank }
            return left.displayText.localizedCaseInsensitiveCompare(right.displayText) == .orderedAscending
        }

        suggestions = Array(sorted.prefix(10))
        selectedIndex = 0
        isVisible = !suggestions.isEmpty
    }

    func hide() {
        suggestions = []
        selectedIndex = 0
        isVisible = false
    }

    func selectNext() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
    }

    func selectPrevious() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + suggestions.count) % suggestions.count
    }

    func selectedItem() -> CompletionItem? {
        guard suggestions.indices.contains(selectedIndex) else { return nil }
        return suggestions[selectedIndex]
    }

    func applyCompletion(to input: String, item explicitItem: CompletionItem? = nil) -> String {
        guard let item = explicitItem ?? selectedItem() else { return input }
        hide()

        if item.kind == .git {
            return replaceGitSubcommand(in: input, with: item.text)
        }

        return replaceCurrentToken(in: input, with: item.text)
    }

    func addToHistory(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        commandHistory.removeAll { $0.text == trimmed }
        commandHistory.insert(
            CompletionItem(
                text: trimmed,
                displayText: trimmed,
                kind: .history,
                icon: "clock",
                description: "Recent command"
            ),
            at: 0
        )
        commandHistory = Array(commandHistory.prefix(50))
        storedHistory = commandHistory.map(\.text).joined(separator: "\n")
    }

    private func loadHistory() {
        commandHistory = storedHistory
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(50)
            .map {
                CompletionItem(
                    text: $0,
                    displayText: $0,
                    kind: .history,
                    icon: "clock",
                    description: "Recent command"
                )
            }
    }

    private func suggestPaths(prefix: String, workingDirectory: String) -> [CompletionItem] {
        let expanded = expandPath(prefix, workingDirectory: workingDirectory)
        let searchDirectory: String
        let searchPrefix: String
        let displayDirectoryPrefix: String

        if prefix.hasSuffix("/") {
            searchDirectory = expanded
            searchPrefix = ""
            displayDirectoryPrefix = prefix
        } else {
            searchDirectory = (expanded as NSString).deletingLastPathComponent
            searchPrefix = (expanded as NSString).lastPathComponent
            displayDirectoryPrefix = pathDisplayPrefix(for: prefix)
        }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: searchDirectory) else {
            return []
        }

        return contents
            .filter { !$0.hasPrefix(".") && $0.localizedCaseInsensitiveHasPrefix(searchPrefix) }
            .prefix(50)
            .compactMap { entry in
                let fullPath = (searchDirectory as NSString).appendingPathComponent(entry)
                var isDirectory = ObjCBool(false)
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory) else { return nil }
                let suffix = isDirectory.boolValue ? "/" : ""
                let escaped = escapePath(displayDirectoryPrefix + entry + suffix)
                return CompletionItem(
                    text: escaped,
                    displayText: entry + suffix,
                    kind: .path,
                    icon: isDirectory.boolValue ? "folder" : "doc.text",
                    description: isDirectory.boolValue ? "Directory" : "File"
                )
            }
    }

    private func shouldSuggestPaths(input: String, token: String) -> Bool {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if input.hasSuffix(" ") { return true }
        return token.hasPrefix(".") || token.hasPrefix("/") || token.hasPrefix("~") || token.contains("/")
    }

    private func currentToken(in input: String) -> String {
        if input.hasSuffix(" ") || input.hasSuffix("\t") { return "" }
        return input.split(whereSeparator: { $0 == " " || $0 == "\t" }).last.map(String.init) ?? input
    }

    private func replaceCurrentToken(in input: String, with replacement: String) -> String {
        guard let range = input.rangeOfCharacter(from: .whitespacesAndNewlines, options: .backwards) else {
            return replacement + trailingSpace(for: replacement)
        }
        let prefix = input[..<range.upperBound]
        return String(prefix) + replacement + trailingSpace(for: replacement)
    }

    private func replaceGitSubcommand(in input: String, with replacement: String) -> String {
        var parts = input.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        if parts.count <= 1 {
            return "git \(replacement) "
        }
        parts[1] = replacement
        return parts.joined(separator: " ") + trailingSpace(for: replacement)
    }

    private func trailingSpace(for text: String) -> String {
        text.hasSuffix("/") ? "" : " "
    }

    private func expandPath(_ prefix: String, workingDirectory: String) -> String {
        if prefix.hasPrefix("~") {
            let home = fileManager.homeDirectoryForCurrentUser.path
            return home + String(prefix.dropFirst())
        }
        if prefix.hasPrefix("/") {
            return prefix
        }
        return (workingDirectory as NSString).appendingPathComponent(prefix)
    }

    private func pathDisplayPrefix(for prefix: String) -> String {
        let directory = (prefix as NSString).deletingLastPathComponent
        if directory == "." || directory.isEmpty { return "" }
        return directory + "/"
    }

    private func escapePath(_ path: String) -> String {
        let specialCharacters = CharacterSet(charactersIn: " \t()[]{}'\"\\")
        guard path.rangeOfCharacter(from: specialCharacters) != nil else { return path }
        return path.reduce(into: "") { result, character in
            if String(character).rangeOfCharacter(from: specialCharacters) != nil {
                result.append("\\")
            }
            result.append(character)
        }
    }

    private func uniqueItems(_ items: [CompletionItem]) -> [CompletionItem] {
        var seen = Set<String>()
        return items.filter { item in
            let key = "\(item.kind.rawValue):\(item.text)"
            return seen.insert(key).inserted
        }
    }

    private static let commands: [CompletionItem] = [
        .init(text: "ls", displayText: "ls", kind: .command, icon: "terminal", description: "List directory contents"),
        .init(text: "cd", displayText: "cd", kind: .command, icon: "folder", description: "Change directory"),
        .init(text: "pwd", displayText: "pwd", kind: .command, icon: "mappin", description: "Print working directory"),
        .init(text: "cat", displayText: "cat", kind: .command, icon: "doc.text", description: "Print file contents"),
        .init(text: "grep", displayText: "grep", kind: .command, icon: "magnifyingglass", description: "Search text patterns"),
        .init(text: "find", displayText: "find", kind: .command, icon: "magnifyingglass", description: "Find files"),
        .init(text: "git", displayText: "git", kind: .command, icon: "arrow.branch", description: "Git version control"),
        .init(text: "npm", displayText: "npm", kind: .command, icon: "cube", description: "Node package manager"),
        .init(text: "yarn", displayText: "yarn", kind: .command, icon: "cube", description: "Yarn package manager"),
        .init(text: "pnpm", displayText: "pnpm", kind: .command, icon: "cube", description: "PNPM package manager"),
        .init(text: "bun", displayText: "bun", kind: .command, icon: "cube", description: "Bun runtime"),
        .init(text: "swift", displayText: "swift", kind: .command, icon: "swift", description: "Swift toolchain"),
        .init(text: "curl", displayText: "curl", kind: .command, icon: "network", description: "Transfer data"),
        .init(text: "wget", displayText: "wget", kind: .command, icon: "network", description: "Download files"),
        .init(text: "tar", displayText: "tar", kind: .command, icon: "doc.zipper", description: "Archive files"),
        .init(text: "zip", displayText: "zip", kind: .command, icon: "doc.zipper", description: "Create zip archive"),
        .init(text: "unzip", displayText: "unzip", kind: .command, icon: "doc.zipper", description: "Extract zip archive"),
        .init(text: "chmod", displayText: "chmod", kind: .command, icon: "lock", description: "Change permissions"),
        .init(text: "chown", displayText: "chown", kind: .command, icon: "lock", description: "Change ownership"),
        .init(text: "mkdir", displayText: "mkdir", kind: .command, icon: "folder.badge.plus", description: "Create directory"),
        .init(text: "rm", displayText: "rm", kind: .command, icon: "trash", description: "Remove files"),
        .init(text: "cp", displayText: "cp", kind: .command, icon: "doc.on.doc", description: "Copy files"),
        .init(text: "mv", displayText: "mv", kind: .command, icon: "arrow.right", description: "Move or rename files"),
        .init(text: "touch", displayText: "touch", kind: .command, icon: "hand.tap", description: "Create or update file"),
        .init(text: "head", displayText: "head", kind: .command, icon: "text.alignleft", description: "Read first lines"),
        .init(text: "tail", displayText: "tail", kind: .command, icon: "text.alignleft", description: "Read last lines"),
        .init(text: "less", displayText: "less", kind: .command, icon: "text.alignleft", description: "Page through text"),
        .init(text: "more", displayText: "more", kind: .command, icon: "text.alignleft", description: "Page through text")
    ]

    private static let gitSubcommands: [CompletionItem] = [
        .init(text: "status", displayText: "status", kind: .git, icon: "info.circle", description: "Show working tree status"),
        .init(text: "log", displayText: "log", kind: .git, icon: "clock", description: "Show commit history"),
        .init(text: "diff", displayText: "diff", kind: .git, icon: "plusminus", description: "Show changes"),
        .init(text: "add", displayText: "add", kind: .git, icon: "plus", description: "Stage changes"),
        .init(text: "commit", displayText: "commit", kind: .git, icon: "checkmark", description: "Record changes"),
        .init(text: "push", displayText: "push", kind: .git, icon: "arrow.up", description: "Push commits"),
        .init(text: "pull", displayText: "pull", kind: .git, icon: "arrow.down", description: "Fetch and merge"),
        .init(text: "fetch", displayText: "fetch", kind: .git, icon: "arrow.down", description: "Fetch refs"),
        .init(text: "branch", displayText: "branch", kind: .git, icon: "arrow.branch", description: "List or create branches"),
        .init(text: "checkout", displayText: "checkout", kind: .git, icon: "arrow.right", description: "Switch branches"),
        .init(text: "merge", displayText: "merge", kind: .git, icon: "arrow.triangle.merge", description: "Merge branches"),
        .init(text: "rebase", displayText: "rebase", kind: .git, icon: "arrow.triangle.branch", description: "Reapply commits"),
        .init(text: "clone", displayText: "clone", kind: .git, icon: "doc.on.doc", description: "Clone repository"),
        .init(text: "reset", displayText: "reset", kind: .git, icon: "arrow.uturn.left", description: "Reset state"),
        .init(text: "stash", displayText: "stash", kind: .git, icon: "tray", description: "Stash changes")
    ]
}

private extension CompletionKind {
    var sortRank: Int {
        switch self {
        case .history: return 0
        case .command: return 1
        case .git: return 2
        case .path: return 3
        }
    }
}

private extension String {
    func localizedCaseInsensitiveHasPrefix(_ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        return range(of: prefix, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
    }
}
