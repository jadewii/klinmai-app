import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var selectedSortMode: SortMode
    @State private var autoCleanInterval: Double
    @State private var showUndoAfterClean: Bool
    @State private var cleanAtEndOfDay: Bool
    @State private var endOfDayHour: Int = 18
    @State private var endOfDayMinute: Int = 0
    @State private var showingFolderPicker = false
    
    init() {
        let state = AppState()
        _selectedSortMode = State(initialValue: state.preferences.sortMode)
        _autoCleanInterval = State(initialValue: Double(state.preferences.autoCleanInterval))
        _showUndoAfterClean = State(initialValue: state.preferences.showUndoAfterClean)
        _cleanAtEndOfDay = State(initialValue: state.preferences.cleanAtEndOfDay)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Sort Mode Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Organization Method", systemImage: "folder.badge.gearshape")
                                .font(.headline)
                                .foregroundColor(Color.appPink)
                            
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                HStack {
                                    Image(systemName: mode.icon)
                                        .frame(width: 24)
                                    
                                    Text(mode.rawValue)
                                    
                                    Spacer()
                                    
                                    if selectedSortMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color.appPink)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedSortMode == mode ? Color.appPink.opacity(0.1) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedSortMode = mode
                                    if mode == .custom {
                                        showingFolderPicker = true
                                    }
                                }
                            }
                            
                            if selectedSortMode == .custom,
                               let customFolder = appState.preferences.customFolder {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(Color.appPink)
                                    Text(customFolder.lastPathComponent)
                                        .font(.caption)
                                    Spacer()
                                    Button("Change") {
                                        showingFolderPicker = true
                                    }
                                    .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                    }
                    
                    // Auto Clean Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Automatic Cleaning", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                                .foregroundColor(Color.appPink)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Clean every \(Int(autoCleanInterval)) minutes")
                                    .font(.subheadline)
                                
                                Slider(value: $autoCleanInterval, in: 5...120, step: 5)
                                    .tint(Color.appPink)
                            }
                            
                            Divider()
                            
                            // End of Day Clean
                            Toggle(isOn: $cleanAtEndOfDay) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Clean at End of Day")
                                        .font(.subheadline)
                                    Text("Automatically organize desktop at a specific time")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(PinkToggleStyle())
                            
                            if cleanAtEndOfDay {
                                HStack {
                                    Text("Clean at:")
                                        .font(.subheadline)
                                    
                                    Spacer()
                                    
                                    Picker("Hour", selection: $endOfDayHour) {
                                        ForEach(0..<24) { hour in
                                            Text(String(format: "%02d", hour))
                                                .tag(hour)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 60)
                                    
                                    Text(":")
                                    
                                    Picker("Minute", selection: $endOfDayMinute) {
                                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                                            Text(String(format: "%02d", minute))
                                                .tag(minute)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 60)
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                    
                    // Other Options
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Options", systemImage: "gearshape")
                                .font(.headline)
                                .foregroundColor(Color.appPink)
                            
                            Toggle(isOn: $showUndoAfterClean) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Show Undo Button")
                                    Text("Display undo option after cleaning")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(PinkToggleStyle())
                        }
                    }
                    
                    // Save Button
                    HStack {
                        Spacer()
                        
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Button(appState.preferences.hasCompletedSetup ? "Save" : "Close") {
                            savePreferences()
                            if !appState.preferences.hasCompletedSetup {
                                appState.preferences.hasCompletedSetup = true
                                NotificationCenter.default.post(name: .setupCompleted, object: nil)
                            }
                            dismiss()
                        }
                        .buttonStyle(PinkButtonStyle())
                    }
                }
                .padding()
            }
        }
        .frame(width: 450, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result,
               let url = urls.first {
                appState.preferences.customFolder = url
            }
        }
        .onAppear {
            selectedSortMode = appState.preferences.sortMode
            autoCleanInterval = Double(appState.preferences.autoCleanInterval)
            showUndoAfterClean = appState.preferences.showUndoAfterClean
            cleanAtEndOfDay = appState.preferences.cleanAtEndOfDay
            if let time = appState.preferences.endOfDayTime {
                endOfDayHour = time.hour ?? 18
                endOfDayMinute = time.minute ?? 0
            }
        }
    }
    
    private func savePreferences() {
        appState.preferences.sortMode = selectedSortMode
        appState.preferences.autoCleanInterval = Int(autoCleanInterval)
        appState.preferences.showUndoAfterClean = showUndoAfterClean
        appState.preferences.cleanAtEndOfDay = cleanAtEndOfDay
        appState.preferences.endOfDayTime = DateComponents(hour: endOfDayHour, minute: endOfDayMinute)
        appState.savePreferences() // Save to UserDefaults
    }
}

struct PinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.appPink)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}