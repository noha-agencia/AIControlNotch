import Darwin
import Foundation

/// A script runs as the person. Whoever can change the program, a file handed to it, or
/// the folders holding either, decides what runs; such a command is refused.
enum ScriptFileTrust {
    /// Members of `admin` can already act as root, so what only they can change is trusted.
    /// Homebrew's `bin` folder is writable by this group.
    static let adminGroup = gid_t(80)
    static let wheelGroup = gid_t(0)

    /// The first file in `command` that others can change, or `nil`. Parts that are not
    /// existing regular files (flags, names, missing paths) have nothing to check.
    static func firstUnsafe(in command: [String], home: URL) -> String? {
        command.lazy.compactMap { file(named: $0, home: home) }.first { !isTrusted($0) }?.path
    }

    /// Relative parts are read from home, where the script runs.
    private static func file(named part: String, home: URL) -> URL? {
        guard !part.isEmpty else { return nil }
        let url = part.hasPrefix("/") ? URL(fileURLWithPath: part) : home.appendingPathComponent(part)
        var info = stat()
        guard stat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
        return url
    }

    /// The real file, the folder holding it and, behind a symlink, the folder holding the
    /// link: whoever can change that folder can point the link elsewhere.
    private static func isTrusted(_ url: URL) -> Bool {
        let real = url.resolvingSymlinksInPath()
        let folders = Set([url.deletingLastPathComponent().standardizedFileURL.path, real.deletingLastPathComponent().path])
        return isSafe(real.path, isFolder: false) && folders.allSatisfy { isSafe($0, isFolder: true) }
    }

    /// Yours or the system's; group-writable only by admin or wheel; never writable by
    /// everyone, except a sticky folder such as /tmp, where others cannot replace your files.
    private static func isSafe(_ path: String, isFolder: Bool) -> Bool {
        var info = stat()
        guard stat(path, &info) == 0 else { return false }
        let owner = info.st_uid == geteuid() || info.st_uid == 0
        let sticky = isFolder && info.st_mode & mode_t(S_ISVTX) != 0
        let group = info.st_mode & mode_t(S_IWGRP) == 0 || [adminGroup, wheelGroup].contains(info.st_gid) || sticky
        let others = info.st_mode & mode_t(S_IWOTH) == 0 || sticky
        return owner && group && others
    }
}
