import Carbon
import AppKit

class HotkeyManager {
    private var hotkeys: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1
    private var hotkeyRefs: [EventHotKeyRef] = []

    init() {
        installEventHandler()
    }

    deinit {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1

        hotkeys[id] = handler

        let hotkeyID = EventHotKeyID(signature: OSType(0x4D574D_00), id: id)  // "MWM\0"
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            hotkeyRefs.append(ref)
            print("Registered hotkey \(id): keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerRef = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handleHotKeyEvent(event!)
            },
            1,
            &eventType,
            handlerRef,
            nil
        )
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
        var hotkeyID = EventHotKeyID()

        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        if status == noErr {
            if let handler = hotkeys[hotkeyID.id] {
                DispatchQueue.main.async {
                    handler()
                }
                return noErr
            }
        }

        return OSStatus(eventNotHandledErr)
    }
}
