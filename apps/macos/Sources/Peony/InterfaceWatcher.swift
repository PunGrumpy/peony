import SystemConfiguration

/// Calls back when an interface appears, goes away or changes its IPv4 address. configd
/// pushes these, so Peony notices tunnels coming and going without waking up to look.
nonisolated final class InterfaceWatcher {
  private let store: SCDynamicStore?

  init(onChange: @escaping @MainActor () -> Void) {
    // The store retains the handler through `info` and releases it with the store,
    // so a late callback can't reach a freed object.
    let handler = Handler(onChange)
    var context = SCDynamicStoreContext(
      version: 0,
      info: Unmanaged.passUnretained(handler).toOpaque(),
      retain: { info in UnsafeRawPointer(Unmanaged<Handler>.fromOpaque(info).retain().toOpaque()) },
      release: { info in Unmanaged<Handler>.fromOpaque(info).release() },
      copyDescription: nil)
    store = withExtendedLifetime(handler) {
      SCDynamicStoreCreate(nil, "app.peony" as CFString, { _, _, info in
        guard let info else { return }
        let handler = Unmanaged<Handler>.fromOpaque(info).takeUnretainedValue()
        MainActor.assumeIsolated { handler.onChange() }
      }, &context)
    }
    guard let store else { return }

    let list = SCDynamicStoreKeyCreateNetworkInterface(nil, kSCDynamicStoreDomainState)
    let ipv4 = SCDynamicStoreKeyCreateNetworkInterfaceEntity(nil, kSCDynamicStoreDomainState, kSCCompAnyRegex, kSCEntNetIPv4)
    SCDynamicStoreSetNotificationKeys(store, [list] as CFArray, [ipv4] as CFArray)
    // Main queue, so the callback above may assume the main actor.
    SCDynamicStoreSetDispatchQueue(store, .main)
  }

  deinit {
    if let store { SCDynamicStoreSetDispatchQueue(store, nil) }
  }

  private final class Handler: Sendable {
    let onChange: @MainActor () -> Void
    init(_ onChange: @escaping @MainActor () -> Void) { self.onChange = onChange }
  }
}
