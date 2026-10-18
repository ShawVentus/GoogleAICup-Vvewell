import Foundation

struct OcrReport: Codable {
    let id: String
    let date: Date
    let imageLocalPath: String
    let source: Source
    let items: [OcrItem]

    enum Source: String, Codable {
        case device
        case cloud
    }

    struct OcrItem: Codable {
        let name: String
        let value: String
        let reference: String
        let isAbnormal: Bool
    }

    init(
        id: String,
        date: Date,
        imageLocalPath: String,
        source: Source = .device,
        items: [OcrItem]
    ) {
        self.id = id
        self.date = date
        self.imageLocalPath = imageLocalPath
        self.source = source
        self.items = items
    }

    enum CodingKeys: String, CodingKey {
        case id, date, imageLocalPath, source, items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        imageLocalPath = try container.decode(String.self, forKey: .imageLocalPath)
        source = try container.decodeIfPresent(Source.self, forKey: .source) ?? .device
        items = try container.decode([OcrItem].self, forKey: .items)
    }
}
