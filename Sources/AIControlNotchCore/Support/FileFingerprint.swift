import Darwin
import Foundation

/// What identifies one version of a file on disk. Permissions and the change time are part
/// of it, the folder's too, so fixing either with `chmod` counts as a change, as does
/// swapping in another file.
public struct FileFingerprint: Equatable, Sendable {
    let device: Int32
    let inode: UInt64
    let mode: UInt16
    let owner: UInt32
    let size: Int64
    let modified: [Int]
    let changed: [Int]
    /// Mode and owner of the folder holding the file.
    let folder: [UInt32]

    /// Follows a symlink, so editing a dotfile target counts as a change.
    init?(of url: URL) {
        var info = stat()
        guard stat(url.path, &info) == 0 else { return nil }
        device = info.st_dev
        inode = info.st_ino
        mode = info.st_mode
        owner = info.st_uid
        size = info.st_size
        modified = [info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec]
        changed = [info.st_ctimespec.tv_sec, info.st_ctimespec.tv_nsec]
        var folderInfo = stat()
        let found = stat(url.deletingLastPathComponent().path, &folderInfo) == 0
        folder = found ? [UInt32(folderInfo.st_mode), folderInfo.st_uid] : []
    }
}
