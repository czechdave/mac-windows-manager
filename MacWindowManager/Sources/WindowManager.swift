import AppKit
import ApplicationServices

struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let axWindow: AXUIElement
    let app: NSRunningApplication
    var frame: CGRect
    let title: String
}

class WindowManager {
    private let systemWideElement = AXUIElementCreateSystemWide()

    // Get the currently focused window
    func getFocusedWindow() -> WindowInfo? {
        var focusedApp: AnyObject?
        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard let appElement = focusedApp else { return nil }

        var focusedWindow: AnyObject?
        AXUIElementCopyAttributeValue(appElement as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard let windowElement = focusedWindow else { return nil }

        return windowInfoFromAXElement(windowElement as! AXUIElement)
    }

    // Get all visible windows on the current screen/space
    func getVisibleWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []

        // Get window list from CGWindowListCopyWindowInfo
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

            // Get AX element for this window
            if let axWindow = getAXWindowForPID(pid, windowID: windowID) {
                let frame = CGRect(
                    x: boundsDict["X"] ?? 0,
                    y: boundsDict["Y"] ?? 0,
                    width: width,
                    height: height
                )

                let title = windowDict[kCGWindowName as String] as? String ?? ""

                windows.append(WindowInfo(
                    id: windowID,
                    pid: pid,
                    axWindow: axWindow,
                    app: app,
                    frame: frame,
                    title: title
                ))
            }
        }

        // Sort by x position (left to right)
        windows.sort { $0.frame.origin.x < $1.frame.origin.x }

        return windows
    }

    // Get the main screen's visible frame (excluding menu bar and dock)
    func getScreenFrame() -> CGRect {
        guard let screen = NSScreen.main else {
            return CGRect(x: 0, y: 0, width: 1920, height: 1080)
        }
        return screen.visibleFrame
    }

    // Move and resize a window
    func setWindowFrame(_ window: WindowInfo, frame: CGRect) {
        // Convert from screen coordinates (origin bottom-left) to AX coordinates (origin top-left)
        guard let screen = NSScreen.main else { return }
        let screenHeight = screen.frame.height

        let axY = screenHeight - frame.origin.y - frame.height

        var position = CGPoint(x: frame.origin.x, y: axY)
        var size = CGSize(width: frame.width, height: frame.height)

        var positionValue: AnyObject?
        var sizeValue: AnyObject?

        // Create CFValues
        positionValue = AXValueCreate(.cgPoint, &position)
        sizeValue = AXValueCreate(.cgSize, &size)

        // Set position first, then size
        if let posVal = positionValue {
            AXUIElementSetAttributeValue(window.axWindow, kAXPositionAttribute as CFString, posVal)
        }
        if let sizeVal = sizeValue {
            AXUIElementSetAttributeValue(window.axWindow, kAXSizeAttribute as CFString, sizeVal)
        }
    }

    // MARK: - Private helpers

    private func getAXWindowForPID(_ pid: pid_t, windowID: CGWindowID) -> AXUIElement? {
        let appElement = AXUIElementCreateApplication(pid)

        var windowsRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        guard result == .success, let windows = windowsRef as? [AXUIElement] else {
            return nil
        }

        // Try to match by position/size since we can't directly get window ID from AX
        // Return the first window (usually the main one)
        return windows.first
    }

    private func windowInfoFromAXElement(_ element: AXUIElement) -> WindowInfo? {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }

        // Get position
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

        // Convert AX coordinates to screen coordinates
        guard let screen = NSScreen.main else { return nil }
        let screenHeight = screen.frame.height
        let screenY = screenHeight - position.y - size.height

        let frame = CGRect(x: position.x, y: screenY, width: size.width, height: size.height)

        return WindowInfo(
            id: 0,  // We don't have the CGWindowID here
            pid: pid,
            axWindow: element,
            app: app,
            frame: frame,
            title: title
        )
    }
}
