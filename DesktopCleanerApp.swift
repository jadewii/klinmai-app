import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusBarItem: NSStatusItem!
    var popover = NSPopover()
    var appState: AppState!
    var timer: Timer?
    var endOfDayTimer: Timer?
    var setupWindow: NSWindow?
    var statusBarMenu: NSMenu!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CRITICAL: Make this a menu bar only app that NEVER quits on window close
        NSApp.setActivationPolicy(.accessory)
        
        // Create app state
        appState = AppState()
        
        // Setup status bar
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Create menu
        statusBarMenu = NSMenu()
        statusBarMenu.addItem(NSMenuItem(title: "About Klinmai", action: #selector(showAbout), keyEquivalent: ""))
        statusBarMenu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        if let button = statusBarItem.button {
            // Use klinmai2.png from desktop as menu bar icon
            if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                let iconURL = desktopURL.appendingPathComponent("klinmai2.png")
                if let klinmaiIcon = NSImage(contentsOf: iconURL) {
                    klinmaiIcon.size = NSSize(width: 20, height: 20)
                    klinmaiIcon.isTemplate = false  // Keep original colors
                    button.image = klinmaiIcon
                } else {
                    // Fallback to system icon
                    if let icon = NSImage(systemSymbolName: "sparkles.rectangle.stack", accessibilityDescription: "Desktop Cleaner") {
                        icon.size = NSSize(width: 18, height: 18)
                        icon.isTemplate = true
                        button.image = icon
                    }
                }
            }
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = appState.getTooltipText()
        }
        
        // Setup popover
        popover.contentViewController = NSHostingController(rootView: MenuView().environmentObject(appState))
        popover.behavior = .transient
        
        // Start auto-clean timer if enabled
        if appState.preferences.autoCleanEnabled {
            startAutoCleanTimer()
        }
        
        // Start end-of-day timer if enabled
        if appState.preferences.cleanAtEndOfDay {
            scheduleEndOfDayClean()
        }
        
        // Listen for preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: .preferencesChanged,
            object: nil
        )
        
        // Always show setup window on first launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showSetupWindow()
        }
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        
        if event.type == .rightMouseUp {
            // Show menu immediately on right click
            statusBarItem.menu = statusBarMenu
            statusBarItem.button?.performClick(nil)
            statusBarItem.menu = nil  // Remove menu after showing
        } else if event.type == .leftMouseUp {
            // Left click cleans desktop
            Task {
                await appState.cleanDesktop()
                await MainActor.run {
                    sender.toolTip = appState.getTooltipText()
                }
            }
        }
    }
    
    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "About Klinmai"
        alert.informativeText = "Klinmai Desktop Organizer\nVersion 1.0\n\nOrganize your Mac the smart way."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc func showPreferences() {
        showSetupWindow()
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    
    func showSetupWindow() {
        // Check if window already exists and is visible
        if let window = setupWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        setupWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 740),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        setupWindow?.title = "Klinmai Desktop"
        setupWindow?.contentView = NSHostingView(
            rootView: SetupView(onDone: {
                // Hide window instead of closing to prevent app quit
                self.setupWindow?.orderOut(nil)
                self.setupWindow = nil
            })
                .environmentObject(appState)
        )
        setupWindow?.center()
        setupWindow?.makeKeyAndOrderFront(nil)
        setupWindow?.delegate = self
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc func preferencesChanged() {
        if appState.preferences.autoCleanEnabled {
            startAutoCleanTimer()
        } else {
            timer?.invalidate()
            timer = nil
        }
        
        if appState.preferences.cleanAtEndOfDay {
            scheduleEndOfDayClean()
        } else {
            endOfDayTimer?.invalidate()
            endOfDayTimer = nil
        }
    }
    
    func startAutoCleanTimer() {
        timer?.invalidate()
        let interval = TimeInterval(appState.preferences.autoCleanInterval * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            Task {
                await self.appState.cleanDesktop()
            }
        }
    }
    
    func scheduleEndOfDayClean() {
        endOfDayTimer?.invalidate()
        
        let calendar = Calendar.current
        var nextCleanDate = calendar.dateComponents([.year, .month, .day], from: Date())
        nextCleanDate.hour = appState.preferences.endOfDayTime.hour
        nextCleanDate.minute = appState.preferences.endOfDayTime.minute
        
        if let targetDate = calendar.date(from: nextCleanDate),
           targetDate <= Date() {
            // If time has passed today, schedule for tomorrow
            nextCleanDate.day! += 1
        }
        
        guard let cleanDate = calendar.date(from: nextCleanDate) else { return }
        let timeInterval = cleanDate.timeIntervalSince(Date())
        
        endOfDayTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task {
                await self.appState.cleanDesktop()
                // Reschedule for next day
                self.scheduleEndOfDayClean()
            }
        }
    }
    
    // Window delegate methods - CRITICAL: Don't let window close quit the app
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender == setupWindow {
            // Hide the window instead of closing it
            setupWindow?.orderOut(nil)
            setupWindow = nil
            return false  // Prevent the actual close
        }
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == setupWindow {
            setupWindow = nil
        }
    }
    
    // Prevent app from terminating when window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // Also implement this to ensure app doesn't quit on window close
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSetupWindow()
        }
        return true
    }
}

extension Notification.Name {
    static let preferencesChanged = Notification.Name("preferencesChanged")
    static let setupCompleted = Notification.Name("setupCompleted")
}