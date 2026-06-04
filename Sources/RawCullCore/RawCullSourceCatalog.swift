import Foundation

public nonisolated struct RawCullSourceCatalog: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let url: URL

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        url: URL,
    ) {
        self.id = id
        self.name = name
        self.url = url
    }
}
