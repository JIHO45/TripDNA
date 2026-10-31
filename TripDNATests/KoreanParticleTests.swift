import Testing
@testable import TripDNA

struct KoreanParticleTests {
    @Test func attachesByFinalConsonant() {
        #expect(KoreanParticle.attach("리스본", .waGwa) == "리스본과")
        #expect(KoreanParticle.attach("리스본", .eunNeun) == "리스본은")
        #expect(KoreanParticle.attach("리스본", .euroRo) == "리스본으로")
        #expect(KoreanParticle.attach("교토", .waGwa) == "교토와")
        #expect(KoreanParticle.attach("교토", .eunNeun) == "교토는")
        #expect(KoreanParticle.attach("교토", .euroRo) == "교토로")
        #expect(KoreanParticle.attach("교토", .iGa) == "교토가")
        #expect(KoreanParticle.attach("질문", .eulReul) == "질문을")
        #expect(KoreanParticle.attach("서울", .euroRo) == "서울로")
    }

    @Test func nonHangulEnding() {
        #expect(KoreanParticle.attach("100만 원", .euroRo) == "100만 원으로")
        #expect(KoreanParticle.attach("3", .euroRo) == "3으로")
        #expect(KoreanParticle.attach("2", .eunNeun) == "2는")
        #expect(KoreanParticle.attach("8", .euroRo) == "8로")
        #expect(KoreanParticle.attach("“미식”", .waGwa) == "“미식”과")
        #expect(KoreanParticle.attach("Lisbon", .waGwa) == "Lisbon와(과)")
    }
}
