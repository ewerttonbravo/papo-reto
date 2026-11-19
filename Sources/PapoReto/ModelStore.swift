import CryptoKit
import Foundation
import PapoRetoCore

/// Checks the model files and downloads the ones missing, verifying each by SHA-256: the app's only network use (ADR-002).
enum ModelStore {
    struct ChecksumMismatch: Error { let file: String }

    /// Absent or truncated files. By size, not hash: hashing the encoder takes 2.3-2.6 s on the reference Mac.
    static func missingFiles(in dir: URL) -> [ModelFile] {
        ParakeetModel.files.filter { file in
            let size = try? FileManager.default.attributesOfItem(atPath: dir.appendingPathComponent(file.name).path)[.size] as? Int64
            return !file.isComplete(bytes: size)
        }
    }

    /// Each file goes to `<name>.part` and is renamed only after its hash matches; an interrupted file starts over.
    static func download(_ files: [ModelFile], to dir: URL, progress: @escaping @Sendable (String) -> Void) async throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let total = files.reduce(0) { $0 + $1.bytes }
        var done: Int64 = 0
        progress(downloadStatus(received: 0, total: total))
        for file in files {
            let destination = dir.appendingPathComponent(file.name)
            let part = destination.appendingPathExtension("part")
            defer { try? FileManager.default.removeItem(at: part) }
            let url = URL(string: "\(ParakeetModel.baseURL)/\(file.name)")!
            try await FileDownload.run(url, to: part, offset: done, total: total, progress: progress)
            guard file.isValid(sha256: sha256(of: part)) else { throw ChecksumMismatch(file: file.name) }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: part, to: destination)
            done += file.bytes
        }
    }

    /// nil when the file is absent or unreadable.
    private static func sha256(of url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        var hasher = SHA256()
        // The pool frees each 1 MB chunk; without it the encoder's 652 chunks pile up in RAM.
        while let chunk = autoreleasepool(invoking: { try? handle.read(upToCount: 1 << 20) }), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

/// One download task; callbacks arrive on the session's serial delegate queue.
private final class FileDownload: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let offset: Int64, total: Int64
    private let progress: @Sendable (String) -> Void
    private var shown = ""
    private var moveError: Error?
    private var continuation: CheckedContinuation<Void, Error>?

    private init(destination: URL, offset: Int64, total: Int64, progress: @escaping @Sendable (String) -> Void) {
        self.destination = destination
        self.offset = offset
        self.total = total
        self.progress = progress
    }

    static func run(_ url: URL, to destination: URL, offset: Int64, total: Int64,
                    progress: @escaping @Sendable (String) -> Void) async throws {
        let download = FileDownload(destination: destination, offset: offset, total: total, progress: progress)
        // Ephemeral: no cookies or cache on disk. The session retains its delegate until invalidated.
        let session = URLSession(configuration: .ephemeral, delegate: download, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { continuation in
            download.continuation = continuation
            session.downloadTask(with: url).resume()
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite _: Int64) {
        // Called every few KB: only a new percent reaches the main thread.
        let status = downloadStatus(received: offset + totalBytesWritten, total: total)
        guard status != shown else { return }
        shown = status
        progress(status)
    }

    /// The system deletes `location` when this returns, so the move happens here.
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            moveError = error
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error ?? moveError { continuation?.resume(throwing: error) } else { continuation?.resume() }
        continuation = nil
    }
}
