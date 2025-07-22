// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Klinmai",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "KlinmaiCore",
            targets: ["KlinmaiCore"]
        ),
        .executable(
            name: "KlinmaiMac",
            targets: ["KlinmaiMac"]
        )
    ],
    targets: [
        // Shared core functionality
        .target(
            name: "KlinmaiCore",
            path: "Shared",
            sources: [
                "Core/Services/SubscriptionManager.swift",
                "Core/Models/",
                "Core/Stores/",
                "Views/"
            ]
        ),
        
        // Platform-specific targets
        .executableTarget(
            name: "KlinmaiMac",
            dependencies: ["KlinmaiCore"],
            path: ".",
            exclude: [
                "Info.plist", 
                "Klinmai.entitlements",
                "Shared",
                "iOS",
                "watchOS"
            ],
            sources: [
                "KlinmaiApp.swift",
                "SmartCareEngine.swift",
                "FileOrganizer.swift",
                "DuplicateScanner.swift",
                "SystemCleaner.swift",
                "MailAndTrashCleaner.swift",
                "LLMHandler.swift",
                "ConsoleView.swift",
                "SmartArchiveManager.swift",
                "ProjectDetector.swift",
                "CopyMascot.swift",
                "SmartCleanManager.swift",
                "DesktopOrganizer.swift",
                "GitHubIntegration.swift",
                "Views/"
            ]
        )
    ]
)