import XCTest
@testable import SimpleNetwork

final class TransferProgressTests: XCTestCase {

    // MARK: - fractionCompleted 계산

    func test_bytesTransferred가_totalBytes의_절반이면_fractionCompleted가_05이다() {
        let progress = TransferProgress(bytesTransferred: 50, totalBytes: 100)

        XCTAssertEqual(progress.fractionCompleted, 0.5)
    }

    func test_totalBytes가_nil이면_fractionCompleted가_nil이다() {
        let progress = TransferProgress(bytesTransferred: 50, totalBytes: nil)

        XCTAssertNil(progress.fractionCompleted)
    }

    // MARK: - 경계값

    func test_bytesTransferred가_totalBytes를_초과하면_fractionCompleted가_1이다() {
        let progress = TransferProgress(bytesTransferred: 120, totalBytes: 100)

        XCTAssertEqual(progress.fractionCompleted, 1.0)
    }

    func test_totalBytes가_0이면_fractionCompleted가_nil이다() {
        let progress = TransferProgress(bytesTransferred: 0, totalBytes: 0)

        XCTAssertNil(progress.fractionCompleted)
    }
}
