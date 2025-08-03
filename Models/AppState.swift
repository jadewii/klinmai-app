import SwiftUI
import Foundation

class AppState: ObservableObject {
    @Published var preferences = Preferences()
    @Published var lastCleanInfo: CleanInfo?
    @Published var isShowingPreferences = false
    @Published var isCleaning = false
    
    private let fileOrganizer = FileOrganizer()
    private let undoManager = UndoManager()
    
    init() {
        loadPreferences()
    }
    
    func cleanDesktop() async {
        await MainActor.run {
            self.isCleaning = true
        }
        
        do {
            let cleanInfo = try await fileOrganizer.organizeDesktop(
                using: preferences.sortMode,
                customFolder: nil
            )
            
            await MainActor.run {
                self.lastCleanInfo = cleanInfo
                self.isCleaning = false
                self.savePreferences()
            }
            
            // Save for undo
            undoManager.saveCleanInfo(cleanInfo)
            
        } catch {
            await MainActor.run {
                self.isCleaning = false
            }
            print("Error cleaning desktop: \(error)")
        }
    }
    
    func undoLastClean() async {
        guard let lastClean = undoManager.getLastClean() else { return }
        
        do {
            try await fileOrganizer.undoClean(lastClean)
            await MainActor.run {
                self.lastCleanInfo = nil
            }
            undoManager.clearLastClean()
        } catch {
            print("Error undoing clean: \(error)")
        }
    }
    
    func getTooltipText() -> String {
        if let lastClean = lastCleanInfo {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let timeAgo = formatter.localizedString(for: lastClean.date, relativeTo: Date())
            return "Last cleaned: \(timeAgo)\nFiles moved: \(lastClean.movedFiles.count)"
        }
        return "Desktop Cleaner - Click to organize"
    }
    
    private func loadPreferences() {
        if let data = UserDefaults.standard.data(forKey: "preferences"),
           let decoded = try? JSONDecoder().decode(Preferences.self, from: data) {
            preferences = decoded
        }
    }
    
    func savePreferences() {
        if let encoded = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(encoded, forKey: "preferences")
        }
        NotificationCenter.default.post(name: .preferencesChanged, object: nil)
    }
}

struct Preferences: Codable {
    var sortMode: SortMode = .smart
    var autoCleanEnabled = true
    var autoCleanInterval = 60
    var cleanAtEndOfDay = true
    var endOfDayTime = DateComponents(hour: 0, minute: 0) // 12 AM (midnight)
    var showUndoAfterClean = false
    var pinnedFiles: Set<String> = []
    var hasCompletedSetup = false // Show setup window on first run
    var autoStartAtLogin = true
    var createScreenshotsFolder = false
    var deleteOldScreenshots = false
}

enum SortMode: String, Codable, CaseIterable {
    case smart = "Smart Native"
    
    var icon: String {
        return "brain.head.profile"
    }
    
    var description: String {
        return "Intelligently organizes files to their proper native macOS locations"
    }
}

struct CleanInfo: Codable {
    let date: Date
    let movedFiles: [MovedFile]
}

struct MovedFile: Codable {
    let originalPath: URL
    let newPath: URL
}