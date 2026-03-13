import SwiftUI
import KeyboardShortcuts
import ApplicationServices

@main
struct InlinaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "sparkles")
        }
    }
}

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        Button("Activate inlina") {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.activateInlina()
            }
        }
        
        Divider()
        
        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            if #available(macOS 14.0, *) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
        }
        .keyboardShortcut(",", modifiers: .command)
        
        Divider()
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        setupStatusItem()
        setupKeyboardShortcut()
        requestAccessibilityPermission()
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        // Status item is now handled by MenuBarExtra in SwiftUI
        // This method is kept for backward compatibility if needed
    }

    // MARK: - Keyboard Shortcut

    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .activateInlina) { [weak self] in
            self?.activateInlina()
        }
    }

    // MARK: - Accessibility

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        if !trusted {
            print("inlina: Accessibility permission not yet granted. Please enable it in System Settings > Privacy & Security > Accessibility.")
        }
    }

    // MARK: - Actions

    private var currentPanel: FloatingPanel?
    private var sourceApp: NSRunningApplication?

    @objc func activateInlina() {
        // Remember the source app so we can return focus on Replace.
        sourceApp = NSWorkspace.shared.frontmostApplication

        // IMPORTANT: Grab the selected text BEFORE showing any UI,
        // while the source app still has focus and selection is intact.
        let selectedText = getSelectedText()
        
        // Print for debugging
        if let text = selectedText {
            print("inlina: Captured selected text: \"\(text)\"")
        } else {
            print("inlina: No text was selected or could not access selection")
        }

        // Close existing panel if any
        currentPanel?.orderOut(nil)

        // Small delay to ensure we don't interfere with the source app
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let panel = FloatingPanel(selectedText: selectedText)
            panel.onResult = { [weak self] result in
                self?.replaceSelectedText(with: result)
            }
            panel.show()
            self.currentPanel = panel
        }
    }

    // MARK: - Text Manipulation via Accessibility API

    func getSelectedText() -> String? {
        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        let appResult = AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)
        guard appResult == .success, let appElement = focusedApp else {
            print("inlina: Could not get focused application. Error: \(appResult.rawValue)")
            return getSelectedTextViaCopy()
        }

        var focusedElement: AnyObject?
        let elementResult = AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard elementResult == .success, let uiElement = focusedElement else {
            print("inlina: Could not get focused UI element. Error: \(elementResult.rawValue)")
            return getSelectedTextViaCopy()
        }

        var selectedTextValue: AnyObject?
        let textResult = AXUIElementCopyAttributeValue(uiElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        
        if textResult == .success, let text = selectedTextValue as? String, !text.isEmpty {
            print("inlina: Got text via Accessibility API")
            return text
        } else {
            print("inlina: Could not get selected text via Accessibility. Error: \(textResult.rawValue)")
            
            // If selected text fails, try to get the value attribute as fallback
            var value: AnyObject?
            let valueResult = AXUIElementCopyAttributeValue(uiElement as! AXUIElement, kAXValueAttribute as CFString, &value)
            if valueResult == .success, let text = value as? String, !text.isEmpty {
                print("inlina: Used value attribute as fallback")
                return text
            }
            
            // Final fallback: simulate copy to clipboard
            print("inlina: Falling back to copy method...")
            return getSelectedTextViaCopy()
        }
    }
    
    private func getSelectedTextViaCopy() -> String? {
        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let oldChangeCount = pasteboard.changeCount
        let oldContents = pasteboard.string(forType: .string)
        
        print("inlina: Attempting to get text via Cmd+C...")
        
        // Clear clipboard to detect if copy worked
        pasteboard.clearContents()
        
        // Simulate Cmd+C
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)  // 0x08 = 'c'
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand
        
        keyDown?.post(tap: .cghidEventTap)
        usleep(5000) // 5ms delay
        keyUp?.post(tap: .cghidEventTap)
        
        // Wait a bit for the copy to complete
        usleep(50000) // 50ms
        
        // Check if clipboard changed
        let newChangeCount = pasteboard.changeCount
        if newChangeCount != oldChangeCount, let copiedText = pasteboard.string(forType: .string), !copiedText.isEmpty {
            print("inlina: Successfully got text via copy: \"\(copiedText)\"")
            
            // Restore old clipboard in background
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let oldContents = oldContents {
                    pasteboard.clearContents()
                    pasteboard.setString(oldContents, forType: .string)
                }
            }
            
            return copiedText
        } else {
            print("inlina: Copy method failed - clipboard didn't change")
            // Restore old clipboard
            if let oldContents = oldContents {
                pasteboard.clearContents()
                pasteboard.setString(oldContents, forType: .string)
            }
            return nil
        }
    }

    func replaceSelectedText(with newText: String) {
        print("inlina: Starting text replacement...")
        
        // Save the original pasteboard contents
        let pasteboard = NSPasteboard.general
        let oldContents = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dict = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        }

        // Put the new text on the clipboard
        pasteboard.clearContents()
        pasteboard.setString(newText, forType: .string)
        print("inlina: New text copied to pasteboard")

        // Hide the panel immediately (no animation) so it releases focus
        currentPanel?.orderOut(nil)
        currentPanel = nil

        // Deactivate inlina so the source app can take focus
        NSApp.hide(nil)

        // Activate the source app
        sourceApp?.activate()

        // Wait for the source app to regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("inlina: Simulating paste...")
            self.simulatePaste()
            
            // Restore the original clipboard contents after paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                pasteboard.clearContents()
                if let oldContents = oldContents {
                    for itemDict in oldContents {
                        let item = NSPasteboardItem()
                        for (type, data) in itemDict {
                            item.setData(data, forType: type)
                        }
                        pasteboard.writeObjects([item])
                    }
                    print("inlina: Restored original pasteboard contents")
                } else {
                    print("inlina: No original contents to restore")
                }
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Simulate Cmd+V
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // 0x09 = 'v'
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand

        if keyDown != nil && keyUp != nil {
            keyDown?.post(tap: .cghidEventTap)
            // Small delay between key down and key up for reliability
            usleep(10000) // 10ms
            keyUp?.post(tap: .cghidEventTap)
            print("inlina: Paste command sent (Cmd+V)")
        } else {
            print("inlina: ERROR - Failed to create CGEvent for paste")
        }
    }
}
