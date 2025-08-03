// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DesktopCleaner",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DesktopCleaner",
            targets: ["DesktopCleaner"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DesktopCleaner",
            path: ".",
            sources: [
                "main.swift",
                "DesktopCleanerApp.swift",
                "Models/AppState.swift", 
                "Services/FileOrganizer.swift",
                "Services/UndoManager.swift",
                "Views/MenuView.swift",
                "SetupView.swift"
            ]
        )
    ]
)
