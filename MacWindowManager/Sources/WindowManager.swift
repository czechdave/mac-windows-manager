import AppKit
import ApplicationServices

struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let axWindow: AXUIElement
    let app: NSRunningApplication
    var frame: CGRect  // In CG/AX coordinates (top-left origin)
    let title: String
}

class WindowManager {
    private let systemWideElement = AXUIElementCreateSystemWide()

    // Get the currently focused window
    func getFocusedWindow() -> WindowInfo? {
        var focusedApp: AnyObject?
        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard let appElement = focusedApp else {
            NSLog("WindowManager: No focused app")
            return nil
        }

        var focusedWindow: AnyObject?
        AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard let windowElement = focusedWindow else {
            NSLog("WindowManager: No focused window")
            return nil
        }

        return windowInfoFromAXElement(windowElement as! AXUIElement)
    }

    // Get all visible windows on the current screen/space
    func getVisibleWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        // Get window list from CGWindowListCopyWindowInfo
        // CG coordinates use top-left origin (same as AX)
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return windows
        }

        for windowDict in windowList {
            guard let windowID = windowDict[kCGWindowNumber as String] as? CGWindowID,
                  let pid = windowDict[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = windowDict[kCGWindowLayer as String] as? Int,
                  layer == 0,  // Normal window layer
                  let boundsDict = windowDict[kCGWindowBounds as String] as? [String: CGFloat],
                  let app = NSRunningApplication(processIdentifier: pid),
                  !app.isHidden,
                  app.activationPolicy == .regular  // Filter out background apps
            else { continue }

            // Skip windows that are too small (likely not real windows)
            let width = boundsDict["Width"] ?? 0
            let height = boundsDict["Height"] ?? 0
            if width < 100 || height < 100 { continue }

            // CG frame (top-left origin, same as AX)
            let cgFrame = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: width,
                height: height
            )

            // Get AX element for this specific window by matching frame
            if let axWindow = getAXWindowByFrame(pid: pid, cgFrame: cgFrame) {
                let title = windowDict[kCGWindowName as String] as? String ?? ""

                windows.append(WindowInfo(
                    id: windowID,
                    pid: pid,
                    axWindow: axWindow,
                    app: app,
                    frame: cgFrame,
                    title: title
                ))
            }
        }

        // Sort by x position (left to right)
        windows.sort { $0.frame.origin.x < $1.frame.origin.x }

        return windows
    }

    // Get the screen frame for tiling (uses focused window to determine which screen)
    // Returns frame in CG/AX coordinates (top-left origin)
    func getScreenFrame() -> CGRect {
        // Get the focused window to determine which screen we're on
        if let focused = getFocusedWindow() {
            // Find the screen containing this window
            let windowCenter = CGPoint(
                x: focused.frame.midX,
                y: focused.frame.midY
            )

            // Get display bounds using CG (which uses top-left origin like AX)
            var displayCount: UInt32 = 0
            var displayID: CGDirectDisplayID = 0
            CGGetDisplaysWithPoint(windowCenter, 1, &displayID, &displayCount)

            if displayCount > 0 {
                let displayBounds = CGDisplayBounds(displayID)
                // Account for menu bar (approximately 25 pixels)
                let menuBarHeight: CGFloat = 25
                return CGRect(
                    x: displayBounds.origin.x,
                    y: displayBounds.origin.y + menuBarHeight,
                    width: displayBounds.width,
                    height: displayBounds.height - menuBarHeight
                )
            }
        }

        // Fallback: use main display
        let mainDisplay = CGMainDisplayID()
        let bounds = CGDisplayBounds(mainDisplay)
        let menuBarHeight: CGFloat = 25
        return CGRect(
            x: bounds.origin.x,
            y: bounds.origin.y + menuBarHeight,
            width: bounds.width,
            height: bounds.height - menuBarHeight
        )
    }

    // Move and resize a window
    func setWindowFrame(_ window: WindowInfo, frame: CGRect) {
        var position = CGPoint(x: frame.origin.x, y: frame.origin.y)
        var size = CGSize(width: frame.width, height: frame.height)

        NSLog("WindowManager: Setting \(window.app.localizedName ?? "?") to pos=(\(Int(position.x)), \(Int(position.y))) size=(\(Int(size.width))x\(Int(size.height)))")

        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        positionValue = AXValueCreate(.cgPoint, &position)
        sizeValue = AXValueCreate(.cgSize, &size)

        // Set size first (some apps work better this way)
        if let sizeVal = sizeValue {
            let result = AXUIElementSetAttributeValue(window.axWindow, kAXSizeAttribute as CFString, sizeVal)
            if result != .success {
                NSLog("WindowManager: Set size failed: \(result.rawValue)")
            }
        }

        // Then set position
        if let posVal = positionValue {
            let result = AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, posVal)
            if result != .success {
                NSLog("WindowManager: Set position failed: \(result.rawValue)")
            }
        }
    }

    // MARK: - Private helpers

    // Find the AXUIElement that matches a specific CG frame
    private func getAXWindowByFrame(pid: pid_t, cgFrame: CGRect) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return nil
        }

        // Find the window whose AX frame matches the CG frame
        for axWindow in windows {
            var posValue: AnyObject?
            var sizeValue: AnyObject?

            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &posValue)
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)

            guard let posVal = posValue, let sizeVal = sizeValue else { continue }

            var axPos = CGPoint.zero
            var axSize = CGSize.zero
            AXValueGetValue(posVal as! AXValue, .cgPoint, &axPos)
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &axSize)

            // Compare with tolerance (window frames can differ by a few pixels)
            let tolerance: CGFloat = 10
            if abs(axPos.x - cgFrame.origin.x) < tolerance &&
               abs(axPos.y - cgFrame.origin.y) < tolerance &&
               abs(axSize.width - cgFrame.width) < tolerance &&
               abs(axSize.height - cgFrame.height) < tolerance {
                return axWindow
            }
        }

        // If no exact match, return first window (fallback)
        return windows.first
    }

    private func windowInfoFromAXElement(_ element: AXUIElement) -> WindowInfo? {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }

        // Get position (AX uses top-left origin, same as CG)
        var positionValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        var position = CGPoint.zero
        if let posVal = positionValue {
            AXValueGetValue(posVal as! AXValue, .cgPoint, &position)
        }

        // Get size
        var sizeValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)
        var size = CGSize.zero
        if let sizeVal = sizeValue {
            AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
        }

        // Get title
        var titleValue: AnyObject?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        let title = titleValue as? String ?? ""

        // Frame is already in CG/AX coordinates
        let frame = CGRect(x: position.x, y: position.y, width: size.width, height: size.height)

        return WindowInfo(
            id: 0,
            pid: pid,
            axWindow: element,
            app: app,
            frame: frame,
            title: title
        )
    }
}
