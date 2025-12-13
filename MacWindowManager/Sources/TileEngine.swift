import AppKit

struct WindowState: Codable {
    var id: String  // Using bundle ID + window index as identifier
    var units: Int
}

class TileEngine {
    private let windowManager: WindowManager
    private var windowOrder: [String] = []  // Ordered list of window identifiers
    private var windowUnits: [String: Int] = [:]  // Window ID -> unit count
    private let storePath: URL

    init(windowManager: WindowManager) {
        self.windowManager = windowManager

        // Store order in Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MacWindowManager")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        self.storePath = appDir.appendingPathComponent("window-state.json")

        loadState()
    }

    // MARK: - Public Actions

    func tileWindows() {
        let windows = windowManager.getVisibleWindows()
        guard !windows.isEmpty else { return }

        let screenFrame = windowManager.getScreenFrame()

        // Update order: keep existing order for known windows, append new ones
        updateWindowOrder(windows)

        // Calculate total units
        var totalUnits = 0
        for window in windows {
            let id = windowIdentifier(window)
            totalUnits += windowUnits[id] ?? 1
        }

        // Calculate unit width
        let unitWidth = screenFrame.width / CGFloat(totalUnits)

        // Position each window according to order
        var currentX = screenFrame.origin.x
        let orderedWindows = orderWindows(windows)

        for window in orderedWindows {
            let id = windowIdentifier(window)
            let units = windowUnits[id] ?? 1
            let windowWidth = unitWidth * CGFloat(units)

            let frame = CGRect(
                x: currentX,
                y: screenFrame.origin.y,
                width: windowWidth,
                height: screenFrame.height
            )

            windowManager.setWindowFrame(window, frame: frame)
            currentX += windowWidth
        }

        saveState()
    }

    func increaseWidth() {
        guard let focused = windowManager.getFocusedWindow() else { return }
        let id = windowIdentifier(focused)
        let current = windowUnits[id] ?? 1
        windowUnits[id] = current + 1
        tileWindows()
    }

    func decreaseWidth() {
        guard let focused = windowManager.getFocusedWindow() else { return }
        let id = windowIdentifier(focused)
        let current = windowUnits[id] ?? 1
        if current > 1 {
            windowUnits[id] = current - 1
            tileWindows()
        }
    }

    func swapLeft() {
        guard let focused = windowManager.getFocusedWindow() else { return }
        let id = windowIdentifier(focused)

        if let index = windowOrder.firstIndex(of: id), index > 0 {
            windowOrder.swapAt(index, index - 1)
            tileWindows()
        }
    }

    func swapRight() {
        guard let focused = windowManager.getFocusedWindow() else { return }
        let id = windowIdentifier(focused)

        if let index = windowOrder.firstIndex(of: id), index < windowOrder.count - 1 {
            windowOrder.swapAt(index, index + 1)
            tileWindows()
        }
    }

    func resetAllSizes() {
        windowUnits.removeAll()
    }

    // MARK: - Private Helpers

    private func windowIdentifier(_ window: WindowInfo) -> String {
        // Use bundle ID + PID as identifier (persistent across tiles but unique per window)
        return "\(window.app.bundleIdentifier ?? "unknown")-\(window.pid)"
    }

    private func updateWindowOrder(_ windows: [WindowInfo]) {
        let currentIDs = Set(windows.map { windowIdentifier($0) })

        // Remove windows that no longer exist
        windowOrder = windowOrder.filter { currentIDs.contains($0) }

        // Add new windows at their current x position
        let newWindows = windows.filter { !windowOrder.contains(windowIdentifier($0)) }
            .sorted { $0.frame.origin.x < $1.frame.origin.x }

        for window in newWindows {
            let id = windowIdentifier(window)
            windowOrder.append(id)
            windowUnits[id] = 1  // Default to 1 unit
        }
    }

    private func orderWindows(_ windows: [WindowInfo]) -> [WindowInfo] {
        // Return windows sorted by our saved order
        return windows.sorted { window1, window2 in
            let id1 = windowIdentifier(window1)
            let id2 = windowIdentifier(window2)
            let index1 = windowOrder.firstIndex(of: id1) ?? Int.max
            let index2 = windowOrder.firstIndex(of: id2) ?? Int.max
            return index1 < index2
        }
    }

    // MARK: - Persistence

    private func loadState() {
        guard let data = try? Data(contentsOf: storePath),
              let state = try? JSONDecoder().decode(SavedState.self, from: data) else {
            return
        }
        windowOrder = state.order
        windowUnits = state.units
    }

    private func saveState() {
        let state = SavedState(order: windowOrder, units: windowUnits)
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: storePath)
        }
    }

    private struct SavedState: Codable {
        var order: [String]
        var units: [String: Int]
    }
}
