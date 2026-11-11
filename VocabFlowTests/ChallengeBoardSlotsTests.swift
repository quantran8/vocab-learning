import XCTest
@testable import VocabFlow

final class ChallengeBoardSlotsTests: XCTestCase {
    func testFirstBoardTakesEngineOrder() {
        XCTAssertEqual(ChallengeBoardSlots.reconcile([], with: ["w2", "w1"]), ["w2", "w1"])
    }

    func testNewTileTakesTheMatchedTilesSlot() {
        let slots = ChallengeBoardSlots.reconcile(["w1", "w2", "w3"], with: ["w4", "w3", "w1"])
        XCTAssertEqual(slots, ["w1", "w4", "w3"])
    }

    func testSlotStaysEmptyWhenQueueRunsOut() {
        XCTAssertEqual(ChallengeBoardSlots.reconcile(["w1", "w2", "w3"], with: ["w3", "w1"]), ["w1", nil, "w3"])
    }

    func testFreshBoardReplacesEverything() {
        XCTAssertEqual(ChallengeBoardSlots.reconcile(["w1", "w2"], with: ["x2", "x1"]), ["x2", "x1"])
    }

    func testHeldTilesKeepTheirSlotUntilReleased() {
        let held = ChallengeBoardSlots.reconcile(["w1", "w2", "w3"], with: ["w4", "w3", "w1"], holding: ["w2"])
        XCTAssertEqual(held, ["w1", "w2", "w3"])
        XCTAssertEqual(ChallengeBoardSlots.reconcile(held, with: ["w4", "w3", "w1"]), ["w1", "w4", "w3"])
    }
}
