# Algorithm validation entry point

ARCH-00 deliberately does not add a second scoring implementation. The replay fixture remains the production XCTest `ScoringEngineTests.testDailyHealthComputationGoldenFixtureAndVersionConsistency`; the reviewable extracted inventory is [`../docs/baselines/golden-inventory.json`](../docs/baselines/golden-inventory.json).

Run the focused replay against a simulator with the normal Vela scheme:

```sh
xcodebuild test \
  -project Vela.xcodeproj \
  -scheme Vela \
  -destination 'platform=iOS Simulator,id=BCAD01D0-CB5A-4277-B622-269479D0E159' \
  -only-testing:VelaTests/ScoringEngineTests/testDailyHealthComputationGoldenFixtureAndVersionConsistency
```

The fixture owns its UTC calendar, date, fourteen-day history, profile, and five expected score values. ARCH-01 must run this test before and after `BodySeekDomain` extraction and preserve the values within the fixture tolerance (`0.01`).
