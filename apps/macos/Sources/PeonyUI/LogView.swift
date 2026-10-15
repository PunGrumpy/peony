import SwiftUI

/// One line of a tunnel tool's output. The id stays with the line when older lines are
/// dropped, so trimming the log doesn't make every row look new.
public struct LogLine: Identifiable, Equatable, Sendable {
  public let id: Int
  public let text: String

  public init(id: Int, text: String) {
    self.id = id
    self.text = text
  }
}

/// openfortivpn's output, newest at the bottom.
public struct LogView: View {
  public static let windowID = "forti-log"
  let lines: [LogLine]

  public init(lines: [LogLine]) {
    self.lines = lines
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(lines) { line in
            Text(line.text)
              .font(Typeface.mono)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
          }
        }
        .padding(14)
      }
      .overlay {
        if lines.isEmpty {
          VStack(spacing: 6) {
            Text("No output yet")
              .font(Typeface.display(20))
              .tracking(Typeface.displayTracking(20))
            Text("Connect Forti and openfortivpn's log appears here.")
              .font(Typeface.body)
              .foregroundStyle(Brand.muted)
          }
        }
      }
      // The newest id, not the count: the count stops changing once the log is full.
      .onChange(of: lines.last?.id) { _, newest in
        if let newest { proxy.scrollTo(newest, anchor: .bottom) }
      }
    }
    .frame(minWidth: 480, minHeight: 280)
    .background(Brand.paper)
    .foregroundStyle(Brand.ink)
  }
}
