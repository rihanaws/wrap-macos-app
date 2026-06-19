import Foundation

final class GitService: ObservableObject {
    @Published var changedFiles: [GitChangedFile] = []
    @Published var currentBranch: String = "unknown"
    @Published var selectedDiff: String = ""
    @Published var lastError: String?

    func refresh(repositoryPath: String) {
        do {
            currentBranch = try runGit(["rev-parse", "--abbrev-ref", "HEAD"], cwd: repositoryPath)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            changedFiles = try parseStatus(runGit(["status", "--porcelain=v1"], cwd: repositoryPath))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func loadDiff(repositoryPath: String, filePath: String, staged: Bool = false) {
        do {
            var arguments = ["diff"]
            if staged { arguments.append("--staged") }
            arguments.append("--")
            arguments.append(filePath)
            selectedDiff = try runGit(arguments, cwd: repositoryPath)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func parseStatus(_ output: String) throws -> [GitChangedFile] {
        output
            .split(separator: "\n")
            .compactMap { line in
                guard line.count >= 4 else { return nil }
                let stagedStatus = String(line.prefix(1))
                let unstagedStatus = String(line.dropFirst().prefix(1))
                let path = String(line.dropFirst(3))
                let status = stagedStatus == " " ? unstagedStatus : stagedStatus
                return GitChangedFile(path: path, status: status, staged: stagedStatus != " ")
            }
    }

    @discardableResult
    func runGit(_ arguments: [String], cwd: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()
        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        let errorData = error.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let message = String(data: errorData, encoding: .utf8) ?? "git failed"
            throw NSError(domain: "WarpClone.GitService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
