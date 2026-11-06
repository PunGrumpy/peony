import Carbon.HIToolbox
import OSLog
import PeonyCore

/// `⌃⌥⌘1`–`⌃⌥⌘9` and `⌃⌥⌘0`, delivered whichever app is in front.
///
/// Carbon's `RegisterEventHotKey` is the one global hotkey API that needs no Accessibility or Input
/// Monitoring permission, which Peony would otherwise have to ask for. It doesn't report a chord another
/// app holds: both registrations succeed, so Peony can't warn about a clash.
nonisolated final class GlobalShortcuts {
  private static let signature: OSType = 0x5045_4F4E // 'PEON'
  private static let modifiers = UInt32(controlKey | optionKey | cmdKey)
  private static let keyCodes: [UInt32: Int] = [
    0: kVK_ANSI_0, 1: kVK_ANSI_1, 2: kVK_ANSI_2, 3: kVK_ANSI_3, 4: kVK_ANSI_4,
    5: kVK_ANSI_5, 6: kVK_ANSI_6, 7: kVK_ANSI_7, 8: kVK_ANSI_8, 9: kVK_ANSI_9,
  ]

  private let logger = Logger(subsystem: "app.peony", category: "shortcuts")
  private let onPress: @MainActor (GlobalShortcut) -> Void
  private var handler: EventHandlerRef?
  private var retained: Unmanaged<Handler>?
  private var hotKeys: [EventHotKeyRef] = []

  init(onPress: @escaping @MainActor (GlobalShortcut) -> Void) {
    self.onPress = onPress
  }

  deinit {
    disable()
  }

  func enable() {
    disable()
    // Retained until the handler is removed, so a late event can't reach a freed box.
    let box = Unmanaged.passRetained(Handler(onPress))
    retained = box
    var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, info in
      guard let event, let info else { return OSStatus(eventNotHandledErr) }
      var id = EventHotKeyID()
      let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &id)
      guard status == noErr, id.signature == GlobalShortcuts.signature, let shortcut = GlobalShortcut(id: id.id) else {
        return OSStatus(eventNotHandledErr)
      }
      let handler = Unmanaged<Handler>.fromOpaque(info).takeUnretainedValue()
      // Application events arrive on the main thread.
      MainActor.assumeIsolated { handler.onPress(shortcut) }
      return noErr
    }, 1, &type, box.toOpaque(), &handler)
    guard installed == noErr else {
      logger.error("Couldn't listen for global shortcuts: \(installed)")
      disable()
      return
    }

    for shortcut in GlobalShortcut.all {
      var hotKey: EventHotKeyRef?
      let status = RegisterEventHotKey(
        UInt32(Self.keyCodes[shortcut.id]!), Self.modifiers, EventHotKeyID(signature: Self.signature, id: shortcut.id),
        GetApplicationEventTarget(), 0, &hotKey)
      if status == noErr, let hotKey {
        hotKeys.append(hotKey)
      } else {
        logger.error("Couldn't register the shortcut for \(shortcut.id): \(status)")
      }
    }
  }

  func disable() {
    for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
    hotKeys = []
    if let handler { RemoveEventHandler(handler) }
    handler = nil
    retained?.release()
    retained = nil
  }

  private final class Handler: Sendable {
    let onPress: @MainActor (GlobalShortcut) -> Void
    init(_ onPress: @escaping @MainActor (GlobalShortcut) -> Void) { self.onPress = onPress }
  }
}
