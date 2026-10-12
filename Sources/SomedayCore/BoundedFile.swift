import Foundation
import Darwin

public enum BoundedFile {
    /// Do not trust a stale or attacker-controlled file-size attribute.
    public static func read(_ url: URL, limit: Int = DrawAuthority.maximumArchiveBytes) throws -> Data {
        guard limit > 0, limit <= DrawAuthority.maximumArchiveBytes else { throw JournalError.fileTooLarge }
        guard url.isFileURL else { throw JournalError.invalidArchive }
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { open($0, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC) } ?? -1
        }
        guard descriptor >= 0 else { throw JournalError.invalidArchive }
        var status = stat()
        guard fstat(descriptor, &status) == 0, (status.st_mode & S_IFMT) == S_IFREG else {
            close(descriptor)
            throw JournalError.invalidArchive
        }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var data = Data()
        while data.count <= limit {
            let count = min(16_384, limit + 1 - data.count)
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else { return data }
            data.append(chunk)
        }
        throw JournalError.fileTooLarge
    }
}
