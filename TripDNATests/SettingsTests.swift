import Foundation
import Testing
@testable import TripDNA

struct SettingsTests {
    @Test func oldProfileWithoutDirectFlightsPreferenceStillDecodes() throws {
        let json = #"{"id":"u","locale":"ko_KR","onboardingStatus":"done","homeCountryCode":"KR","createdAt":0}"#
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        #expect(profile.prefersDirectFlights == nil)
        #expect(profile.departureAirportCode == nil)
    }

    @Test @MainActor func departureDefaultsPersistAndKeepHomeCountry() async throws {
        let dependencies = AppDependencies(persistence: .inMemory)
        await dependencies.setHomeCountryCode("KR")
        try await dependencies.setDepartureDefaults(airportCode: "ICN", prefersDirectFlights: true)
        let profile = try #require(await dependencies.store.loadProfile())
        #expect(profile.departureAirportCode == "ICN")
        #expect(profile.prefersDirectFlights == true)
        #expect(profile.homeCountryCode == "KR")

        await dependencies.clearHomeCountryCode()
        let cleared = try #require(await dependencies.store.loadProfile())
        #expect(cleared.homeCountryCode == nil)
        #expect(cleared.departureAirportCode == "ICN")
        #expect(dependencies.homeCountryCode == nil)
    }
}
