import Foundation
import Observation

@MainActor @Observable final class Library {
    var data = LibraryData()
    var message = ""
    var lastSaved: Place?
    static let group = (Bundle.main.object(forInfoDictionaryKey: "ReelMapAppGroup") as? String) ?? "group.com.course.reelmap"
    var sharedAvailable: Bool { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group) != nil }
    private var file: URL {
        let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("reelmap.json")
    }
    init() { reload() }
    func reload() {
        do { data = try read() } catch { message = "저장 데이터를 읽지 못했습니다: \(error.localizedDescription)" }
    }
    private func read() throws -> LibraryData {
        guard FileManager.default.fileExists(atPath: file.path) else { return LibraryData() }
        return try JSONDecoder().decode(LibraryData.self, from: Data(contentsOf: file))
    }
    private func change(_ update: (inout LibraryData) -> Void) throws {
        #if SHARE_EXTENSION
        guard sharedAvailable else { throw UserError(message: "App Group 서명이 연결되지 않아 앱과 저장 공간을 공유할 수 없습니다. Xcode에서 두 타깃의 App Groups 설정을 확인해 주세요.") }
        #endif
        var coordinationError: NSError?
        var operationError: Error?
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forMerging, error: &coordinationError) { url in
            do {
                var current = try read()
                update(&current)
                try JSONEncoder().encode(current).write(to: url, options: .atomic)
                data = current
            } catch { operationError = error }
        }
        if let error = coordinationError { throw error }
        if let error = operationError { throw error }
    }
    func save(_ places: [Place], source: String, resolving: String? = nil, resolveSource: Bool = false) throws {
        try change { current in
            for var p in places where !current.places.contains(where: { $0.id == p.id }) {
                p.source = source
                p.savedAt = ISO8601DateFormatter().string(from: Date())
                current.places.append(p)
            }
            if let resolving { current.pending.removeAll { $0.id == resolving } }
            if resolveSource, let key = InstagramCaption.postKey(source) { current.pending.removeAll { InstagramCaption.postKey($0.url) == key } }
        }
        lastSaved = places.first
    }
    func addPending(url: String, text: String, reason: String) throws {
        try change { current in
            let key = InstagramCaption.postKey(url)
            if let index = current.pending.firstIndex(where: { key != nil ? InstagramCaption.postKey($0.url) == key : $0.url == url && $0.text == text }) {
                let old = current.pending[index]
                current.pending[index] = PendingPost(id: old.id, url: url, text: text.isEmpty ? old.text : text, reason: reason, createdAt: old.createdAt)
            } else { current.pending.insert(PendingPost(url: url, text: text, reason: reason), at: 0) }
        }
    }
    func delete(_ place: Place) throws { try change { $0.places.removeAll { $0.id == place.id } } }
    func removePending(_ id: String) throws { try change { $0.pending.removeAll { $0.id == id } } }
}
