import AppKit
import SwiftUI

/// Keeps the menu bar panel hanging from the menu bar while its content grows or shrinks.
/// AppKit resizes windows around their bottom edge, so without this a shorter panel
/// (say, Connecting… turning into Connected) slides down and leaves a gap under the bar.
struct PanelAnchor: NSViewRepresentable {
  func makeNSView(context: Context) -> AnchorView { AnchorView() }
  func updateNSView(_ nsView: AnchorView, context: Context) {}

  final class AnchorView: NSView {
    private var top: CGFloat?
    private var observers: [NSObjectProtocol] = []

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observers.forEach(NotificationCenter.default.removeObserver)
      observers = []
      guard let window else { return }
      let center = NotificationCenter.default
      // The system places the panel under its status item each time it opens.
      observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.top = self?.window?.frame.maxY }
      })
      observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.pin() }
      })
      top = window.frame.maxY
    }

    private func pin() {
      guard let window, let top, abs(window.frame.maxY - top) > 0.5 else { return }
      window.setFrameOrigin(NSPoint(x: window.frame.minX, y: top - window.frame.height))
    }
  }
}
