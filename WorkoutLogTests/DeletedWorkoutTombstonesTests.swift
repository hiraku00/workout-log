import XCTest
@testable import WorkoutLog

final class DeletedWorkoutTombstonesTests: XCTestCase {
    func testRecordedIDIsReportedAsContained() {
        let id = UUID()
        XCTAssertFalse(DeletedWorkoutTombstones.contains(id))

        DeletedWorkoutTombstones.record(id)

        XCTAssertTrue(DeletedWorkoutTombstones.contains(id))
    }

    func testRecordingASequenceRecordsEachID() {
        let ids = [UUID(), UUID(), UUID()]

        DeletedWorkoutTombstones.record(ids)

        for id in ids {
            XCTAssertTrue(DeletedWorkoutTombstones.contains(id))
        }
    }

    func testUnrecordedIDIsNotContained() {
        XCTAssertFalse(DeletedWorkoutTombstones.contains(UUID()))
    }
}
