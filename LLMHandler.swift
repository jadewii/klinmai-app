import Foundation

@MainActor
class LLMHandler: ObservableObject {
    @Published var isProcessing = false
    @Published var lastError: String?
    
    // Configuration for local LLM
    private let modelPath = "/usr/local/models/mistral-7b" // Adjust based on actual setup
    private let ollamaURL = "http://localhost:11434/api/generate" // For Ollama integration
    
    func processCommand(_ input: String) async -> CleanAction? {
        isProcessing = true
        defer { isProcessing = false }
        
        // For now, use pattern matching. In production, this would call the local LLM
        let lowercased = input.lowercased()
        
        // Pattern matching for common commands
        if lowercased.contains("clean") && lowercased.contains("desktop") {
            return CleanAction(
                type: .cleanDesktop,
                description: "Clean and organize Desktop",
                parameters: [:]
            )
        }
        
        if lowercased.contains("clean") && lowercased.contains("downloads") {
            return CleanAction(
                type: .cleanDownloads,
                description: "Clean and organize Downloads",
                parameters: [:]
            )
        }
        
        if lowercased.contains("remove") && lowercased.contains("duplicate") {
            return CleanAction(
                type: .removeDuplicates,
                description: "Find and remove duplicate files",
                parameters: [:]
            )
        }
        
        if lowercased.contains("clean") && (lowercased.contains("system") || lowercased.contains("junk")) {
            return CleanAction(
                type: .cleanSystem,
                description: "Clean system junk and caches",
                parameters: [:]
            )
        }
        
        if lowercased.contains("archive") {
            // Extract months if specified
            var months = 6
            if let match = lowercased.range(of: #"(\d+)\s*month"#, options: .regularExpression) {
                let numberStr = String(lowercased[match]).components(separatedBy: " ")[0]
                months = Int(numberStr) ?? 6
            }
            
            return CleanAction(
                type: .archiveOldFiles,
                description: "Archive files older than \(months) months",
                parameters: ["months": months]
            )
        }
        
        if lowercased.contains("clean") && (lowercased.contains("everything") || lowercased.contains("all") || lowercased.contains("mac")) {
            return CleanAction(
                type: .custom,
                description: "Run full Smart Care scan",
                parameters: ["fullScan": true]
            )
        }
        
        // In production, this would make an actual LLM call
        // For now, return a custom action for unmatched commands
        return CleanAction(
            type: .custom,
            description: "Process: \(input)",
            parameters: ["rawCommand": input]
        )
    }
    
    // This would be the actual LLM integration in production
    private func callLocalLLM(_ prompt: String) async -> String? {
        // Example structure for Ollama API call
        let _ = """
        You are Klinmai, an AI assistant for Mac cleaning tasks.
        Parse the user's request and return a JSON action.
        Available actions: cleanDesktop, cleanDownloads, removeDuplicates, cleanSystem, archiveOldFiles
        Return format: {"action": "actionName", "parameters": {}}
        """
        
        // In production, this would make an HTTP request to the local LLM
        // For now, return nil to fall back to pattern matching
        return nil
    }
}