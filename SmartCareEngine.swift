import Foundation
import SwiftUI

@MainActor
class SmartCareEngine: ObservableObject {
    @Published var consoleOutput: [ConsoleEntry] = []
    @Published var isRunning = false
    @Published var totalActionsPerformed = 0
    @Published var spaceSaved: Int64 = 0
    
    private let fileOrganizer = FileOrganizer()
    private let duplicateScanner = DuplicateScanner()
    private let systemCleaner = SystemCleaner()
    private let mailAndTrashCleaner = MailAndTrashCleaner()
    
    func runFullScan() async {
        isRunning = true
        totalActionsPerformed = 0
        spaceSaved = 0
        
        log("🚀 Starting Smart Care scan...", type: .info)
        log("💖 Hi! I'm Klinmai! Let's make your Mac sparkle clean!", type: .info)
        
        // Clean Desktop
        log("📁 Scanning Desktop...", type: .progress)
        let desktopResults = await fileOrganizer.cleanDesktop()
        totalActionsPerformed += desktopResults.filesOrganized
        
        if desktopResults.filesOrganized > 0 {
            log("✅ Desktop tidied up! Organized \(desktopResults.filesOrganized) files into neat folders", type: .success)
            if desktopResults.filesOrganized > 50 {
                log("💡 Wow, that was a lot of files! Consider using Desktop Stacks (right-click → Use Stacks)", type: .info)
            }
        } else {
            log("✨ Desktop already spotless — nice work staying organized!", type: .success)
            log("💡 Tip: I found \(desktopResults.filesScanned) files already in folders. You're doing great!", type: .info)
        }
        
        // Clean Downloads
        log("📥 Scanning Downloads folder...", type: .progress)
        let downloadsResults = await fileOrganizer.cleanDownloads()
        totalActionsPerformed += downloadsResults.filesOrganized
        
        if downloadsResults.filesOrganized > 0 {
            log("✅ Downloads organized: \(downloadsResults.filesOrganized) files sorted by type", type: .success)
            if let oldestFile = downloadsResults.oldestFileDate {
                let daysOld = Calendar.current.dateComponents([.day], from: oldestFile, to: Date()).day ?? 0
                if daysOld > 90 {
                    log("💡 Found files from \(daysOld) days ago! Consider archiving old downloads", type: .warning)
                }
            }
        } else {
            log("✨ Downloads folder is empty or already organized — you're on top of things!", type: .success)
        }
        
        // Find and remove duplicates
        log("🔍 Hunting for duplicate files across your Mac...", type: .progress)
        let duplicateResults = await duplicateScanner.findAndRemoveDuplicates()
        totalActionsPerformed += duplicateResults.duplicatesRemoved
        spaceSaved += duplicateResults.spaceSaved
        
        if duplicateResults.duplicatesRemoved > 0 {
            log("✅ Found and removed \(duplicateResults.duplicatesRemoved) duplicates!", type: .success)
            log("💰 Recovered \(formatBytes(duplicateResults.spaceSaved)) of precious disk space", type: .success)
            if duplicateResults.largestDuplicate != nil {
                log("💡 Biggest duplicate was \(formatBytes(duplicateResults.largestDuplicate!)) — that's like deleting a whole movie!", type: .info)
            }
        } else {
            log("✨ No duplicates found — your files are already unique!", type: .success)
        }
        
        // Clean system junk
        log("🗑 Deep cleaning system caches and temporary files...", type: .progress)
        let junkResults = await systemCleaner.cleanSystemJunk()
        totalActionsPerformed += junkResults.filesRemoved
        spaceSaved += junkResults.spaceSaved
        
        if junkResults.filesRemoved > 0 {
            log("✅ Cleaned \(junkResults.filesRemoved) junk files", type: .success)
            log("💾 Freed up \(formatBytes(junkResults.spaceSaved)) of system space", type: .success)
            let percentOfTotal = Int((Double(junkResults.spaceSaved) / Double(getDiskSize() ?? 1)) * 100)
            if percentOfTotal > 1 {
                log("📊 That's \(percentOfTotal)% of your total disk space!", type: .info)
            }
        } else {
            log("✨ System caches are minimal — your Mac is running lean!", type: .success)
        }
        
        // Empty trash
        log("♻️ Checking trash bins...", type: .progress)
        let trashResults = await mailAndTrashCleaner.emptyAllTrash()
        spaceSaved += trashResults.spaceSaved
        
        if trashResults.spaceSaved > 0 {
            log("✅ Emptied trash and recovered \(formatBytes(trashResults.spaceSaved))", type: .success)
        } else {
            log("✨ Trash is already empty — nothing to clean here!", type: .success)
            log("💡 Pro tip: Empty trash regularly with ⌘+⇧+⌫", type: .info)
        }
        
        // Smart Summary
        log("", type: .info) // Blank line for separation
        log("🎉 Smart Care Complete! Here's what happened:", type: .success)
        
        if totalActionsPerformed > 0 {
            log("💖 I organized and cleaned \(totalActionsPerformed) items for you!", type: .info)
            log("💾 Total space recovered: \(formatBytes(spaceSaved))", type: .info)
            
            // Context for space saved
            if spaceSaved > 1_000_000_000 { // More than 1GB
                let movies = Int(spaceSaved / 1_500_000_000)
                log("🎬 That's like deleting \(movies) HD movies!", type: .info)
            } else if spaceSaved > 100_000_000 { // More than 100MB
                let songs = Int(spaceSaved / 4_000_000)
                log("🎵 That's about \(songs) songs worth of space!", type: .info)
            }
            
            // Suggestions based on results
            if duplicateResults.duplicatesRemoved == 0 && totalActionsPerformed < 10 {
                log("💡 Suggestion: Run a deep scan for large old files (coming soon!)", type: .info)
            }
        } else {
            log("✨ Your Mac is already squeaky clean! No action needed", type: .success)
            log("💖 I checked everything and you're doing a great job staying organized!", type: .info)
            log("💡 Come back in a week for your next cleanup!", type: .info)
        }
        
        isRunning = false
    }
    
    func executeAction(_ action: CleanAction) async {
        isRunning = true
        
        switch action.type {
        case .cleanDesktop:
            let results = await fileOrganizer.cleanDesktop()
            log("✅ Desktop cleaned: \(results.filesOrganized) files organized", type: .success)
            
        case .cleanDownloads:
            let results = await fileOrganizer.cleanDownloads()
            log("✅ Downloads cleaned: \(results.filesOrganized) files organized", type: .success)
            
        case .removeDuplicates:
            let results = await duplicateScanner.findAndRemoveDuplicates()
            log("✅ Removed \(results.duplicatesRemoved) duplicates", type: .success)
            
        case .cleanSystem:
            let results = await systemCleaner.cleanSystemJunk()
            log("✅ Cleaned system: \(formatBytes(results.spaceSaved)) freed", type: .success)
            
        case .archiveOldFiles:
            let results = await fileOrganizer.archiveOldFiles(olderThanMonths: action.parameters["months"] as? Int ?? 6)
            log("✅ Archived \(results.filesArchived) old files", type: .success)
            
        case .custom:
            log("⚡ Executing custom action: \(action.description)", type: .info)
            // Handle custom actions based on parameters
        }
        
        isRunning = false
    }
    
    private func log(_ message: String, type: ConsoleEntryType) {
        let entry = ConsoleEntry(
            timestamp: Date(),
            message: message,
            type: type
        )
        consoleOutput.append(entry)
        
        // Keep console output manageable
        if consoleOutput.count > 1000 {
            consoleOutput.removeFirst(consoleOutput.count - 1000)
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func getDiskSize() -> Int64? {
        let fileManager = FileManager.default
        do {
            let attributes = try fileManager.attributesOfFileSystem(forPath: "/")
            return attributes[.systemSize] as? Int64
        } catch {
            return nil
        }
    }
    
    // Quick action methods
    func cleanDesktop() async {
        log("📁 Organizing Desktop...", type: .progress)
        let results = await fileOrganizer.cleanDesktop()
        if results.filesOrganized > 0 {
            log("✅ Desktop organized: \(results.filesOrganized) files", type: .success)
        } else {
            log("✨ Desktop already organized!", type: .success)
        }
    }
    
    func cleanDownloads() async {
        log("📥 Organizing Downloads...", type: .progress)
        let results = await fileOrganizer.cleanDownloads()
        if results.filesOrganized > 0 {
            log("✅ Downloads organized: \(results.filesOrganized) files", type: .success)
        } else {
            log("✨ Downloads already organized!", type: .success)
        }
    }
    
    func findDuplicates() async {
        log("🔍 Scanning for duplicates...", type: .progress)
        let results = await duplicateScanner.findAndRemoveDuplicates()
        if results.duplicatesRemoved > 0 {
            log("✅ Removed \(results.duplicatesRemoved) duplicates, saved \(formatBytes(results.spaceSaved))", type: .success)
        } else {
            log("✨ No duplicates found!", type: .success)
        }
    }
    
    func cleanSystem() async {
        log("🗑 Cleaning system junk...", type: .progress)
        let results = await systemCleaner.cleanSystemJunk()
        if results.filesRemoved > 0 {
            log("✅ Cleaned \(results.filesRemoved) junk files, saved \(formatBytes(results.spaceSaved))", type: .success)
        } else {
            log("✨ System is already clean!", type: .success)
        }
    }
}

struct ConsoleEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: ConsoleEntryType
}

enum ConsoleEntryType {
    case info
    case success
    case warning
    case error
    case progress
    
    var color: Color {
        switch self {
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        case .progress: return .blue
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .progress: return "arrow.clockwise"
        }
    }
}

struct CleanAction {
    let type: CleanActionType
    let description: String
    let parameters: [String: Any]
}

enum CleanActionType {
    case cleanDesktop
    case cleanDownloads
    case removeDuplicates
    case cleanSystem
    case archiveOldFiles
    case custom
}