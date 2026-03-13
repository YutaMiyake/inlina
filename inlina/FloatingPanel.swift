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
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true

        // Critical: These settings keep the source app's selection intact.
        // The panel floats above without stealing focus from the source app.
        becomesKeyOnlyIfNeeded = true
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

        // Use orderFront instead of makeKeyAndOrderFront to avoid
        // stealing focus from the source app (preserves text selection).
        orderFrontRegardless()
        alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }

        // Monitor Escape key globally (panel is not key window, so use global monitor)
        escapeMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    // MARK: - Key Handling

    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    override var canBecomeKey: Bool { true }
}
