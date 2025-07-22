import Foundation
import AppKit

struct GitHubRepo: Identifiable {
    let id = UUID()
    let name: String
    let fullName: String  // owner/repo
    let description: String?
    let url: URL
    let isPrivate: Bool
    let defaultBranch: String
    let localPath: URL?
    let hasUnpushedChanges: Bool
    let lastUpdated: Date?
    
    var owner: String {
        fullName.split(separator: "/").first.map(String.init) ?? ""
    }
}

struct GitHubUser {
    let username: String
    let name: String?
    let avatarURL: URL?
}

@MainActor
class GitHubIntegration: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: GitHubUser?
    @Published var repositories: [GitHubRepo] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    
    // Check if gh CLI is installed and authenticated
    func checkAuthentication() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Check gh auth status
            let result = try await runGitHubCommand(["auth", "status"])
            isAuthenticated = result.contains("Logged in")
            
            if isAuthenticated {
                await fetchUserInfo()
                await fetchRepositories()
            }
        } catch {
            isAuthenticated = false
            errorMessage = "GitHub CLI not authenticated. Run 'gh auth login' in Terminal."
        }
        
        isLoading = false
    }
    
    // Authenticate with GitHub
    func authenticate() async {
        // Open gh auth in terminal
        NSWorkspace.shared.open(URL(string: "x-man-page://gh-auth-login")!)
        
        // Alternative: Open GitHub device flow
        if let url = URL(string: "https://github.com/login/device") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // Fetch current user info
    private func fetchUserInfo() async {
        do {
            let result = try await runGitHubCommand(["api", "user", "--jq", ".login,.name,.avatar_url"])
            let lines = result.split(separator: "\n")
            if lines.count >= 2 {
                currentUser = GitHubUser(
                    username: String(lines[0]),
                    name: lines.count > 1 ? String(lines[1]) : nil,
                    avatarURL: lines.count > 2 ? URL(string: String(lines[2])) : nil
                )
            }
        } catch {
            print("Failed to fetch user info: \(error)")
        }
    }
    
    // Fetch user's repositories
    func fetchRepositories() async {
        isLoading = true
        
        do {
            // Fetch repos with gh CLI
            let result = try await runGitHubCommand([
                "repo", "list", "--limit", "100", "--json",
                "name,nameWithOwner,description,url,isPrivate,defaultBranchRef"
            ])
            
            if let data = result.data(using: .utf8) {
                let decoder = JSONDecoder()
                let repos = try decoder.decode([GitHubRepoResponse].self, from: data)
                
                // Convert to our model and check for local paths
                repositories = await withTaskGroup(of: GitHubRepo?.self) { group in
                    for repo in repos {
                        group.addTask {
                            await self.createGitHubRepo(from: repo)
                        }
                    }
                    
                    var result: [GitHubRepo] = []
                    for await repo in group {
                        if let repo = repo {
                            result.append(repo)
                        }
                    }
                    return result.sorted { $0.name < $1.name }
                }
            }
        } catch {
            errorMessage = "Failed to fetch repositories: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // Convert API response to our model
    private func createGitHubRepo(from response: GitHubRepoResponse) async -> GitHubRepo? {
        guard let url = URL(string: response.url) else { return nil }
        
        // Check if repo exists locally
        let localPath = await findLocalRepo(named: response.name)
        let hasUnpushedChanges = await checkUnpushedChanges(at: localPath)
        
        return GitHubRepo(
            name: response.name,
            fullName: response.nameWithOwner,
            description: response.description,
            url: url,
            isPrivate: response.isPrivate,
            defaultBranch: response.defaultBranchRef?.name ?? "main",
            localPath: localPath,
            hasUnpushedChanges: hasUnpushedChanges,
            lastUpdated: nil
        )
    }
    
    // Find local clone of a repo
    private func findLocalRepo(named name: String) async -> URL? {
        let searchPaths = [
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Developer"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Projects"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Dev"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Dev"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents/Projects"),
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        
        for path in searchPaths {
            let repoPath = path.appendingPathComponent(name)
            if fileManager.fileExists(atPath: repoPath.path) {
                // Check if it's a git repo
                let gitPath = repoPath.appendingPathComponent(".git")
                if fileManager.fileExists(atPath: gitPath.path) {
                    return repoPath
                }
            }
        }
        
        return nil
    }
    
    // Check for unpushed changes
    private func checkUnpushedChanges(at path: URL?) async -> Bool {
        guard let path = path else { return false }
        
        do {
            let result = try await runCommand("git", arguments: ["-C", path.path, "status", "--porcelain"])
            return !result.isEmpty
        } catch {
            return false
        }
    }
    
    // Create a new repository
    func createRepository(name: String, description: String?, isPrivate: Bool) async throws {
        var args = ["repo", "create", name]
        
        if let desc = description {
            args.append("--description")
            args.append(desc)
        }
        
        if isPrivate {
            args.append("--private")
        } else {
            args.append("--public")
        }
        
        _ = try await runGitHubCommand(args)
        await fetchRepositories()
    }
    
    // Clone a repository
    func cloneRepository(_ repo: GitHubRepo, to directory: URL) async throws {
        let clonePath = directory.appendingPathComponent(repo.name)
        _ = try await runGitHubCommand(["repo", "clone", repo.fullName, clonePath.path])
    }
    
    // Push files to repository
    func pushFilesToRepo(_ files: [URL], repo: GitHubRepo, commitMessage: String) async throws {
        guard let localPath = repo.localPath else {
            throw GitHubError.repoNotClonedLocally
        }
        
        // Copy files to repo
        for file in files {
            let destination = localPath.appendingPathComponent(file.lastPathComponent)
            try fileManager.copyItem(at: file, to: destination)
        }
        
        // Git add, commit, and push
        try await runCommand("git", arguments: ["-C", localPath.path, "add", "."])
        try await runCommand("git", arguments: ["-C", localPath.path, "commit", "-m", commitMessage])
        try await runCommand("git", arguments: ["-C", localPath.path, "push"])
    }
    
    // Initialize a folder as a GitHub repo
    func initializeAndPushFolder(_ folderURL: URL, repoName: String, isPrivate: Bool) async throws {
        // Initialize git repo
        try await runCommand("git", arguments: ["-C", folderURL.path, "init"])
        
        // Create GitHub repo
        try await createRepository(name: repoName, description: "Created by Klinmai", isPrivate: isPrivate)
        
        // Add remote
        let remoteURL = "https://github.com/\(currentUser?.username ?? "")/\(repoName).git"
        try await runCommand("git", arguments: ["-C", folderURL.path, "remote", "add", "origin", remoteURL])
        
        // Initial commit and push
        try await runCommand("git", arguments: ["-C", folderURL.path, "add", "."])
        try await runCommand("git", arguments: ["-C", folderURL.path, "commit", "-m", "Initial commit from Klinmai"])
        try await runCommand("git", arguments: ["-C", folderURL.path, "push", "-u", "origin", "main"])
    }
    
    // Run GitHub CLI command
    private func runGitHubCommand(_ arguments: [String]) async throws -> String {
        return try await runCommand("gh", arguments: arguments)
    }
    
    // Run shell command
    private func runCommand(_ command: String, arguments: [String]) async throws -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = [command] + arguments
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if task.terminationStatus != 0 {
            throw GitHubError.commandFailed(output)
        }
        
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// GitHub API Response Models
struct GitHubRepoResponse: Codable {
    let name: String
    let nameWithOwner: String
    let description: String?
    let url: String
    let isPrivate: Bool
    let defaultBranchRef: GitHubBranchRef?
}

struct GitHubBranchRef: Codable {
    let name: String
}

enum GitHubError: LocalizedError {
    case notAuthenticated
    case repoNotClonedLocally
    case commandFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with GitHub"
        case .repoNotClonedLocally:
            return "Repository not cloned locally"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        }
    }
}