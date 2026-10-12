import Foundation

public enum TunnelState: Equatable, Sendable {
  case off
  case connecting
  case disconnecting
  case on(address: String)
  case failed(TunnelFailure)

  /// Whether this tunnel is up, or on its way up.
  public var wantsOn: Bool {
    switch self {
    case .connecting, .on: true
    case .off, .disconnecting, .failed: false
    }
  }

  public var isBusy: Bool {
    switch self {
    case .connecting, .disconnecting: true
    case .off, .on, .failed: false
    }
  }

  public var address: String? {
    if case .on(let address) = self { address } else { nil }
  }

  public var failure: TunnelFailure? {
    if case .failed(let failure) = self { failure } else { nil }
  }
}

public struct TunnelFailure: Equatable, Sendable {
  public var message: String
  /// The one thing most likely to fix it, offered as the primary button.
  public var fix: Fix?

  public init(message: String, fix: Fix? = nil) {
    self.message = message
    self.fix = fix
  }

  public enum Fix: Equatable, Sendable {
    /// Peony's root helper is missing or out of date.
    case installHelper
    /// A Homebrew formula is missing; `command` installs it.
    case installTool(name: String, command: String)
    /// The server's certificate isn't trusted; offer to trust this pin.
    case trustCertificate(pin: String)
    /// Something in the profile needs changing.
    case editProfile

    public var title: String {
      switch self {
      case .installHelper: "Install helper"
      case .installTool(let name, _): "Install \(name)"
      case .trustCertificate: "Trust this server"
      case .editProfile: "Edit VPN"
      }
    }
  }
}
