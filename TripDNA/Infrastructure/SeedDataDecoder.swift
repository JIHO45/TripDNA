import Foundation

nonisolated struct SeedDataDecoder {
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    func decodeCountries(from data: Data) throws -> [CountryProfile] {
        let seeds = try decoder.decode([String: CountrySeed].self, from: data)
        return try seeds.map { code, seed in
            let matchingAxes = try Set(seed.matchingAxes.map(requiredAxis))
            return CountryProfile(
                countryCode: code.uppercased(),
                name: seed.name,
                nameKo: seed.nameKo,
                status: seed.status,
                tasteCore: TasteAxes(
                    natureUrban: seed.tasteCore.natureUrban,
                    energyLevel: seed.tasteCore.energyLevel,
                    planningStyle: seed.tasteCore.planningStyle,
                    socialMode: seed.tasteCore.socialMode,
                    noveltyAppetite: seed.tasteCore.noveltyDistance ?? 0
                ).clamped(),
                matchingAxes: matchingAxes,
                interestTags: seed.interestTags,
                constraints: seed.constraints,
                popularity: seed.popularity.map { min(max($0, 0), 1) }
            )
        }
        .sorted { $0.countryCode < $1.countryCode }
    }

    func decodeTags(from data: Data) throws -> [TagDefinition] {
        let seeds = try decoder.decode([String: TagSeed].self, from: data)
        return try seeds.map { id, seed in
            let signature = try seed.axisSignature?.reduce(
                into: [TasteAxis: Double]()
            ) { result, pair in
                result[try requiredAxis(pair.key)] = min(max(pair.value, -1), 1)
            }
            return TagDefinition(
                id: id,
                labelKo: seed.labelKo,
                group: seed.group,
                routing: Set(seed.routing),
                axisSignature: signature,
                polarityPairID: seed.polarityPairID,
                constraintTarget: seed.constraintTarget,
                qualityTarget: seed.qualityTarget
            )
        }
        .sorted { $0.id < $1.id }
    }

    private func requiredAxis(_ rawValue: String) throws -> TasteAxis {
        guard let axis = TasteAxis(rawValue: rawValue) else {
            throw SeedDataError.unknownTasteAxis(rawValue)
        }
        return axis
    }
}

nonisolated enum SeedDataError: Error, Equatable {
    case unknownTasteAxis(String)
}

private struct CountrySeed: Decodable {
    let name: String
    let nameKo: String
    let status: CountryStatus
    let tasteCore: CountryTasteCoreSeed
    let matchingAxes: [String]
    let interestTags: [String: Double?]
    let constraints: CountryConstraints
    /// 인지도(0~1). 값이 없으면 underrated_fit 슬롯에서 중립값으로 취급한다.
    let popularity: Double?
}

private struct CountryTasteCoreSeed: Decodable {
    let natureUrban: Double
    let energyLevel: Double
    let planningStyle: Double
    let socialMode: Double
    let noveltyDistance: Double?
}

private struct TagSeed: Decodable {
    let labelKo: String
    let group: TagGroup
    let routing: [TagRouting]
    let axisSignature: [String: Double]?
    let polarityPairID: String?
    let constraintTarget: String?
    let qualityTarget: Bool

    private enum CodingKeys: String, CodingKey {
        case labelKo
        case group
        case routing
        case axisSignature
        case polarityPairID = "polarityPairId"
        case constraintTarget
        case qualityTarget
    }
}
