import SwiftUI

struct PerfectCircularButton: View {
    @State private var isPressed = false
    @State private var isHovering = false
    
    var body: some View {
        Button(action: {
            // Your action here
            print("Dinosaur button tapped!")
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 200, height: 200)
                
                // The dinosaur image
                Image("dino")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140) // 70% of circle size for padding
                    .clipShape(Circle()) // Ensures it stays within circular bounds
            }
            // Outer glow effect
            .shadow(color: .red.opacity(0.6), radius: isHovering ? 20 : 10)
            // Optional border
            .overlay(
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 200, height: 200)
            )
        }
        .buttonStyle(PlainButtonStyle()) // Removes default button styling
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: isPressed)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .pressEvents(onPress: {
            isPressed = true
        }, onRelease: {
            isPressed = false
        })
    }
}

// Version 2: With more control over image positioning
struct CircularImageButton: View {
    let imageName: String
    let size: CGFloat
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Perfect circle background
                Circle()
                    .fill(Color.red.gradient)
                    .frame(width: size, height: size)
                
                // Image with proper scaling
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: size * 0.7,  // 70% of button size
                        height: size * 0.7
                    )
            }
        }
        .buttonStyle(.plain)
        .shadow(
            color: .red.opacity(isHovering ? 0.6 : 0.3),
            radius: isHovering ? 15 : 8,
            x: 0,
            y: 4
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// Version 3: Most flexible with all options
struct UltimateCircularButton: View {
    let imageName: String
    let buttonSize: CGFloat
    let imageScale: CGFloat // 0.0 to 1.0 (percentage of button)
    let backgroundColor: Color
    let glowColor: Color
    let action: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            GeometryReader { geometry in
                ZStack {
                    // Background circle
                    Circle()
                        .fill(backgroundColor)
                    
                    // Centered image
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(
                            width: buttonSize * imageScale,
                            height: buttonSize * imageScale
                        )
                        .position(
                            x: geometry.size.width / 2,
                            y: geometry.size.height / 2
                        )
                }
            }
            .frame(width: buttonSize, height: buttonSize)
            .clipShape(Circle())
            // Glow effect
            .background(
                Circle()
                    .fill(glowColor.opacity(0.3))
                    .blur(radius: isHovering ? 20 : 10)
                    .offset(y: 4)
                    .scaleEffect(isHovering ? 1.2 : 1.1)
            )
            // Border
            .overlay(
                Circle()
                    .strokeBorder(
                        Color.white.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : (isHovering ? 1.05 : 1.0))
        .animation(.spring(response: 0.3), value: isHovering)
        .animation(.spring(response: 0.1), value: isPressed)
        .onHover { hovering in
            isHovering = hovering
        }
        .pressEvents(onPress: {
            isPressed = true
        }, onRelease: {
            isPressed = false
        })
    }
}

// Helper for press events
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if pressing {
                onPress()
            } else {
                onRelease()
            }
        }, perform: {})
    }
}

// Usage examples:
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 50) {
            // Simple version
            CircularImageButton(
                imageName: "dino",
                size: 200,
                action: { print("Tapped!") }
            )
            
            // Customizable version
            UltimateCircularButton(
                imageName: "dino",
                buttonSize: 150,
                imageScale: 0.75,
                backgroundColor: .purple,
                glowColor: .purple,
                action: { print("Ultimate tapped!") }
            )
        }
        .padding()
        .background(Color.black)
    }
}