import AppKit
import SwiftUI

/// Keeps the menu bar panel hanging from the menu bar while its content grows or shrinks.
/// AppKit resizes windows around their bottom edge, so without this a shorter panel
/// (say, Connecting… turning into Connected) slides down and leaves a gap under the bar.
struct PanelAnchor: NSViewRepresentable {
  func makeNSView(context: Context) -> AnchorView { AnchorView() }
  func updateNSView(_ nsView: AnchorView, context: Context) {}

  final class AnchorView: NSView {
    private var last: NSRect?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      guard let window else { return }
      let center = NotificationCenter.default
      observers.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.last = self?.window?.frame }
      })
      observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.pin() }
      })
      last = window.frame
    }

    /// Only a resize that kept the bottom edge is AppKit's doing. When the bottom moved too,
    /// the system placed the panel under its status item, and that placement wins.
    private func pin() {
      guard let window else { return }
      if let last, window.frame.minY == last.minY, abs(window.frame.maxY - last.maxY) > 0.5 {
        window.setFrameOrigin(NSPoint(x: window.frame.minX, y: last.maxY - window.frame.height))
      }
      last = window.frame
    }
  }
}
