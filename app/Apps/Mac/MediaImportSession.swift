import Foundation
import MediaIO
import Observation

@MainActor
@Observable
final class MediaImportSession {
    struct Row: Identifiable {
        let id = UUID()
        let filename: String
        let result: Result<ImportedMedia, MediaImportError>
    }

    private let library: MediaLibrary
    private var task: Task<Void, Never>?
    private(set) var rows: [Row] = []

    var isImporting: Bool { task != nil }

    init(library: MediaLibrary) {
        self.library = library
    }

    @discardableResult
    func importFiles(_ urls: [URL]) -> Task<Void, Never>? {
        guard task == nil, !urls.isEmpty else { return nil }
        let importTask = Task {
            let results = await library.importFiles(urls)
            rows.append(contentsOf: zip(urls, results).map { url, result in
                Row(filename: url.lastPathComponent, result: result)
            })
            task = nil
        }
        task = importTask
        return importTask
    }

    func cancel() {
        task?.cancel()
    }
}
