import Foundation
import OSLog
import PeonyCore
import PeonyUI

/// The app's side of `peony`: the one door automation gets into the running app.
///
/// It reads status and asks `AppModel` to connect or disconnect, exactly as a click in the menu
/// would, then waits for the tunnel to settle before it replies. It never touches `Connection`
/// directly, never applies a `TunnelFailure.Fix`, and never edits a profile: those stay behind the UI.
final class ControlServer {
  private unowned let model: AppModel
  private var listener: ControlListener?
  private let logger = Logger(subsystem: "app.peony", category: "control")
  private static let tick: Duration = .milliseconds(250)

  init(model: AppModel) {
    self.model = model
  }

  /// Stays off, with a log line, when another Peony already answers `peony` or the path is too long.
  func start() {
    guard let path = Control.socketPath() else {
      logger.error("The control socket's path is too long for macOS, so `peony` can't reach this app")
      return
    }
    do {
      listener = try ControlSocket.serve(at: path) { [weak self] request in
        await self?.handle(request) ?? .refused(.notRunning)
      }
      logger.info("Answering `peony` at \(path, privacy: .public)")
    } catch .inUse {
      logger.notice("Another Peony already answers `peony` at \(path, privacy: .public), so this one doesn't")
    } catch {
      logger.error("Couldn't open the control socket at \(path, privacy: .public): \(String(describing: error), privacy: .public)")
    }
  }

  func stop() {
    listener?.close()
    listener = nil
  }

  /// The UserDefaults key behind Settings › Agents › "Let agents control Peony". Read on every
  /// request, so turning it off, in Settings or with `defaults write`, applies to the next one.
  static let enabledKey = "agentControl"

  private func handle(_ request: ControlRequest) async -> ControlReply {
    guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return .refused(.disabled) }
    switch request {
    case .status:
      return .answered(.done, snapshot)
    case .connect(let query, let wait):
      switch ControlPolicy.resolve(query, among: snapshot.vpns) {
      case .failure(let refusal):
        return .refused(refusal)
      case .success(let id):
        let reply = await run(.up(id), within: wait)
        logger.info("`peony connect` ended with exit \(reply.exitCode)")
        return reply
      }
    case .disconnect(let wait):
      let reply = await run(.down, within: wait)
      logger.info("`peony disconnect` ended with exit \(reply.exitCode)")
      return reply
    }
  }

  /// Acts if the tunnel needs it, then waits for `ControlPolicy.outcome` or the deadline. Polling
  /// runs only while a client waits, and avoids re-registering observation on every change.
  private func run(_ goal: ControlPolicy.Goal, within limit: WaitLimit) async -> ControlReply {
    let deadline = ContinuousClock.now + limit.duration
    var started: Task<Void, Never>?
    planning: while true {
      switch ControlPolicy.plan(goal, snapshot.tunnel) {
      case .done:
        return .answered(.done, snapshot)
      case .join:
        break planning
      case .start:
        started = switch goal {
        case .up(let id): model.connect(id)
        case .down: model.disconnect()
        }
        break planning
      case .waitForOff:
        guard ContinuousClock.now < deadline else { return .answered(.timedOut, snapshot) }
        try? await Task.sleep(for: Self.tick)
      }
    }

    let intent = model.intent
    // Until this request's own connect or disconnect has run, the tunnel still shows what came before it.
    let begun = Flag(started == nil)
    if let started {
      Task {
        await started.value
        begun.value = true
      }
    }
    while true {
      let replaced = model.intent != intent
      if begun.value || replaced, let outcome = ControlPolicy.outcome(goal, snapshot.tunnel, replaced: replaced) {
        return .answered(outcome, snapshot)
      }
      guard ContinuousClock.now < deadline else { return .answered(.timedOut, snapshot) }
      try? await Task.sleep(for: Self.tick)
    }
  }

  /// Built from the same live state the panel reads, at the moment of asking.
  private var snapshot: ControlSnapshot {
    let profiles = model.store.profiles
    let connection = model.connection
    let vpn = connection.profileID.map { id in
      ControlSnapshot.VPNRef(id: id, name: profiles.first { $0.id == id }?.name ?? "Removed VPN")
    }
    return ControlSnapshot(
      tunnel: ControlSnapshot.Tunnel(
        connection.state, vpn: vpn, since: connection.since, signingIn: connection.isSigningIn,
        destinations: model.destinations),
      vpns: profiles.map(ControlSnapshot.VPN.init))
  }

  private final class Flag {
    var value: Bool

    init(_ value: Bool) {
      self.value = value
    }
  }
}

extension ControlSnapshot.Tunnel {
  /// The only place the app's tunnel types meet the control types. Every switch is exhaustive, so a
  /// new state or fix fails the build here instead of leaking a certificate pin or going missing.
  init(_ state: TunnelState, vpn: ControlSnapshot.VPNRef?, since: Date?, signingIn: Bool, destinations: [DestinationStatus]) {
    // Connection names its profile before it leaves .off, so a tunnel without one is off.
    guard let vpn else {
      self = .off
      return
    }
    switch state {
    case .off:
      self = .off
    case .connecting:
      self = .connecting(vpn, signingIn: signingIn)
    case .disconnecting:
      self = .disconnecting(vpn)
    case .on(let address):
      let hosts = destinations.map { destination in
        let status: ControlSnapshot.Host.Status = switch destination.reachability {
        case .checking: .checking
        case .reachable(let milliseconds): .reachable(milliseconds: milliseconds)
        case .unreachable: .unreachable
        }
        return ControlSnapshot.Host(host: destination.host, status: status)
      }
      self = .on(vpn, address: address.isEmpty ? nil : address, since: since, hosts: hosts)
    case .failed(let failure):
      // The pin stays behind: trusting a server is only ever a confirmed choice in the app.
      let fix = failure.fix.map { fix in
        switch fix {
        case .installHelper: ControlSnapshot.Fix(kind: .installHelper, title: fix.title)
        case .installTool(_, let command): ControlSnapshot.Fix(kind: .installTool, title: fix.title, command: command)
        case .trustCertificate: ControlSnapshot.Fix(kind: .trustCertificate, title: fix.title)
        case .editProfile: ControlSnapshot.Fix(kind: .editProfile, title: fix.title)
        }
      }
      self = .failed(vpn, ControlSnapshot.Failure(message: failure.message, fix: fix))
    }
  }
}
