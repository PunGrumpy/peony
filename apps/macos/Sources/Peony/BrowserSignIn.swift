import AppKit
import WebKit

/// A window that signs in to a FortiGate through its SAML page (Microsoft Entra and the like) and
/// hands back the session cookie. It uses WebKit's persistent data store, so the identity provider's
/// session survives between connects and MFA isn't asked every time.
final class BrowserSignIn: NSObject {
  private static let cookieName = "SVPNCOOKIE"

  private var window: NSWindow?
  private var webView: WKWebView?
  private var host = ""
  private var waiter: CheckedContinuation<String?, Never>?

  var isOpen: Bool { window != nil }

  /// Shows the sign-in page and waits for the gateway's cookie. Nil if the window is closed first.
  func cookie(from url: URL, host: String) async -> String? {
    cancel()
    self.host = host
    let store = WKWebsiteDataStore.default().httpCookieStore
    // A cookie left from an earlier session would pass for a fresh sign-in.
    for stale in await store.allCookies() where matches(stale) { await store.deleteCookie(stale) }

    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .default()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = self
    store.add(self)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 720),
      styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
    window.title = "Sign in to \(host)"
    window.contentView = webView
    window.isReleasedWhenClosed = false
    window.delegate = self
    window.center()
    self.window = window
    self.webView = webView

    return await withCheckedContinuation { continuation in
      waiter = continuation
      webView.load(URLRequest(url: url))
      focus()
    }
  }

  func focus() {
    NSApp.activate()
    window?.makeKeyAndOrderFront(nil)
  }

  /// Closes the window without a cookie.
  func cancel() {
    finish(nil)
  }

  private func finish(_ cookie: String?) {
    guard let waiter else { return }
    self.waiter = nil
    WKWebsiteDataStore.default().httpCookieStore.remove(self)
    webView?.navigationDelegate = nil
    window?.delegate = nil
    window?.close()
    window = nil
    webView = nil
    waiter.resume(returning: cookie)
  }

  private func matches(_ cookie: HTTPCookie) -> Bool {
    let domain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
    return cookie.name == Self.cookieName && (host == domain || host.hasSuffix("." + domain))
  }

  private func checkForCookie() {
    Task {
      let cookies = await WKWebsiteDataStore.default().httpCookieStore.allCookies()
      if let found = cookies.first(where: { matches($0) && !$0.value.isEmpty }) { finish(found.value) }
    }
  }
}

extension BrowserSignIn: WKHTTPCookieStoreObserver {
  func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
    checkForCookie()
  }
}

extension BrowserSignIn: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    checkForCookie()
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
    let nsError = error as NSError
    guard nsError.code != NSURLErrorCancelled else { return }
    let message = nsError.localizedDescription
      .replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
    webView.loadHTMLString("<body style='font:14px -apple-system;padding:2em'><p>Couldn't load the sign-in page.</p><p>\(message)</p>", baseURL: nil)
  }
}

extension BrowserSignIn: NSWindowDelegate {
  func windowWillClose(_ notification: Notification) {
    finish(nil)
  }
}
