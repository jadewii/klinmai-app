import Foundation

class UndoManager {
    private let undoFileURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("DesktopCleaner", isDirectory: true)
        
        // Create app support folder if needed
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        undoFileURL = appFolder.appendingPathComponent("last_clean.json")
    }
    
    func saveCleanInfo(_ cleanInfo: CleanInfo) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(cleanInfo)
            try data.write(to: undoFileURL)
        } catch {
            print("Failed to save undo info: \(error)")
        }
    }
    
    func getLastClean() -> CleanInfo? {
        guard FileManager.default.fileExists(atPath: undoFileURL.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: undoFileURL)
            return try JSONDecoder().decode(CleanInfo.self, from: data)
        } catch {
            print("Failed to load undo info: \(error)")
            return nil
        }
    }
    
    func clearLastClean() {
        try? FileManager.default.removeItem(at: undoFileURL)
    }
    
    func canUndo() -> Bool {
        return getLastClean() != nil
    }
}