import Foundation

struct Track: Identifiable, Hashable {
    let id: String
    let url: URL
    let title: String
}

struct Album: Identifiable, Hashable {
    let id: String
    let name: String
    let artistName: String
    var tracks: [Track]
}

struct Artist: Identifiable, Hashable {
    let id: String
    let name: String
    var albums: [Album]
}
