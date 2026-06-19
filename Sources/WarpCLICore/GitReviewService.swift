import Foundation

public struct GitStatusSummary: Equatable {
    public var branch: String
    public var files: [GitChangedFile]

    public init(branch: String, files: [GitChangedFile]) {
        self.branch = branch
        self.files = files
    }
}

public struct GitChangedFile: Equatable, Identifiable {
    public var id: String { path }
    public var path: String
    public var indexStatus: String
    public var workTreeStatus: String

    public init(path: String, indexStatus: String, workTreeStatus: String) {
        self.path = path
        self.indexStatus = indexStatus
        self.workTreeStatus = workTreeStatus
    }
}

public final class GitReviewService {
    public var repositoryPath: String

    public init(repositoryPath: String = FileManager.default.currentDirectoryPath) {
        self.repositoryPath = repositoryPath
    }

    public func status() throws -> GitStatusSummary {
        try Self.parseStatus(runGit(["status", "--porcelain=v1", "--branch"]))
    }

    public func diff(staged: Bool = false, branch: String? = nil, path: String? = nil) throws -> String {
        var args = ["diff"]
        if staged {
            args.append("--staged")
        }
        if let branch {
            args.append(branch)
        }
        if let path {
            args.append(contentsOf: ["--", path])
        }
        return try runGit(args)
    }

    public func reviewPrompt(staged: Bool = false, branch: String? = nil, path: String? = nil) throws -> String {
        let status = try status()
        let diff = try diff(staged: staged, branch: branch, path: path)
        return """
        Review the following git changes for correctness, security, regressions, and missing tests.

        Branch: \(status.branch)
        Files:
        \(status.files.map { "- \($0.indexStatus)\($0.workTreeStatus) \($0.path)" }.joined(separator: "\n"))

        Diff:
        \(diff)
        """
    }

    public static func parseStatus(_ output: String) -> GitStatusSummary {
        var branch = "unknown"
        var files: [GitChangedFile] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.hasPrefix("## ") {
                let rawBranch = String(line.dropFirst(3))
                branch = rawBranch.components(separatedBy: "...").first ?? rawBranch
                continue
            }
            guard line.count >= 4 else {
                continue
            }

            let index = String(line[line.startIndex])
            let workTree = String(line[line.index(after: line.startIndex)])
            let pathStart = line.index(line.startIndex, offsetBy: 3)
            files.append(GitChangedFile(path: String(line[pathStart...]), indexStatus: index, workTreeStatus: workTree))
        }

        return GitStatusSummary(branch: branch, files: files)
    }

    private func runGit(_ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: repositoryPath)

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        try process.run()
        process.waitUntilExit()

        let outputData = output.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus == 0 {
            return String(data: outputData, encoding: .utf8) ?? ""
        }

        let errorText = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "git failed"
        throw GitReviewError.gitFailed(arguments, errorText)
    }
}

public enum GitReviewError: Error, LocalizedError {
    case gitFailed([String], String)

    public var errorDescription: String? {
        switch self {
        case .gitFailed(let args, let message):
            "`git \(args.joined(separator: " "))` failed: \(message)"
        }
    }
}
