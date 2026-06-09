# Apple + Xunji Workout Sync Design

## Goal

Vela should treat Apple Watch workouts as the authoritative workout record, while using Xunji only to enrich strength workouts with structured lifting details.

## Data Source Roles

- Apple Watch / HealthKit is the primary source for workout time, duration, heart rate, route, distance, weather-derived context, active energy, and activity type.
- Xunji is a strength-training detail source for title, body part, exercises, sets, reps, weight, notes, and session RPE.
- Non-strength activities such as walking, running, swimming, and cycling do not require Xunji data and should remain Apple-only unless another explicit detail source is added later.

## Merge Behavior

The canonical training list should contain one row per real workout.

When an Apple strength workout and a Xunji workout represent the same real session:

- Keep one `WorkoutEventRecord`.
- Preserve Apple timing and physiological metrics.
- Link `linkedHealthKitWorkoutId` to the Apple workout.
- Link `linkedStrengthWorkoutId` to the Xunji-backed `StrengthWorkoutRecord`.
- Set the displayed title and strength detail view to the Xunji title and exercises.
- Mark the source as `healthKit+xunji`.

When an Apple workout has no matching Xunji workout:

- Keep it as an Apple-backed `WorkoutEventRecord`.
- Display the Apple activity name.
- Do not synthesize strength details.

When a Xunji strength workout has no matching Apple workout:

- Keep it as a `xunji-only` local workout event.
- Display it in the training list with Xunji title and lifting details.
- Treat physiological metrics as unavailable rather than estimating them as Apple data.
- Allow a later HealthKit sync to merge it into `healthKit+xunji` if a matching Apple workout appears.

## Matching Rules

A Xunji workout can merge only with a compatible Apple strength workout.

Compatibility requires:

- Same calendar day, allowing workouts near midnight to match by actual overlap.
- Apple activity is a strength training activity, or normalized Apple title is strength-compatible.
- Meaningful time relationship:
  - Prefer interval overlap of at least 50% of the shorter workout.
  - Also allow start or end time drift up to 20 minutes, because Watch and Xunji are often started a few minutes apart.
  - Avoid matching solely by start time when durations do not overlap.

If multiple Apple candidates exist, choose the highest score by:

1. overlap ratio
2. start/end closeness
3. duration similarity
4. existing link stability

If confidence is ambiguous, do not merge automatically. Keep Xunji as `xunji-only` rather than risking corrupting an Apple workout.

## Idempotency

Repeated Xunji imports and HealthKit syncs must not create duplicate rows.

- Xunji import should upsert by `XunjiWorkoutMirrorRecord.externalID`.
- HealthKit sync should upsert by `linkedHealthKitWorkoutId`.
- Merge should be reversible in data shape: unlinking one side must not delete the other side unless the user explicitly deletes that source.
- Daily summary aggregation should rebuild from canonical `WorkoutEventRecord` rows.

## UI Contract

Training list labels:

- `Apple` for Apple-only workouts.
- `Apple + 训记` for merged strength workouts.
- `训记` for Xunji-only strength workouts.

Merged detail view:

- Header title uses Xunji title.
- Time, duration, calories, heart rate, route, and other physiological fields use Apple data.
- Strength section uses Xunji exercises, sets, reps, and weights.

## Tests

Add or update tests for:

- Xunji imports merge into an overlapping Apple traditional strength training event.
- A Xunji workout with no Apple match remains `xunji-only`.
- A later Apple sync upgrades an existing `xunji-only` workout to `healthKit+xunji`.
- Running import and sync repeatedly stays idempotent.
- Running or walking Apple workouts never merge with Xunji strength details.
- Close start time but poor overlap does not merge.
