import AppKit
import SwiftUI

/// Sizes the menu bar panel to its content and keeps it hanging from the menu bar.
/// The system grows the panel's window when the content grows but doesn't shrink it,
/// so a shorter panel (say, an error turning into Connected) sat centered in the old
/// height, with a gap under the bar.
struct PanelAnchor: NSViewRepresentable {
  func makeNSView(context: Context) -> AnchorView { AnchorView() }
  func updateNSView(_ nsView: AnchorView, context: Context) {}

  /// Drawn behind the panel, so its frame is the content's size.
  final class AnchorView: NSView {
    private var observer: NSObjectProtocol?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      observer.map(NotificationCenter.default.removeObserver)
      observer = window.map { window in
        NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.fit() }
        }
      }
      fit()
    }

    override func setFrameSize(_ newSize: NSSize) {
      super.setFrameSize(newSize)
      DispatchQueue.main.async { [weak self] in self?.fit() }
    }

    private func fit() {
      guard let window, frame.height > 0 else { return }
      let content = window.contentRect(forFrameRect: window.frame)
      guard abs(content.height - frame.height) > 0.5 else { return }
      let top = window.frame.maxY
      var target = window.frameRect(forContentRect: NSRect(x: content.minX, y: content.minY, width: content.width, height: frame.height))
      target.origin.y = top - target.height
      window.setFrame(target, display: true)
    }
  }
}
