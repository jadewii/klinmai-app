import SwiftUI

struct SetupView: View {
    let onDone: () -> Void
    @EnvironmentObject var appState: AppState
    @State private var selectedOrganization = "smart" // Default to smart
    @State private var selectedSchedule = "never" // Default to manual
    @State private var autoStartAtLogin = true
    @State private var createScreenshotsFolder = false
    @State private var deleteOldScreenshots = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title only
            Text("Organize your Mac the smart way.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.949, green: 0.616, blue: 0.827))
            
            // Main content area
            VStack(alignment: .leading, spacing: 20) {
                
                // Organization type section with screenshot options
                HStack(alignment: .top, spacing: 30) {
                    // Left side - Smart Native Organization
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(red: 0.949, green: 0.616, blue: 0.827))
                                .font(.system(size: 20))
                            Text("Smart Native Organization")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        }
                        
                        Text("Files go where they belong: Pictures → Pictures, Documents → Documents")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                            .padding(.leading, 28)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    // Right side - Screenshot options
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $createScreenshotsFolder) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Create Screenshots folder?")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                                Text("Organize screenshots by month in Documents/Screenshots")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                            }
                        }
                        .toggleStyle(PinkCheckboxStyle())
                        
                        if createScreenshotsFolder {
                            Toggle(isOn: $deleteOldScreenshots) {
                                Text("Delete screenshots after 30 days?")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                            }
                            .toggleStyle(PinkCheckboxStyle())
                            .padding(.leading, 25)
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 30)
                
                // Automatic Cleaning Schedule section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Automatic Cleaning Schedule")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                    
                    // Schedule options
                    VStack(alignment: .leading, spacing: 10) {
                        RadioButton(text: "Never", subtext: "Manual organization only", isSelected: selectedSchedule == "never") {
                            selectedSchedule = "never"
                        }
                        
                        RadioButton(text: "End of Day", subtext: "Automatically organize every night at 12 AM", isSelected: selectedSchedule == "daily") {
                            selectedSchedule = "daily"
                        }
                        
                        RadioButton(text: "End of Week", subtext: "Automatically organize every Sunday at 12 AM", isSelected: selectedSchedule == "weekly") {
                            selectedSchedule = "weekly"
                        }
                        
                        RadioButton(text: "End of Month", subtext: "Automatically organize on the last day of each month", isSelected: selectedSchedule == "monthly") {
                            selectedSchedule = "monthly"
                        }
                    }
                    
                    // Auto start at login checkbox
                    Toggle(isOn: $autoStartAtLogin) {
                        Text("Automatically start Klinmai at login")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    }
                    .toggleStyle(PinkCheckboxStyle())
                    .padding(.top, 10)
                }
                .padding(.horizontal, 40)
                
                
                // Tip section
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                    Text("Tip: Click the Klinmai icon in your menu bar anytime for instant cleanup!")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
                .frame(maxWidth: .infinity)
                .background(Color(red: 0.949, green: 0.616, blue: 0.827))
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.97, green: 0.97, blue: 0.97))
            
            // Bottom button area
            HStack {
                // Remove Quit button from here - it should only be in the menu
                
                Spacer()
                
                Button("Help & Feedback") {
                    if let url = URL(string: "https://klinmai.com/help") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(ClassicButtonStyle())
                
                // Done button - save and close window WITHOUT quitting app
                Button("Done") {
                    savePreferences()
                    onDone()
                }
                .buttonStyle(ClassicPinkButtonStyle())
            }
            .padding(20)
            .background(Color(red: 0.93, green: 0.93, blue: 0.93))
        }
        .frame(width: 680, height: 740)
        .background(Color(red: 0.97, green: 0.97, blue: 0.97))
    }
    
    var scheduleDisplayText: String {
        switch selectedSchedule {
        case "daily": return "Daily at 10 PM"
        case "weekly": return "Weekly on Sunday"
        case "monthly": return "Monthly"
        default: return "Never"
        }
    }
    
    func savePreferences() {
        appState.preferences.hasCompletedSetup = true
        appState.preferences.autoStartAtLogin = autoStartAtLogin
        
        // Set schedule preferences
        switch selectedSchedule {
        case "daily":
            appState.preferences.cleanAtEndOfDay = true
            appState.preferences.autoCleanEnabled = false
        case "weekly":
            appState.preferences.cleanAtEndOfDay = true
            appState.preferences.autoCleanEnabled = false
        case "monthly":
            appState.preferences.cleanAtEndOfDay = true
            appState.preferences.autoCleanEnabled = false
        default:
            appState.preferences.cleanAtEndOfDay = false
            appState.preferences.autoCleanEnabled = false
        }
        
        // Save screenshot preferences
        appState.preferences.createScreenshotsFolder = createScreenshotsFolder
        appState.preferences.deleteOldScreenshots = deleteOldScreenshots
        
        // Create Screenshots folder if enabled
        if createScreenshotsFolder {
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let screenshotsURL = documentsURL.appendingPathComponent("Screenshots")
            try? FileManager.default.createDirectory(at: screenshotsURL, withIntermediateDirectories: true)
        }
        
        appState.savePreferences()
    }
}

// Classic macOS button style
struct ClassicButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// Pink accent button for primary action
struct ClassicPinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.949, green: 0.616, blue: 0.827))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// Radio button component
struct RadioButton: View {
    let text: String
    let subtext: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? Color(red: 0.949, green: 0.616, blue: 0.827) : Color.gray)
                    .font(.system(size: 20))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(text)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                    Text(subtext)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Pink checkbox style
struct PinkCheckboxStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? Color(red: 0.949, green: 0.616, blue: 0.827) : Color.gray)
                .font(.system(size: 16))
                .onTapGesture { configuration.isOn.toggle() }
            
            configuration.label
        }
    }
}

#Preview {
    SetupView(onDone: {})
        .environmentObject(AppState())
        .frame(width: 680, height: 740)
}