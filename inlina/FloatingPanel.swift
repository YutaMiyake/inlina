import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    let selectedText: String?
    var onResult: ((String) -> Void)?
    private var escapeMonitor: Any?

    init(selectedText: String?) {
        self.selectedText = selectedText

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        // Text is captured before panel shows, so we can safely take focus.
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let panelView = FloatingPanelView(
            selectedText: selectedText,
            onResult: { [weak self] result in
                self?.onResult?(result)
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingController = NSHostingController(rootView: panelView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.cornerRadius = 14
        hostingController.view.layer?.cornerCurve = .continuous
        hostingController.view.layer?.masksToBounds = true
        contentViewController = hostingController
    }

    // MARK: - Presentation

    func show() {
        // Position near the mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        let origin = NSPoint(
            x: mouseLocation.x - frame.width / 2,
            y: mouseLocation.y - frame.height - 8
        )
        setFrameOrigin(origin)

        // Text is already captured, so it's safe to activate and take focus
        // for keyboard input in the text field.
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }

        // Monitor Escape key (panel is now key window)
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
                return nil
            }
            return event
        }
    }

    func dismiss() {
        cleanupMonitor()

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    override func orderOut(_ sender: Any?) {
        cleanupMonitor()
        super.orderOut(sender)
    }

    private func cleanupMonitor() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    // MARK: - Key Handling

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    override var canBecomeKey: Bool { true }
}
