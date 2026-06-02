# Xunji Read-Only Training Mirror Design

## Scope

This increment adds a local-first, read-only Xunji training mirror to Vela. It imports explicitly requested training days into Vela's existing training fact layer so the current Fitness UI, workout details, analytics, recovery adaptation, and Coach context can reuse the data.

Writeback is intentionally excluded from the first increment. The future writeback path must remain a separate user-confirmed operation with a visible mutation summary.

## External Contract

Vela reads Xunji through:

```http
POST https://trains.xunjiapp.cn/api_trains_for_llm_v2
Authorization: Bearer <Keychain value>
Content-Type: application/json

{
  "schema_version": "train_open_api_v2",
  "datestr": "2026-06-02",
  "include_full_data": true
}
```

The API key is stored only in iOS Keychain under a dedicated account. It is never written to source, SwiftData, logs, analytics, URLs, request bodies, or UI after save.

Vela imports one day at a time. A successful response has `success === true`; training payloads are read from `res.trains`. User-visible errors distinguish missing key, invalid key, VIP requirement, throttling, transport failure, and malformed responses without exposing credentials.

## Data Model

Add two SwiftData models:

### `XunjiDailyCacheRecord`

- unique `datestr`
- `fetchedAt`
- `includeFullData`
- external-storage `responseData`

This stores the most recent normalized server response for a day. Reads within 90 seconds reuse the cache and never call Xunji again. A full-data cache can satisfy a lightweight request. A lightweight cache is still reused during the cooldown; after the cooldown, an explicit full-data request can refresh it.

### `XunjiWorkoutMirrorRecord`

- unique `externalID`
- `datestr`
- `linkedStrengthWorkoutID`
- `linkedWorkoutEventID`
- external-storage `rawTrainData`
- `lastImportedAt`

This is the idempotency map between a Xunji `localid` and Vela's existing records. It prevents duplicate imports and preserves the original server payload for later read-only inspection or confirmed writeback.

## Parsing And Mapping

`XunjiTrainingClient` owns HTTP encoding, authentication, status validation, and response decoding. It receives the key as a method argument so credentials never become model state.

`XunjiTrainingImportService` runs on the main actor because it writes SwiftData. For each requested day:

1. Reuse `XunjiDailyCacheRecord` if it is younger than 90 seconds.
2. Otherwise read the key from Keychain and fetch the day.
3. Store the successful normalized response in the daily cache.
4. Parse each train into a `StrengthWorkoutRecord`.
5. Upsert the linked `WorkoutEventRecord` through `WorkoutAggregationService`.
6. Save or refresh `XunjiWorkoutMirrorRecord`.

Mapping rules:

- Preserve Xunji `localid`, `start`, and `end` in the mirror payload.
- Use the Xunji training title as the local workout title.
- Map completed movement sets into `StrengthSetLog`; preserve unfinished sets with `isCompleted = false`.
- Parse `kg` directly. Convert `lb` to kilograms. Unknown units remain zero rather than guessing.
- Preserve RPE and duration values where provided.
- Flatten supported nested `items` into their Chinese movement names.
- Do not read, store, display, or generate internal Xunji movement keys.
- If a record has no usable strength movements, create a unified `WorkoutEventRecord` only when the payload still describes a timed activity. Do not invent strength sets.

## UI

Add a `XunjiTrainingSettingsView` under Settings > Data Sources:

- secure key entry
- saved/not-saved status
- save and delete actions
- explanation that credentials remain in Keychain

Add a compact `XunjiSyncSheetView` opened from the Fitness header:

- date picker, defaulting to today
- one-day import action
- full-data import enabled by default so set details, unfinished sets, RPE, notes, and timed metrics are preserved
- cache state and imported-record summary
- understandable errors

The Fitness header sync button uses a download-style icon and stays secondary to the existing start-workout action.

## Security And Writeback Boundary

- Never log request headers or keys.
- Never persist the key outside Keychain.
- Never place the key in body or query parameters.
- Never expose an automatic writeback path.
- A future writeback UI must show a mutation summary and wait for explicit confirmation immediately before the network call.
- Future movement writeback must use Chinese names from the public Xunji movement list and must not send internal keys.

## Testing

Add focused tests for:

- 90-second cache reuse policy
- full cache satisfying lightweight reads
- lightweight cache requiring refresh for full data after cooldown
- API response decoding
- kilogram and pound mapping
- unfinished-set preservation
- nested-item flattening
- idempotent local mirror imports
- generated `WorkoutEventRecord` and daily aggregation
- absence of internal movement-key fields in Xunji write-capable payload types

Run the complete simulator suite, unsigned simulator build, signed device build, and device install/launch after the increment.

## Follow-Up

The next training-product increment will build template management and richer visualizations directly on Vela's local training fact layer. Once Vela's native tracking flow is sufficient, Xunji remains an optional migration and interoperability source rather than a required dependency.
