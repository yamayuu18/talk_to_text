import SwiftUI

@main
struct TalkToTextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 450, height: 300)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unifiedCompact)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarManager: MenuBarManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure logging to suppress known framework noise
        configureLogging()
        
        menuBarManager = MenuBarManager()
        
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func configureLogging() {
        // Suppress verbose logging from Speech framework and related components
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        setenv("ACTIVITY_LOG_STDERR", "0", 1)
        
        // Disable specific subsystem logging that generates 1101 errors
        UserDefaults.standard.set(false, forKey: "NSApplicationCrashOnExceptions")
        
        // Filter out Assistant framework logs
        #if DEBUG
        print("Logging configuration applied to suppress framework noise")
        #endif
    }
}