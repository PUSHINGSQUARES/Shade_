import Foundation

struct City: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double

    var displayLabel: String { "\(name), \(country)" }
}

struct CityDatabase {
    let cities: [City]

    init(cities: [City]) {
        self.cities = cities
    }

    init(data: Data) throws {
        self.cities = try JSONDecoder().decode([City].self, from: data)
    }

    static func bundled(bundle: Bundle = .main) -> CityDatabase {
        guard let url = bundle.url(forResource: "cities", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let database = try? CityDatabase(data: data) else {
            return CityDatabase(cities: [])
        }
        return database
    }

    func search(_ query: String) -> [City] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cities }
        let lowered = trimmed.lowercased()
        return cities.filter { $0.name.lowercased().contains(lowered) }
    }
}
