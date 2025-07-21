import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject var smartCare: SmartCareEngine
    @State private var autoScroll = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Console header
            HStack {
                Label("Console Output", systemImage: "terminal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                
                Button(action: {
                    smartCare.consoleOutput.removeAll()
                }) {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.05))
            
            Divider()
            
            // Console content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(smartCare.consoleOutput) { entry in
                            ConsoleEntryView(entry: entry)
                                .id(entry.id)
                        }
                        
                        if smartCare.consoleOutput.isEmpty {
                            Text("Ready to clean your Mac...")
                                .foregroundColor(.white.opacity(0.4))
                                .font(.system(.body, design: .monospaced))
                                .padding()
                        }
                    }
                    .padding()
                }
                .background(Color.black.opacity(0.3))
                .onChange(of: smartCare.consoleOutput.count) { _ in
                    if autoScroll, let lastEntry = smartCare.consoleOutput.last {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }
}

struct ConsoleEntryView: View {
    let entry: ConsoleEntry
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: entry.timestamp)
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(timeString)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .trailing)
            
            Image(systemName: entry.type.icon)
                .foregroundColor(entry.type.color)
                .font(.caption)
                .frame(width: 16)
            
            Text(entry.message)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(entry.type.color)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}