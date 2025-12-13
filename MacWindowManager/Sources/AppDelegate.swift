import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var windowManager: WindowManager!
    private var hotkeyManager: HotkeyManager!
    private var tileEngine: TileEngine!
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check accessibility permissions
        if !AXIsProcessTrusted() {
            promptForAccessibility()
        }

        // Initialize components
        windowManager = WindowManager()
        tileEngine = TileEngine(windowManager: windowManager)
        hotkeyManager = HotkeyManager()

        // Setup hotkeys
        setupHotkeys()

        // Setup menu bar
        setupMenuBar()

        // Setup window change observer
        setupWindowObserver()

        // Initial tile
        tileEngine.tileWindows()

        print("MacWindowManager started")
    }

    private func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "Window Manager")
        }

        let menu = NSMenu()

        let enableItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enableItem.state = isEnabled ? .on : .off
        menu.addItem(enableItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Tile Now", action: #selector(tileNow), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "Reset Sizes", action: #selector(resetSizes), keyEquivalent: "r"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func setupHotkeys() {
        // Hyper + Up: Increase width
        hotkeyManager.register(keyCode: UInt32(kVK_UpArrow), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey)) { [weak self] in
            self?.tileEngine.increaseWidth()
        }

        // Hyper + Down: Decrease width
        hotkeyManager.register(keyCode: UInt32(kVK_DownArrow), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey)) { [weak self] in
            self?.tileEngine.decreaseWidth()
        }

        // Hyper + Left: Swap left
        hotkeyManager.register(keyCode: UInt32(kVK_LeftArrow), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey)) { [weak self] in
            self?.tileEngine.swapLeft()
        }

        // Hyper + Right: Swap right
        hotkeyManager.register(keyCode: UInt32(kVK_RightArrow), modifiers: UInt32(cmdKey | controlKey | optionKey | shiftKey)) { [weak self] in
            self?.tileEngine.swapRight()
        }
    }

    private func setupWindowObserver() {
        // Observe window creation/destruction via NSWorkspace
        let notificationCenter = NSWorkspace.shared.notificationCenter

        notificationCenter.addObserver(self, selector: #selector(windowsChanged),
                                       name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowsChanged),
                                       name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowsChanged),
                                       name: NSWorkspace.didActivateApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowsChanged),
                                       name: NSWorkspace.didHideApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowsChanged),
                                       name: NSWorkspace.didUnhideApplicationNotification, object: nil)
    }

    @objc private func windowsChanged(_ notification: Notification) {
        guard isEnabled else { return }
        // Small delay to let window system settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.tileEngine.tileWindows()
        }
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        sender.state = isEnabled ? .on : .off
    }

    @objc private func tileNow() {
        tileEngine.tileWindows()
    }

    @objc private func resetSizes() {
        tileEngine.resetAllSizes()
        tileEngine.tileWindows()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
