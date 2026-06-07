import Carbon.HIToolbox
import Foundation

protocol HotKeyRegistering {
    func register(onFire: @escaping () -> Void) throws
    func unregister()
}

enum HotKeyRegistrationError: LocalizedError, Equatable {
    case eventHandlerInstallFailed(OSStatus)
    case hotKeyRegistrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .eventHandlerInstallFailed(let status):
            "Could not install the Shade_ shortcut handler. Carbon status: \(status)."
        case .hotKeyRegistrationFailed(let status):
            "Could not register Cmd + Opt + Shift + S. Carbon status: \(status)."
        }
    }
}

final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private let hotKeyID = EventHotKeyID(signature: fourCharCode("SHDE"), id: 1)
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private var onFire: (() -> Void)?

    func register(onFire: @escaping () -> Void) throws {
        unregister()
        self.onFire = onFire

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard handlerStatus == noErr else {
            self.onFire = nil
            throw HotKeyRegistrationError.eventHandlerInstallFailed(handlerStatus)
        }

        var registeredHotKey: EventHotKeyRef?
        let registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(cmdKey | optionKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &registeredHotKey
        )
        guard registrationStatus == noErr else {
            unregister()
            throw HotKeyRegistrationError.hotKeyRegistrationFailed(registrationStatus)
        }

        hotKey = registeredHotKey
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        onFire = nil
    }

    private func fire() {
        onFire?()
    }

    private static let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return noErr
        }

        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr else {
            return status
        }

        let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
        guard hotKeyID.signature == registrar.hotKeyID.signature, hotKeyID.id == registrar.hotKeyID.id else {
            return noErr
        }

        registrar.fire()
        return noErr
    }
}

final class KeyboardShortcutController {
    var onDisable: (() -> Void)?
    private let registrar: HotKeyRegistering
    private var isStarted = false

    init(registrar: HotKeyRegistering = CarbonHotKeyRegistrar()) {
        self.registrar = registrar
    }

    func start() throws {
        guard !isStarted else { return }
        try registrar.register { [weak self] in
            self?.onDisable?()
        }
        isStarted = true
    }

    func stop() {
        guard isStarted else { return }
        registrar.unregister()
        isStarted = false
    }
}

private func fourCharCode(_ string: StaticString) -> OSType {
    var result: UInt32 = 0
    for character in string.description.utf8 {
        result = (result << 8) + UInt32(character)
    }
    return result
}
