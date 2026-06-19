import Foundation
import AppKit
import SwiftUI

struct TerminalTheme: Identifiable, Equatable, Codable {
    let id: String
    let displayName: String
    let background: String
    let foreground: String
    let blockBackground: String
    let accent: String
    let success: String
    let warning: String
    let failure: String
}

enum ThemeRegistry {
    static let themes: [TerminalTheme] = [
        .init(id: "dark", displayName: "Warp Dark", background: "#1E1E1E", foreground: "#ECEFF4", blockBackground: "#252629", accent: "#0A84FF", success: "#34C759", warning: "#FFD60A", failure: "#FF453A"),
        .init(id: "gruvbox-light", displayName: "Gruvbox Light", background: "#FBF1C7", foreground: "#3C3836", blockBackground: "#F2E5BC", accent: "#458588", success: "#98971A", warning: "#D79921", failure: "#CC241D"),
        .init(id: "cyber-wave", displayName: "Cyber Wave", background: "#0D1021", foreground: "#E8F0FF", blockBackground: "#151A33", accent: "#00F6ED", success: "#22C55E", warning: "#F59E0B", failure: "#FF6B9D"),
        .init(id: "jelly-fish", displayName: "Jelly Fish", background: "#102A43", foreground: "#D9E2EC", blockBackground: "#183B56", accent: "#62B6CB", success: "#8AC926", warning: "#FFCA3A", failure: "#FF595E"),
        .init(id: "koi", displayName: "Koi", background: "#FFF7ED", foreground: "#431407", blockBackground: "#FFE8CC", accent: "#EA580C", success: "#16A34A", warning: "#CA8A04", failure: "#DC2626"),
        .init(id: "marble", displayName: "Marble", background: "#F8FAFC", foreground: "#0F172A", blockBackground: "#EEF2F7", accent: "#64748B", success: "#15803D", warning: "#A16207", failure: "#B91C1C"),
        .init(id: "pink-city", displayName: "Pink City", background: "#271526", foreground: "#FFE4F3", blockBackground: "#341B32", accent: "#FF69B4", success: "#34D399", warning: "#FBBF24", failure: "#FB7185"),
        .init(id: "red-rock", displayName: "Red Rock", background: "#2C1410", foreground: "#FFD4C7", blockBackground: "#3A1C15", accent: "#FF6347", success: "#84CC16", warning: "#EAB308", failure: "#F43F5E"),
        .init(id: "willow-dream", displayName: "Willow Dream", background: "#0F1F17", foreground: "#DFF7E8", blockBackground: "#162A20", accent: "#66BB6A", success: "#86EFAC", warning: "#FDE68A", failure: "#FDA4AF"),
        .init(id: "solar-flare", displayName: "Solar Flare", background: "#211A0A", foreground: "#FFF7CC", blockBackground: "#2F250F", accent: "#F59E0B", success: "#A3E635", warning: "#F97316", failure: "#EF4444"),
        .init(id: "dark-city", displayName: "Dark City", background: "#0D1117", foreground: "#C9D1D9", blockBackground: "#161B22", accent: "#58A6FF", success: "#3FB950", warning: "#D29922", failure: "#F85149"),
        .init(id: "adeberry", displayName: "Adeberry", background: "#18122B", foreground: "#F7EFE5", blockBackground: "#211A38", accent: "#A084DC", success: "#7DD87D", warning: "#FFD372", failure: "#FF6B6B"),
        .init(id: "phenomenon", displayName: "Phenomenon", background: "#061A23", foreground: "#E0FBFC", blockBackground: "#0B2733", accent: "#3D5A80", success: "#98C1D9", warning: "#EE6C4D", failure: "#E63946"),
        .init(id: "midnight", displayName: "Midnight", background: "#020617", foreground: "#E2E8F0", blockBackground: "#0F172A", accent: "#38BDF8", success: "#22C55E", warning: "#FACC15", failure: "#FB7185"),
        .init(id: "paper", displayName: "Paper", background: "#FFFBEB", foreground: "#292524", blockBackground: "#F8F0D6", accent: "#2563EB", success: "#15803D", warning: "#B45309", failure: "#B91C1C"),
        .init(id: "nord", displayName: "Nord", background: "#2E3440", foreground: "#D8DEE9", blockBackground: "#3B4252", accent: "#88C0D0", success: "#A3BE8C", warning: "#EBCB8B", failure: "#BF616A"),
        .init(id: "dracula", displayName: "Dracula", background: "#282A36", foreground: "#F8F8F2", blockBackground: "#343746", accent: "#BD93F9", success: "#50FA7B", warning: "#F1FA8C", failure: "#FF5555"),
        .init(id: "monokai", displayName: "Monokai", background: "#272822", foreground: "#F8F8F2", blockBackground: "#33342D", accent: "#66D9EF", success: "#A6E22E", warning: "#E6DB74", failure: "#F92672"),
        .init(id: "tokyo-night", displayName: "Tokyo Night", background: "#1A1B26", foreground: "#C0CAF5", blockBackground: "#24283B", accent: "#7AA2F7", success: "#9ECE6A", warning: "#E0AF68", failure: "#F7768E"),
        .init(id: "rose-pine", displayName: "Rosé Pine", background: "#191724", foreground: "#E0DEF4", blockBackground: "#26233A", accent: "#C4A7E7", success: "#31748F", warning: "#F6C177", failure: "#EB6F92"),
        .init(id: "catppuccin", displayName: "Catppuccin", background: "#1E1E2E", foreground: "#CDD6F4", blockBackground: "#313244", accent: "#89B4FA", success: "#A6E3A1", warning: "#F9E2AF", failure: "#F38BA8")
    ]

    static func theme(id: String) -> TerminalTheme {
        themes.first { $0.id == id } ?? themes[0]
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: sanitized)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    static var separator: Color {
        Color(nsColor: .separatorColor)
    }

    static var secondarySystemFill: Color {
        Color(nsColor: NSColor.controlBackgroundColor)
    }
}
