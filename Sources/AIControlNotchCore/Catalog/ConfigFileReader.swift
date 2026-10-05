import Foundation

/// Why a config file was not read, in words for the person.
struct ConfigFileRejected: Error, Equatable {
    let reason: String
}

/// Opens a config file once and checks the open file itself, so it cannot be swapped
/// between the check and the read. A FIFO or device is refused without blocking.
/// Mode bits only: access lists (`chmod +a`) and the folders above the parent are not checked.
enum ConfigFileReader {
    static let othersCanWrite = mode_t(S_IWGRP | S_IWOTH)

    /// The file's bytes, or `nil` when there is no file. `name` is how messages call it.
    static func read(_ url: URL, name: String, maxBytes: Int) throws -> Data? {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOCTTY)
        guard descriptor >= 0 else {
            if errno == ENOENT { return nil }
            throw ConfigFileRejected(reason: "\(name) could not be read")
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var info = stat()
        guard fstat(descriptor, &info) == 0 else { throw ConfigFileRejected(reason: "\(name) could not be read") }
        try check(info, name: name, maxBytes: maxBytes, folders: folders(of: url))
        let data = try handle.read(upToCount: maxBytes + 1) ?? Data()
        guard data.count <= maxBytes else { throw tooLarge(name, maxBytes) }
        return data
    }

    private static func check(_ info: stat, name: String, maxBytes: Int, folders: [URL]) throws {
        guard info.st_mode & S_IFMT == S_IFREG else { throw ConfigFileRejected(reason: "\(name) must be a regular file") }
        guard info.st_uid == geteuid() else { throw ConfigFileRejected(reason: "\(name) must belong to you") }
        guard info.st_mode & othersCanWrite == 0 else {
            throw ConfigFileRejected(reason: "\(name) can be changed by other users; run chmod 600 on it")
        }
        guard info.st_size <= Int64(maxBytes) else { throw tooLarge(name, maxBytes) }
        for folder in folders {
            var folderInfo = stat()
            guard stat(folder.path, &folderInfo) == 0, folderInfo.st_mode & othersCanWrite == 0,
                  folderInfo.st_uid == geteuid() || folderInfo.st_uid == 0 else {
                throw ConfigFileRejected(reason: "the folder of \(name) can be changed by other users")
            }
        }
    }

    private static func tooLarge(_ name: String, _ maxBytes: Int) -> ConfigFileRejected {
        ConfigFileRejected(reason: "\(name) is larger than \(maxBytes / 1_024) KB")
    }

    /// The folder holding the path and, behind a symlink, the one holding the real file.
    private static func folders(of url: URL) -> [URL] {
        let direct = url.deletingLastPathComponent()
        let resolved = url.resolvingSymlinksInPath().deletingLastPathComponent()
        return direct.standardizedFileURL == resolved.standardizedFileURL ? [direct] : [direct, resolved]
    }
}
