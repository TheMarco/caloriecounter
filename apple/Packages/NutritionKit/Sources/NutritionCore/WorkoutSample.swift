// A completed Apple Health workout the app may offer to offset calories against.
// This is read-only context — the app never writes workouts to Health. Only
// "real" workouts surface (see `qualifiesAsRealWorkout`): a duration + energy
// floor keeps incidental movement (a few flights of stairs) from ever appearing.

import Foundation

public struct WorkoutSample: Sendable, Equatable, Identifiable {
    /// `HKWorkout.uuid` as a string — the stable key used to dedup offers, so the
    /// same workout is never suggested or added twice.
    public let id: String
    /// Local day (YYYY-MM-DD) the workout ended on — the day whose offset it applies to.
    public let date: String
    /// Friendly activity name for the prompt ("Run", "Walk", "Strength Training").
    public let activityName: String
    public let start: Date
    public let end: Date
    /// Whole minutes of elapsed workout time.
    public let durationMinutes: Int
    /// Active energy burned, in kilocalories (already rounded for display).
    public let kcal: Double

    public init(id: String, date: String, activityName: String,
                start: Date, end: Date, durationMinutes: Int, kcal: Double) {
        self.id = id
        self.date = date
        self.activityName = activityName
        self.start = start
        self.end = end
        self.durationMinutes = durationMinutes
        self.kcal = kcal
    }

    /// Gate for a "real" workout — a longer walk or an actual session, never a brief
    /// burst of incidental movement. Both floors must clear: short-but-intense and
    /// long-but-trivial are both excluded. Defaults match `Constants`.
    public static func qualifiesAsRealWorkout(
        durationMinutes: Int, kcal: Double,
        minMinutes: Int = Constants.minWorkoutMinutes,
        minKcal: Double = Constants.minWorkoutKcal
    ) -> Bool {
        durationMinutes >= minMinutes && kcal >= minKcal
    }
}
