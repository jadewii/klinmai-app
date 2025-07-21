import SwiftUI

struct SmartCareView: View {
    @EnvironmentObject var smartCare: SmartCareEngine
    @EnvironmentObject var llmHandler: LLMHandler
    @Binding var isScanning: Bool
    @Binding var buttonScale: CGFloat
    @Binding var userInput: String
    
    @State private var glowAmount: Double = 0.5
    @State private var isHovering = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Big glowing clean button
            Button(action: {
                Task {
                    await runSmartCare()
                }
            }) {
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.red.opacity(0.8),
                                    Color.red.opacity(0.4),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 50,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .blur(radius: isScanning ? 30 : 20)
                        .opacity(glowAmount)
                        .animation(
                            .easeInOut(duration: 2)
                            .repeatForever(autoreverses: true),
                            value: glowAmount
                        )
                    
                    // Just use the image directly as the button
                    MascotImage(size: 200)
                        .rotationEffect(.degrees(isScanning ? 360 : 0))
                        .scaleEffect(isHovering ? 1.1 : 1.0)
                        .shadow(color: .red.opacity(0.5), radius: isHovering ? 20 : 10)
                        .animation(
                            isScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .spring(response: 0.3),
                            value: isScanning
                        )
                        .animation(.spring(response: 0.3), value: isHovering)
                    
                    // Option B: Mascot behind text (commented out - uncomment to use)
                    /*
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.2, blue: 0.3),
                                        Color(red: 0.8, green: 0.1, blue: 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .red.opacity(0.5), radius: isHovering ? 20 : 10)
                        
                        // Mascot behind text
                        Image("KlinmaiMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .opacity(0.3)
                            .rotationEffect(.degrees(isScanning ? 360 : 0))
                            .animation(
                                isScanning ? .linear(duration: 2).repeatForever(autoreverses: false) : .default,
                                value: isScanning
                            )
                        
                        // Text on top
                        Text("CLEAN MY\nCOMPUTER")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                        
                        // Border overlay
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    }
                    .frame(width: 200, height: 200)
                    */
                }
                .scaleEffect(buttonScale)
                .scaleEffect(isHovering ? 1.05 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(isScanning)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3)) {
                    isHovering = hovering
                }
            }
            .onAppear {
                glowAmount = 1.0
            }
            
            // AI command input with glass effect
            HStack(spacing: 15) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title2)
                
                TextField("Tell Klinmai what to clean...", text: $userInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .onSubmit {
                        Task {
                            await processAICommand()
                        }
                    }
                
                Button(action: {
                    Task {
                        await processAICommand()
                    }
                }) {
                    Text("Clean")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple, Color.pink],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(userInput.isEmpty || isScanning)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 500)
            
            // Quick action buttons
            HStack(spacing: 20) {
                QuickActionButton(
                    title: "Desktop",
                    icon: "desktopcomputer",
                    action: { await smartCare.cleanDesktop() }
                )
                
                QuickActionButton(
                    title: "Downloads",
                    icon: "arrow.down.circle",
                    action: { await smartCare.cleanDownloads() }
                )
                
                QuickActionButton(
                    title: "Duplicates",
                    icon: "doc.on.doc",
                    action: { await smartCare.findDuplicates() }
                )
                
                QuickActionButton(
                    title: "System",
                    icon: "gearshape.2",
                    action: { await smartCare.cleanSystem() }
                )
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    @MainActor
    private func runSmartCare() async {
        withAnimation(.spring(response: 0.3)) {
            buttonScale = 0.95
        }
        
        isScanning = true
        await smartCare.runFullScan()
        isScanning = false
        
        withAnimation(.spring(response: 0.3)) {
            buttonScale = 1.0
        }
    }
    
    @MainActor
    private func processAICommand() async {
        guard !userInput.isEmpty else { return }
        isScanning = true
        
        if let action = await llmHandler.processCommand(userInput) {
            await smartCare.executeAction(action)
        }
        
        userInput = ""
        isScanning = false
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () async -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(isHovering ? 0.4 : 0.2), lineWidth: 1)
                    )
            )
            .scaleEffect(isHovering ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3)) {
                isHovering = hovering
            }
        }
    }
}