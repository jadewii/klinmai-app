import Foundation
import CryptoKit

struct SmartSuggestion: Identifiable {
    let id = UUID()
    let type: SuggestionType
    let title: String
    let description: String
    let action: SuggestionAction
    let affectedFiles: [URL]
    let potentialSaving: Int64?
    
    enum SuggestionType {
        case archive
        case group
        case duplicate
        case projectDetection
        case emptyFile
        case sequence
        
        var icon: String {
            switch self {
            case .archive: return "archivebox"
            case .group: return "folder"
            case .duplicate: return "doc.on.doc"
            case .projectDetection: return "folder.badge.gearshape"
            case .emptyFile: return "doc.text"
            case .sequence: return "square.stack.3d.forward.dottedline"
            }
        }
        
        var color: String {
            switch self {
            case .archive: return "orange"
            case .group: return "blue"
            case .duplicate: return "red"
            case .projectDetection: return "purple"
            case .emptyFile: return "gray"
            case .sequence: return "green"
            }
        }
    }
    
    enum SuggestionAction {
        case archiveFiles
        case groupIntoFolder(name: String)
        case keepNewest
        case moveToProject(name: String)
        case deleteEmpty
        case createSequence(name: String)
    }
}

@MainActor
class SmartCleanManager: ObservableObject {
    @Published var suggestions: [SmartSuggestion] = []
    @Published var isAnalyzing = false
    
    private let fileManager = FileManager.default
    
    // Analyze files and generate smart suggestions
    func analyzeFiles(_ files: [ArchiveCandidate]) async {
        await MainActor.run {
            isAnalyzing = true
            suggestions.removeAll()
        }
        
        var newSuggestions: [SmartSuggestion] = []
        
        // Group files by type for analysis
        let audioFiles = files.filter { $0.type == .audio }
        let imageFiles = files.filter { $0.type == .image }
        let documentFiles = files.filter { $0.type == .document }
        let allFiles = files
        
        // Analyze each type
        if !audioFiles.isEmpty {
            newSuggestions.append(contentsOf: await analyzeAudioFiles(audioFiles))
        }
        
        if !imageFiles.isEmpty {
            newSuggestions.append(contentsOf: await analyzeImageFiles(imageFiles))
        }
        
        if !documentFiles.isEmpty {
            newSuggestions.append(contentsOf: await analyzeDocumentFiles(documentFiles))
        }
        
        // General analysis for all files
        newSuggestions.append(contentsOf: await analyzeGeneralFiles(allFiles))
        
        await MainActor.run {
            suggestions = newSuggestions
            isAnalyzing = false
        }
    }
    
    // MARK: - Audio Analysis
    private func analyzeAudioFiles(_ files: [ArchiveCandidate]) async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Detect sample packs
        let samplePackGroups = detectSamplePacks(files)
        for (packName, packFiles) in samplePackGroups {
            suggestions.append(SmartSuggestion(
                type: .group,
                title: "Sample Pack Detected",
                description: "\(packFiles.count) files that appear to be from '\(packName)' sample pack",
                action: .groupIntoFolder(name: "Sample Pack - \(packName)"),
                affectedFiles: packFiles.map { $0.url },
                potentialSaving: nil
            ))
        }
        
        // Categorize by length
        let oneShots = files.filter { isOneShot($0) }
        if oneShots.count > 5 {
            suggestions.append(SmartSuggestion(
                type: .group,
                title: "One-shot Samples",
                description: "\(oneShots.count) short audio files (<10s) detected",
                action: .groupIntoFolder(name: "One-shots"),
                affectedFiles: oneShots.map { $0.url },
                potentialSaving: nil
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Image Analysis
    private func analyzeImageFiles(_ files: [ArchiveCandidate]) async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Detect sequences
        let sequences = detectImageSequences(files)
        for (baseName, sequenceFiles) in sequences {
            if sequenceFiles.count > 3 {
                suggestions.append(SmartSuggestion(
                    type: .sequence,
                    title: "Image Sequence Found",
                    description: "\(sequenceFiles.count) frames of '\(baseName)' sequence",
                    action: .createSequence(name: baseName),
                    affectedFiles: sequenceFiles.map { $0.url },
                    potentialSaving: nil
                ))
            }
        }
        
        // Detect screenshots
        let screenshots = files.filter { isScreenshot($0) }
        if screenshots.count > 10 {
            let totalSize = screenshots.reduce(0) { $0 + $1.size }
            suggestions.append(SmartSuggestion(
                type: .archive,
                title: "Old Screenshots",
                description: "\(screenshots.count) screenshots taking up \(formatBytes(totalSize))",
                action: .archiveFiles,
                affectedFiles: screenshots.map { $0.url },
                potentialSaving: totalSize
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Document Analysis
    private func analyzeDocumentFiles(_ files: [ArchiveCandidate]) async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Detect duplicates by content hash
        let duplicates = await detectDuplicateDocuments(files)
        for (_, duplicateGroup) in duplicates {
            if duplicateGroup.count > 1 {
                let oldestFile = duplicateGroup.min(by: { $0.lastModified < $1.lastModified })!
                let totalWaste = duplicateGroup.dropFirst().reduce(0) { $0 + $1.size }
                
                suggestions.append(SmartSuggestion(
                    type: .duplicate,
                    title: "Duplicate Documents",
                    description: "\(duplicateGroup.count) copies of '\(oldestFile.url.lastPathComponent)'",
                    action: .keepNewest,
                    affectedFiles: duplicateGroup.map { $0.url },
                    potentialSaving: totalWaste
                ))
            }
        }
        
        // Detect empty documents
        let emptyDocs = files.filter { $0.size < 100 } // Less than 100 bytes
        if !emptyDocs.isEmpty {
            suggestions.append(SmartSuggestion(
                type: .emptyFile,
                title: "Empty Documents",
                description: "\(emptyDocs.count) nearly empty documents found",
                action: .deleteEmpty,
                affectedFiles: emptyDocs.map { $0.url },
                potentialSaving: nil
            ))
        }
        
        return suggestions
    }
    
    // MARK: - General Analysis
    private func analyzeGeneralFiles(_ files: [ArchiveCandidate]) async -> [SmartSuggestion] {
        var suggestions: [SmartSuggestion] = []
        
        // Detect untouched files
        let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
        let untouchedFiles = files.filter { $0.lastModified < threeMonthsAgo }
        
        if untouchedFiles.count > 20 {
            let totalSize = untouchedFiles.reduce(0) { $0 + $1.size }
            let oldestDays = Calendar.current.dateComponents([.day], 
                from: untouchedFiles.min(by: { $0.lastModified < $1.lastModified })!.lastModified, 
                to: Date()).day ?? 0
            
            let iCloudCount = untouchedFiles.filter { $0.iCloudStatus != .notIniCloud }.count
            let description = iCloudCount > 0 
                ? "You haven't touched these \(untouchedFiles.count) files in \(oldestDays) days (\(iCloudCount) in iCloud)"
                : "You haven't touched these \(untouchedFiles.count) files in \(oldestDays) days"
            
            suggestions.append(SmartSuggestion(
                type: .archive,
                title: "Untouched Files",
                description: description,
                action: .archiveFiles,
                affectedFiles: untouchedFiles.map { $0.url },
                potentialSaving: totalSize
            ))
        }
        
        // iCloud-specific suggestions
        let iCloudNotDownloaded = files.filter { 
            if case .notDownloaded = $0.iCloudStatus { return true }
            return false
        }
        
        if iCloudNotDownloaded.count > 10 {
            suggestions.append(SmartSuggestion(
                type: .archive,
                title: "iCloud Files Not Downloaded",
                description: "\(iCloudNotDownloaded.count) files are stored only in iCloud - consider removing from local view",
                action: .archiveFiles,
                affectedFiles: iCloudNotDownloaded.map { $0.url },
                potentialSaving: nil
            ))
        }
        
        // Detect potential projects
        let projectGroups = detectPotentialProjects(files)
        for (projectName, projectFiles) in projectGroups {
            if projectFiles.count > 5 {
                suggestions.append(SmartSuggestion(
                    type: .projectDetection,
                    title: "Potential Project",
                    description: "These \(projectFiles.count) files might belong to '\(projectName)' project",
                    action: .moveToProject(name: projectName),
                    affectedFiles: projectFiles.map { $0.url },
                    potentialSaving: nil
                ))
            }
        }
        
        return suggestions
    }
    
    // MARK: - Helper Functions
    
    private func detectSamplePacks(_ audioFiles: [ArchiveCandidate]) -> [String: [ArchiveCandidate]] {
        var packs: [String: [ArchiveCandidate]] = [:]
        
        // Group by common prefixes
        for file in audioFiles {
            let name = file.url.deletingPathExtension().lastPathComponent
            
            // Look for common sample pack patterns
            if let match = name.range(of: #"^(.+?)[\s_-]*(\d+|[A-Z])"#, options: .regularExpression) {
                let packName = String(name[..<match.lowerBound])
                if packName.count > 3 {
                    if packs[packName] == nil {
                        packs[packName] = []
                    }
                    packs[packName]?.append(file)
                }
            }
        }
        
        // Filter out small groups
        return packs.filter { $0.value.count > 3 }
    }
    
    private func isOneShot(_ file: ArchiveCandidate) -> Bool {
        // This is a simplified check - in a real app, you'd analyze the actual audio duration
        // For now, use file size as a proxy (small files are likely short)
        return file.size < 2_000_000 // Less than 2MB
    }
    
    private func detectImageSequences(_ imageFiles: [ArchiveCandidate]) -> [String: [ArchiveCandidate]] {
        var sequences: [String: [ArchiveCandidate]] = [:]
        
        for file in imageFiles {
            let name = file.url.deletingPathExtension().lastPathComponent
            
            // Look for sequence patterns like frame_001, image01, etc.
            if let match = name.range(of: #"^(.+?)[\s_-]*(\d{2,4})"#, options: .regularExpression) {
                let baseName = String(name[..<match.lowerBound])
                if baseName.count > 2 {
                    if sequences[baseName] == nil {
                        sequences[baseName] = []
                    }
                    sequences[baseName]?.append(file)
                }
            }
        }
        
        return sequences.filter { $0.value.count > 2 }
    }
    
    private func isScreenshot(_ file: ArchiveCandidate) -> Bool {
        let name = file.url.lastPathComponent.lowercased()
        return name.contains("screenshot") || 
               name.contains("screen shot") || 
               name.hasPrefix("screen") ||
               (name.hasPrefix("image") && name.contains("at"))
    }
    
    private func detectDuplicateDocuments(_ documents: [ArchiveCandidate]) async -> [String: [ArchiveCandidate]] {
        var hashGroups: [String: [ArchiveCandidate]] = [:]
        
        await withTaskGroup(of: (ArchiveCandidate, String?).self) { group in
            for doc in documents {
                group.addTask {
                    let hash = await self.hashFile(doc.url)
                    return (doc, hash)
                }
            }
            
            for await (doc, hash) in group {
                if let hash = hash {
                    if hashGroups[hash] == nil {
                        hashGroups[hash] = []
                    }
                    hashGroups[hash]?.append(doc)
                }
            }
        }
        
        return hashGroups.filter { $0.value.count > 1 }
    }
    
    private func hashFile(_ url: URL) async -> String? {
        return await Task.detached {
            guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
            
            // For large files, just hash the first 1MB
            let sampleSize = min(data.count, 1_048_576)
            let sample = data.prefix(sampleSize)
            
            let hash = SHA256.hash(data: sample)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }.value
    }
    
    private func detectPotentialProjects(_ files: [ArchiveCandidate]) -> [String: [ArchiveCandidate]] {
        var projects: [String: [ArchiveCandidate]] = [:]
        
        // Group files by their parent directory name
        for file in files {
            let parentDir = file.url.deletingLastPathComponent().lastPathComponent
            
            // Skip system directories
            if !["Desktop", "Downloads", "Documents", "Pictures", "Movies"].contains(parentDir) {
                if projects[parentDir] == nil {
                    projects[parentDir] = []
                }
                projects[parentDir]?.append(file)
            }
        }
        
        // Look for files with similar names that might be a project
        let nameGroups = groupBySimilarNames(files)
        for (projectName, projectFiles) in nameGroups {
            if projectFiles.count > 3 {
                projects[projectName] = projectFiles
            }
        }
        
        return projects
    }
    
    private func groupBySimilarNames(_ files: [ArchiveCandidate]) -> [String: [ArchiveCandidate]] {
        var groups: [String: [ArchiveCandidate]] = [:]
        
        for file in files {
            let name = file.url.deletingPathExtension().lastPathComponent
            
            // Extract potential project name (first meaningful part)
            let components = name.components(separatedBy: CharacterSet(charactersIn: "_- "))
            if let firstComponent = components.first, firstComponent.count > 3 {
                if groups[firstComponent] == nil {
                    groups[firstComponent] = []
                }
                groups[firstComponent]?.append(file)
            }
        }
        
        return groups.filter { $0.value.count > 2 }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}