import SwiftUI

struct DesktopOrganizerView: View {
    @StateObject private var organizer = DesktopOrganizer()
    @State private var showOrganizeDialog = false
    @State private var selectedFolderOption: FolderOption = .new
    @State private var newFolderName = ""
    @State private var selectedExistingFolder = ""
    @State private var organizeByType = true
    @State private var isOrganizing = false
    @State private var showSuccessAlert = false
    @State private var errorMessage = ""
    
    enum FolderOption {
        case new
        case existing
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "desktopcomputer")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.8))
                
                Text("Desktop Organizer")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Clean up your desktop by organizing files into folders")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Stats
            if !organizer.desktopFiles.isEmpty {
                HStack(spacing: 40) {
                    StatBox(
                        icon: "doc.fill",
                        value: "\(organizer.desktopFiles.count)",
                        label: "Files on Desktop"
                    )
                    
                    StatBox(
                        icon: "folder.fill",
                        value: "\(organizer.getExistingDesktopFolders().count)",
                        label: "Existing Folders"
                    )
                }
                .padding(.vertical, 20)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                if organizer.isScanning {
                    ProgressView("Scanning desktop...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                } else if organizer.desktopFiles.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        
                        Text("Your desktop is clean!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Button("Scan Desktop") {
                            Task {
                                await organizer.scanDesktop()
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                    }
                } else {
                    Button("Organize Desktop") {
                        showOrganizeDialog = true
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    
                    Button("Rescan") {
                        Task {
                            await organizer.scanDesktop()
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await organizer.scanDesktop()
            }
        }
        .sheet(isPresented: $showOrganizeDialog) {
            OrganizeFolderDialog(
                organizer: organizer,
                selectedFolderOption: $selectedFolderOption,
                newFolderName: $newFolderName,
                selectedExistingFolder: $selectedExistingFolder,
                organizeByType: $organizeByType,
                isOrganizing: $isOrganizing,
                onConfirm: {
                    Task {
                        await organizeDesktop()
                    }
                }
            )
        }
        .alert("Success!", isPresented: $showSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Your desktop has been organized successfully!")
        }
    }
    
    private func organizeDesktop() async {
        isOrganizing = true
        showOrganizeDialog = false
        
        let folderName: String
        if selectedFolderOption == .new {
            folderName = newFolderName.isEmpty ? organizer.folderSuggestions.first! : newFolderName
        } else {
            folderName = selectedExistingFolder
        }
        
        let success = await organizer.organizeIntoFolder(folderName: folderName, organizeByType: organizeByType)
        
        isOrganizing = false
        if success {
            showSuccessAlert = true
            // Reset form
            newFolderName = ""
            selectedExistingFolder = ""
        }
    }
}

struct OrganizeFolderDialog: View {
    let organizer: DesktopOrganizer
    @Binding var selectedFolderOption: DesktopOrganizerView.FolderOption
    @Binding var newFolderName: String
    @Binding var selectedExistingFolder: String
    @Binding var organizeByType: Bool
    @Binding var isOrganizing: Bool
    let onConfirm: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 48))
                    .foregroundColor(Color(hex: "f29dd3"))
                
                Text("Organize Desktop Files")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("\(organizer.desktopFiles.count) files will be organized")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Folder selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose destination folder:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                // New folder option
                RadioButton(
                    title: "Create new folder",
                    isSelected: selectedFolderOption == .new,
                    action: { selectedFolderOption = .new }
                )
                
                if selectedFolderOption == .new {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Folder name", text: $newFolderName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.leading, 24)
                        
                        // Suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(organizer.folderSuggestions, id: \.self) { suggestion in
                                    Button(suggestion) {
                                        newFolderName = suggestion
                                    }
                                    .buttonStyle(SuggestionButtonStyle())
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
                
                // Existing folder option
                let existingFolders = organizer.getExistingDesktopFolders()
                if !existingFolders.isEmpty {
                    RadioButton(
                        title: "Use existing folder",
                        isSelected: selectedFolderOption == .existing,
                        action: { selectedFolderOption = .existing }
                    )
                    
                    if selectedFolderOption == .existing {
                        Picker("Select folder", selection: $selectedExistingFolder) {
                            ForEach(existingFolders, id: \.self) { folder in
                                Text(folder).tag(folder)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .padding(.leading, 24)
                        .onAppear {
                            if selectedExistingFolder.isEmpty {
                                selectedExistingFolder = existingFolders.first ?? ""
                            }
                        }
                    }
                }
            }
            
            // Organization options
            VStack(alignment: .leading, spacing: 12) {
                Text("Organization options:")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Toggle(isOn: $organizeByType) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Organize by file type")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                        Text("Creates subfolders for Images, Documents, Videos, etc.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: Color(hex: "f29dd3")))
            }
            
            // Progress
            if isOrganizing {
                VStack(spacing: 8) {
                    ProgressView(value: organizer.organizationProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(hex: "f29dd3")))
                    Text("Organizing files...")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Organize") {
                    onConfirm()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isOrganizing || (selectedFolderOption == .new && newFolderName.isEmpty && !organizer.folderSuggestions.contains(newFolderName)))
            }
        }
        .padding(32)
        .frame(width: 500)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "2a2a2a"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct RadioButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color(hex: "f29dd3") : .white.opacity(0.5))
                
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "f29dd3"))
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(hex: "f29dd3"), Color(hex: "f29dd3").opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}