import Foundation

/// Why a script provider produced no numbers. Shown in the panel, so it stays language-neutral
/// (`Copy` words it) and never carries the script's own output.
public enum ScriptFailure: Error, Equatable, Sendable {
    /// Missing, not executable, or refused by the system.
    case launch
    /// The program, a file named in its arguments, or their folder can be changed by other users.
    case unsafeFile
    case exit(Int32)
    case timedOut(seconds: Int)
    case tooMuchOutput(kilobytes: Int)
    /// The field at fault, such as `windows[0].usedPercent`.
    case invalidOutput(String)
}
