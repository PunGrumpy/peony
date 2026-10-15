import AppKit
import Foundation
import PeonyCore

/// Installs peony-helper as root, plus a sudoers rule that lets this user run it
/// without a password. One admin prompt, the same pattern Afterhours uses for pmset.
enum HelperInstaller {
  enum Status: Equatable {
    case installed
    case outdated
    case missing
  }

  /// Asks the installed helper its version, which runs a process, so it's async.
  static func status() async -> Status {
    guard FileManager.default.fileExists(atPath: Helper.sudoersPath),
          FileManager.default.isExecutableFile(atPath: Helper.installedPath)
    else { return .missing }
    // `version` is the one command the helper answers without root.
    let output = (try? await Command.run(Helper.installedPath, "version"))?.text ?? ""
    return output.trimmingCharacters(in: .whitespacesAndNewlines) == Helper.version ? .installed : .outdated
  }

  static var bundledHelper: String? {
    Bundle.main.url(forAuxiliaryExecutable: "peony-helper")?.path
      ?? Bundle.main.bundleURL.appending(path: "Contents/Helpers/peony-helper").path
  }

  static func install() throws {
    guard let source = bundledHelper, FileManager.default.isExecutableFile(atPath: source) else {
      throw InstallError("Peony's helper is missing from the app bundle. Reinstall Peony.")
    }
    let user = NSUserName()
    guard !user.isEmpty, user.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }) else {
      throw InstallError("Peony can't install its helper for the account name \"\(user)\".")
    }
    let rule = "\(user) ALL=(root) NOPASSWD: \(Helper.installedPath)"
    // Root copies the helper and writes the rule from its own temp file, so nothing running
    // as the user can swap either between the check and the install.
    let shell = """
    set -e; /bin/mkdir -p /Library/PrivilegedHelperTools; \
    /usr/bin/install -m 0755 -o root -g wheel '\(source)' \(Helper.installedPath); \
    t="$(/usr/bin/mktemp /tmp/peony.sudoers.XXXXXX)"; trap '/bin/rm -f "$t"' EXIT; \
    /bin/echo '\(rule)' > "$t"; /usr/sbin/visudo -cf "$t"; \
    /usr/bin/install -m 0440 -o root -g wheel "$t" \(Helper.sudoersPath)
    """
    try runAsAdmin(shell)
  }

  static func uninstall() throws {
    try runAsAdmin("/bin/rm -f \(Helper.sudoersPath) \(Helper.installedPath); /bin/rm -rf \(Helper.runDirectory)")
  }

  struct InstallError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
  }

  private static func runAsAdmin(_ shell: String) throws {
    let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let source = "do shell script \"\(escaped)\" with prompt \"Peony needs to install a small helper to manage VPN routes.\" with administrator privileges"
    var error: NSDictionary?
    NSAppleScript(source: source)?.executeAndReturnError(&error)
    if let error {
      throw InstallError(error[NSAppleScript.errorMessage] as? String ?? "The admin command failed.")
    }
  }

}
