import SwiftUI

struct SmartSuggestionsView: View {
    @ObservedObject var smartCleanManager: SmartCleanManager
    let onApplySuggestion: (SmartSuggestion) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(smartCleanManager.suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        onApply: {
                            onApplySuggestion(suggestion)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(height: 140)
        .background(Color.white.opacity(0.03))
    }
}

struct SuggestionCard: View {
    let suggestion: SmartSuggestion
    let onApply: () -> Void
    
    @State private var isHovered = false
    @State private var showDetails = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: suggestion.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(suggestion.type.color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(suggestion.description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // AI suggestion indicator
                Image(systemName: "sparkle")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.7))
            }
            
            Spacer()
            
            HStack {
                if let saving = suggestion.potentialSaving {
                    Text("Save \(formatBytes(saving))")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                
                Spacer()
                
                Button(action: onApply) {
                    Text(actionText(for: suggestion.action))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color(hex: "f29dd3"))
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .frame(width: 280, height: 120)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHovered ? 0.12 : 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: isHovered ? Color.black.opacity(0.2) : Color.clear, radius: 8, y: 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            showDetails = true
        }
        .sheet(isPresented: $showDetails) {
            SuggestionDetailsView(suggestion: suggestion, onApply: {
                showDetails = false
                onApply()
            })
        }
    }
    
    private func actionText(for action: SmartSuggestion.SuggestionAction) -> String {
        switch action {
        case .archiveFiles: return "Archive"
        case .groupIntoFolder: return "Group"
        case .keepNewest: return "Clean Up"
        case .moveToProject: return "Organize"
        case .deleteEmpty: return "Delete"
        case .createSequence: return "Create Sequence"
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SuggestionDetailsView: View {
    let suggestion: SmartSuggestion
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Image(systemName: suggestion.type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(Color(suggestion.type.color))
                
                VStack(alignment: .leading) {
                    Text(suggestion.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("\(suggestion.affectedFiles.count) files affected")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Description
            Text(suggestion.description)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Files preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Files:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(suggestion.affectedFiles.prefix(10)), id: \.self) { url in
                            Text("• \(url.lastPathComponent)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        
                        if suggestion.affectedFiles.count > 10 {
                            Text("... and \(suggestion.affectedFiles.count - 10) more")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                                .italic()
                        }
                    }
                }
                .frame(maxHeight: 150)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            
            // Cross-suite awareness
            if shouldShowCrossSuiteHint(for: suggestion) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow)
                    
                    Text(crossSuiteHintText(for: suggestion))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.yellow.opacity(0.1))
                )
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button(action: onApply) {
                    HStack {
                        Image(systemName: actionIcon(for: suggestion.action))
                        Text(actionButtonText(for: suggestion.action))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "2a2a2a"))
        )
    }
    
    private func shouldShowCrossSuiteHint(for suggestion: SmartSuggestion) -> Bool {
        switch suggestion.action {
        case .moveToProject: return true
        case .groupIntoFolder(let name): return name.contains("Project")
        default: return false
        }
    }
    
    private func crossSuiteHintText(for suggestion: SmartSuggestion) -> String {
        switch suggestion.action {
        case .moveToProject:
            return "Pro tip: Projemai can help you manage projects more effectively!"
        case .groupIntoFolder(let name) where name.contains("Project"):
            return "Looks like a project! Projemai specializes in project organization."
        default:
            return ""
        }
    }
    
    private func actionIcon(for action: SmartSuggestion.SuggestionAction) -> String {
        switch action {
        case .archiveFiles: return "archivebox.fill"
        case .groupIntoFolder: return "folder.fill"
        case .keepNewest: return "sparkles"
        case .moveToProject: return "folder.badge.gearshape"
        case .deleteEmpty: return "trash"
        case .createSequence: return "square.stack.3d.forward.dottedline"
        }
    }
    
    private func actionButtonText(for action: SmartSuggestion.SuggestionAction) -> String {
        switch action {
        case .archiveFiles: return "Archive Files"
        case .groupIntoFolder(let name): return "Create '\(name)'"
        case .keepNewest: return "Keep Newest Only"
        case .moveToProject(let name): return "Move to '\(name)'"
        case .deleteEmpty: return "Delete Empty Files"
        case .createSequence(let name): return "Create '\(name)' Sequence"
        }
    }
}