import Foundation

struct ProjectFolder: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let type: ProjectType
    let fileCount: Int
    let totalSize: Int64
    let lastModified: Date
    let confidence: Double // 0.0 to 1.0
    
    enum ProjectType: String, CaseIterable {
        case design = "Design"
        case development = "Development"
        case video = "Video"
        case audio = "Audio"
        case photo = "Photo"
        case writing = "Writing"
        case mixed = "Mixed Media"
        case unknown = "Unknown"
        
        var icon: String {
            switch self {
            case .design: return "paintbrush"
            case .development: return "chevron.left.forwardslash.chevron.right"
            case .video: return "video"
            case .audio: return "waveform"
            case .photo: return "camera"
            case .writing: return "doc.text"
            case .mixed: return "folder.fill.badge.gearshape"
            case .unknown: return "folder"
            }
        }
    }
}

class ProjectDetector {
    private let fileManager = FileManager.default
    
    // Project indicators
    private let projectPatterns = [
        "project", "proj_", "v1", "v2", "final", "draft", "wip",
        "client", "logo", "design", "mockup", "prototype"
    ]
    
    // File type signatures for different project types
    private let projectSignatures: [ProjectFolder.ProjectType: Set<String>] = [
        .design: ["psd", "ai", "sketch", "fig", "xd", "indd", "eps"],
        .development: ["swift", "py", "js", "ts", "java", "cpp", "h", "xcodeproj", "pbxproj"],
        .video: ["prproj", "fcpx", "aep", "dav", "veg"],
        .audio: ["logic", "als", "flp", "ptx", "cpr"],
        .photo: ["lrcat", "lrtemplate", "cos"],
        .writing: ["scriv", "ulysses", "fountain", "celtx"]
    ]
    
    func detectProjectFolders(in directories: [URL]) async -> [ProjectFolder] {
        var detectedProjects: [ProjectFolder] = []
        
        for directory in directories {
            let projects = await scanForProjects(in: directory)
            detectedProjects.append(contentsOf: projects)
        }
        
        // Sort by confidence and size
        return detectedProjects.sorted { 
            if $0.confidence == $1.confidence {
                return $0.totalSize > $1.totalSize
            }
            return $0.confidence > $1.confidence
        }
    }
    
    private func scanForProjects(in directory: URL) async -> [ProjectFolder] {
        var projects: [ProjectFolder] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
                options: [.skipsHiddenFiles]
            )
            
            for url in contents {
                let attributes = try url.resourceValues(forKeys: [.isDirectoryKey])
                guard attributes.isDirectory == true else { continue }
                
                // Skip system folders
                let folderName = url.lastPathComponent.lowercased()
                if folderName == "library" || folderName == "applications" { continue }
                
                // Analyze folder
                if let project = await analyzeFolder(url) {
                    projects.append(project)
                }
            }
        } catch {
            // Skip directories we can't read
        }
        
        return projects
    }
    
    private func analyzeFolder(_ folderURL: URL) async -> ProjectFolder? {
        let folderName = folderURL.lastPathComponent.lowercased()
        var confidence: Double = 0
        
        // Check folder name patterns
        for pattern in projectPatterns {
            if folderName.contains(pattern) {
                confidence += 0.3
                break
            }
        }
        
        // Analyze folder contents
        var fileTypes: [String: Int] = [:]
        var totalSize: Int64 = 0
        var fileCount = 0
        var lastModified = Date.distantPast
        
        // Use a synchronous scan wrapped in Task.detached
        let scanResult = await Task.detached {
            if let enumerator = self.fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles],
                errorHandler: nil
            ) {
                while let fileURL = enumerator.nextObject() as? URL {
                    do {
                        let attributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey])
                        
                        guard attributes.isRegularFile == true else { continue }
                        
                        fileCount += 1
                        totalSize += Int64(attributes.fileSize ?? 0)
                        
                        if let modDate = attributes.contentModificationDate, modDate > lastModified {
                            lastModified = modDate
                        }
                        
                        let ext = fileURL.pathExtension.lowercased()
                        fileTypes[ext, default: 0] += 1
                        
                    } catch {
                        continue
                    }
                }
            }
            return (fileTypes, totalSize, fileCount, lastModified)
        }.value
        
        fileTypes = scanResult.0
        totalSize = scanResult.1
        fileCount = scanResult.2
        lastModified = scanResult.3
        
        // Skip empty or tiny folders
        if fileCount < 3 || totalSize < 1_000_000 { // Less than 1MB
            return nil
        }
        
        // Detect project type based on file signatures
        let projectType = detectProjectType(from: fileTypes)
        
        // Boost confidence based on file diversity and project files
        if fileTypes.count > 5 {
            confidence += 0.2
        }
        
        if projectType != .unknown {
            confidence += 0.4
        }
        
        // Check for mixed media (strong project indicator)
        let hasMedia = fileTypes.keys.contains { ["jpg", "png", "mp4", "mov", "mp3", "wav"].contains($0) }
        let hasDocuments = fileTypes.keys.contains { ["pdf", "doc", "docx", "txt"].contains($0) }
        let hasCode = fileTypes.keys.contains { ["swift", "py", "js", "html", "css"].contains($0) }
        
        if (hasMedia && hasDocuments) || (hasMedia && hasCode) || (hasDocuments && hasCode) {
            confidence += 0.3
        }
        
        // Require minimum confidence
        guard confidence >= 0.3 else { return nil }
        
        return ProjectFolder(
            url: folderURL,
            name: folderURL.lastPathComponent,
            type: projectType,
            fileCount: fileCount,
            totalSize: totalSize,
            lastModified: lastModified,
            confidence: min(confidence, 1.0)
        )
    }
    
    private func detectProjectType(from fileTypes: [String: Int]) -> ProjectFolder.ProjectType {
        var typeScores: [ProjectFolder.ProjectType: Int] = [:]
        
        for (ext, count) in fileTypes {
            for (projectType, signatures) in projectSignatures {
                if signatures.contains(ext) {
                    typeScores[projectType, default: 0] += count * 10 // Weight project files heavily
                }
            }
        }
        
        // Check for common file types
        let imageCount = fileTypes.filter { ["jpg", "jpeg", "png", "gif", "bmp"].contains($0.key) }.values.reduce(0, +)
        let videoCount = fileTypes.filter { ["mp4", "mov", "avi", "mkv"].contains($0.key) }.values.reduce(0, +)
        let audioCount = fileTypes.filter { ["mp3", "wav", "aiff", "flac"].contains($0.key) }.values.reduce(0, +)
        let codeCount = fileTypes.filter { ["swift", "py", "js", "java", "cpp"].contains($0.key) }.values.reduce(0, +)
        
        if imageCount > 10 { typeScores[.photo, default: 0] += imageCount }
        if videoCount > 3 { typeScores[.video, default: 0] += videoCount * 3 }
        if audioCount > 5 { typeScores[.audio, default: 0] += audioCount * 2 }
        if codeCount > 5 { typeScores[.development, default: 0] += codeCount * 2 }
        
        // Find the highest scoring type
        if let (topType, _) = typeScores.max(by: { $0.value < $1.value }) {
            return topType
        }
        
        // Check if it's mixed media
        let uniqueTypes = Set([imageCount > 0, videoCount > 0, audioCount > 0, codeCount > 0].filter { $0 })
        if uniqueTypes.count >= 2 {
            return .mixed
        }
        
        return .unknown
    }
    
    func organizeProjects(_ projects: [ProjectFolder]) async -> (organized: Int, errors: [String]) {
        var organized = 0
        var errors: [String] = []
        
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let projectsBaseURL = documentsURL.appendingPathComponent("Projects_Cleaned")
        
        for project in projects {
            do {
                // Create category folder
                let categoryURL = projectsBaseURL.appendingPathComponent(project.type.rawValue)
                try fileManager.createDirectory(at: categoryURL, withIntermediateDirectories: true)
                
                // Move project folder
                let destURL = categoryURL.appendingPathComponent(project.name)
                let finalURL = uniqueURL(for: destURL)
                
                try fileManager.moveItem(at: project.url, to: finalURL)
                organized += 1
                
            } catch {
                errors.append("Failed to organize \(project.name): \(error.localizedDescription)")
            }
        }
        
        return (organized, errors)
    }
    
    private func uniqueURL(for url: URL) -> URL {
        var finalURL = url
        var counter = 1
        
        while fileManager.fileExists(atPath: finalURL.path) {
            let name = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newName = "\(name)_\(counter)" + (ext.isEmpty ? "" : ".\(ext)")
            finalURL = url.deletingLastPathComponent().appendingPathComponent(newName)
            counter += 1
        }
        
        return finalURL
    }
}