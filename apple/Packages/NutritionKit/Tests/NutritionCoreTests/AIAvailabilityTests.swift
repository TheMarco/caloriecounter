// The Apple Intelligence nudge rule: only suggest turning it on when the device is
// capable but it's switched off — never for ineligible hardware or mid-download.

import Testing
@testable import NutritionCore

@Suite("AIAvailability")
struct AIAvailabilityTests {

    @Test("only .notEnabled suggests enabling Apple Intelligence")
    func suggestsEnablingOnlyWhenOff() {
        #expect(AIAvailability.notEnabled.suggestsEnabling)
        #expect(!AIAvailability.available.suggestsEnabling)
        #expect(!AIAvailability.deviceNotEligible.suggestsEnabling)   // can't enable it
        #expect(!AIAvailability.modelNotReady.suggestsEnabling)       // still loading
        #expect(!AIAvailability.unavailable.suggestsEnabling)
    }
}
