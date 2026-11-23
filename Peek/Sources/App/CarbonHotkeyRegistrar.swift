import Carbon
import Foundation

/// Live Carbon implementation of `HotkeyRegistering`. Installs the hot-key event
/// handler once at construction and re-registers the key combination on demand,
/// unregistering any previous binding first. This is the only place that touches
/// Carbon's hot-key API.
final class CarbonHotkeyRegistrar: HotkeyRegistering {
    /// Each registrar owns one shortcut; the handler ignores the others' presses.
    private let hotKeyID: UInt32

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let handler: () -> Void
    private let signature = OSType("PEEK".fourCharCodeValue)

    init(id: UInt32 = 1, handler: @escaping () -> Void) {
        self.hotKeyID = id
        self.handler = handler
        installEventHandler()
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
                var pressed = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressed
                )
                guard status == noErr, pressed.signature == registrar.signature, pressed.id == registrar.hotKeyID else {
                    return OSStatus(eventNotHandledErr)
                }
                registrar.handler()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32) -> OSStatus {
        unregister()
        let hotKeyID = EventHotKeyID(signature: signature, id: self.hotKeyID)
        return RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}

extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        if let data = self.data(using: .macOSRoman) {
            data.withUnsafeBytes { bytes in
                let pointer = bytes.bindMemory(to: UInt8.self)
                for i in 0..<min(4, data.count) {
                    result = result << 8 + FourCharCode(pointer[i])
                }
            }
        }
        return result
    }
}
