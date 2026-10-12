import SwiftUI

/// openfortivpn's output, newest at the bottom.
public struct LogView: View {
  public static let windowID = "forti-log"
  let lines: [String]

  public init(lines: [String]) {
    self.lines = lines
  }

  public var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 2) {
          ForEach(lines.indices, id: \.self) { index in
            Text(lines[index])
              .font(Typeface.mono)
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .id(index)
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
      .onChange(of: lines.count) {
        proxy.scrollTo(lines.count - 1, anchor: .bottom)
      }
    }
    .frame(minWidth: 480, minHeight: 280)
    .background(Brand.paper)
    .foregroundStyle(Brand.ink)
  }
}
