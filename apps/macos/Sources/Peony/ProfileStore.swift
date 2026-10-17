import Foundation
import Observation
import OSLog
import PeonyCore

/// The user's VPNs, saved as JSON in Application Support. Secrets go to the Keychain.
@Observable
final class ProfileStore {
  private(set) var profiles: [Profile] = []

  @ObservationIgnored private let url: URL
  @ObservationIgnored private let logger = Logger(subsystem: "app.peony", category: "profiles")

  init(directory: URL = URL.applicationSupportDirectory.appending(path: "Peony")) {
    url = directory.appending(path: "profiles.json")
    load()
  }

  func profile(_ id: UUID) -> Profile? {
    profiles.first { $0.id == id }
  }

  func save(_ profile: Profile, secret: String?, openVPNPassword: String? = nil) {
    if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
      profiles[index] = profile
    } else {
      profiles.append(profile)
    }
    if let secret { Keychain.setSecret(secret, for: profile.id, label: "Peony: \(profile.name)") }
    if let openVPNPassword { Keychain.setSecret(openVPNPassword, for: profile.id, .openVPNPassword, label: "Peony: \(profile.name) password") }
    write()
  }

  func delete(_ id: UUID) {
    profiles.removeAll { $0.id == id }
    Keychain.deleteSecret(for: id)
    Keychain.deleteSecret(for: id, .openVPNPassword)
    write()
  }

  func move(from source: IndexSet, to destination: Int) {
    profiles.move(fromOffsets: source, toOffset: destination)
    write()
  }

  private func load() {
    guard let data = try? Data(contentsOf: url) else { return }
    do {
      profiles = try JSONDecoder().decode([Profile].self, from: data)
    } catch {
      logger.error("Couldn't read profiles: \(error.localizedDescription, privacy: .public)")
      // Saving would replace the user's VPNs with an empty list, so keep the file for them to recover.
      let stamp = Int(Date.now.timeIntervalSince1970)
      let aside = url.deletingLastPathComponent().appending(path: "profiles-unreadable-\(stamp).json")
      do {
        try FileManager.default.moveItem(at: url, to: aside)
        logger.error("Moved the unreadable profiles to \(aside.path, privacy: .public)")
      } catch {
        logger.error("Couldn't move the unreadable profiles aside: \(error.localizedDescription, privacy: .public)")
      }
    }
  }

  private func write() {
    do {
      try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      try encoder.encode(profiles).write(to: url, options: .atomic)
    } catch {
      logger.error("Couldn't save profiles: \(error.localizedDescription, privacy: .public)")
    }
  }
}
