import SwiftUI
import AppKit

/// Manages NSWindow lifecycle for Settings and Logs panels.
/// Used because MenuBarExtra doesn't support .sheet.
final class WindowManager: NSObject {
    static let shared = WindowManager()

    private var settingsWindow: NSWindow?
    private var logWindow: NSWindow?

    func showSettings(proxyManager: ProxyManager) {
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView(proxyManager: proxyManager)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame.size = hosting.fittingSize

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Proxy Settings"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showLogs(proxyManager: ProxyManager) {
        if let existing = logWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = LogView(proxyManager: proxyManager)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame.size = hosting.fittingSize

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Proxy Logs"
        window.contentView = hosting
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self

        logWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - NSWindowDelegate

extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            if window == settingsWindow { settingsWindow = nil }
            if window == logWindow { logWindow = nil }
        }
    }
}
