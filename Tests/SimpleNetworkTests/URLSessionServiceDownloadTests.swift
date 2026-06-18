import XCTest
@testable import SimpleNetwork

final class URLSessionServiceDownloadTests: XCTestCase {

    private var session: URLSession!
    private var service: URLSessionService!
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        URLProtocol.registerClass(MockURLProtocol.self)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = URLSessionService(session: session)

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SimpleNetworkDownloadTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        URLProtocol.unregisterClass(MockURLProtocol.self)
        MockURLProtocol.reset()
        try? FileManager.default.removeItem(at: tempDir)
        session = nil
        service = nil
        tempDir = nil
        try super.tearDownWithError()
    }

    // MARK: - URL 검증

    func test_url이_nil이면_invalidURL_에러로_종료된다() async {
        let destination = tempDir.appendingPathComponent("out.bin")
        let api = MockInvalidDownloadAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        guard let error = result.error else {
            return XCTFail("에러가 방출되지 않았습니다")
        }
        guard case .invalidURL = error as? NetworkError else {
            return XCTFail("기대: NetworkError.invalidURL, 실제: \(error)")
        }
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    // MARK: - 성공 경로

    func test_Content_Length_제공된_200_응답은_progress_이후_completed로_종료된다() async throws {
        let body = makeBody(size: 200 * 1024)
        let chunks = splitIntoChunks(body, chunkSize: 64 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(body.count)"],
            chunks: chunks
        )

        let destination = tempDir.appendingPathComponent("ok.bin")
        let api = makeAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)

        let progresses = result.events.compactMap { event -> TransferProgress? in
            if case .progress(let progress) = event { return progress }
            return nil
        }
        XCTAssertGreaterThanOrEqual(progresses.count, 1)
        XCTAssertEqual(progresses.last?.fractionCompleted, 1.0)

        guard case .completed(let url) = result.events.last else {
            return XCTFail("마지막 이벤트가 .completed 가 아닙니다")
        }
        XCTAssertEqual(url, destination)
    }

    func test_Content_Length_없는_200_응답은_fractionCompleted가_nil로_종료된다() async throws {
        let body = makeBody(size: 32 * 1024)
        let chunks = splitIntoChunks(body, chunkSize: 8 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: [:],
            chunks: chunks
        )

        let destination = tempDir.appendingPathComponent("unknown-length.bin")
        let api = makeAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)

        let progresses = result.events.compactMap { event -> TransferProgress? in
            if case .progress(let progress) = event { return progress }
            return nil
        }
        XCTAssertFalse(progresses.isEmpty)
        XCTAssertTrue(progresses.allSatisfy { $0.totalBytes == nil })
        XCTAssertTrue(progresses.allSatisfy { $0.fractionCompleted == nil })

        guard case .completed = result.events.last else {
            return XCTFail("마지막 이벤트가 .completed 가 아닙니다")
        }
    }

    // MARK: - 에러 매핑

    func test_404_응답이면_httpError가_throw되고_파일이_생성되지_않는다() async {
        MockURLProtocol.stub(
            status: 404,
            headers: [:],
            chunks: [Data("not found".utf8)]
        )

        let destination = tempDir.appendingPathComponent("notfound.bin")
        let api = makeAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        guard let error = result.error else {
            return XCTFail("에러가 방출되지 않았습니다")
        }
        guard case .httpError(let statusCode) = error as? NetworkError else {
            return XCTFail("기대: NetworkError.httpError, 실제: \(error)")
        }
        XCTAssertEqual(statusCode, 404)
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func test_전송_중_에러_발생시_unknown_에러로_종료되고_부분_파일이_삭제된다() async {
        let firstChunk = Data(repeating: 0xAA, count: 16 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(200_000)"],
            chunks: [firstChunk],
            errorAfterChunk: 0,
            error: URLError(.networkConnectionLost)
        )

        let destination = tempDir.appendingPathComponent("partial.bin")
        let api = makeAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        guard let error = result.error else {
            return XCTFail("에러가 방출되지 않았습니다")
        }
        if case .unknown = error as? NetworkError {
            // OK
        } else {
            XCTFail("기대: NetworkError.unknown, 실제: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(result.events.contains { if case .completed = $0 { return true } else { return false } })
    }

    func test_destination의_상위_디렉터리가_없으면_unknown_에러로_종료된다() async {
        let body = makeBody(size: 8)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(body.count)"],
            chunks: [body]
        )

        let destination = tempDir
            .appendingPathComponent("does_not_exist")
            .appendingPathComponent("out.bin")
        let api = makeAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        guard let error = result.error else {
            return XCTFail("에러가 방출되지 않았습니다")
        }
        if case .unknown = error as? NetworkError {
            // OK
        } else {
            XCTFail("기대: NetworkError.unknown, 실제: \(error)")
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertTrue(result.events.isEmpty)
    }

    // MARK: - 저장 정책

    func test_기존_파일이_있어도_덮어써지고_바이트가_서버_응답과_동일하다() async throws {
        let destination = tempDir.appendingPathComponent("overwrite.bin")
        try Data([0xFF, 0xFF, 0xFF]).write(to: destination)

        let body = makeBody(size: 1 << 18)
        let chunks = splitIntoChunks(body, chunkSize: 32 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(body.count)"],
            chunks: chunks
        )

        let api = makeAPI(destination: destination)
        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)
        let written = try Data(contentsOf: destination)
        XCTAssertEqual(written, body)
    }

    func test_completed의_URL이_destination과_동일하다() async throws {
        let body = makeBody(size: 4 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(body.count)"],
            chunks: [body]
        )

        let destination = tempDir.appendingPathComponent("match.bin")
        let api = makeAPI(destination: destination)

        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)
        guard case .completed(let url) = result.events.last else {
            return XCTFail("마지막 이벤트가 .completed 가 아닙니다")
        }
        XCTAssertEqual(url, destination)
    }

    // MARK: - 취소

    func test_소비자_Task_cancel시_CancellationError로_종료되고_파일이_삭제된다() async throws {
        let chunks = (0..<20).map { _ in Data(repeating: 0xAB, count: 1024) }
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(chunks.count * 1024)"],
            chunks: chunks,
            interChunkDelay: 0.03
        )

        let destination = tempDir.appendingPathComponent("cancel.bin")
        let api = makeAPI(destination: destination)
        let stream = service.download(api)

        let downloadTask = Task { [stream] () -> (events: [DownloadEvent], error: (any Error)?) in
            var events: [DownloadEvent] = []
            do {
                for try await event in stream {
                    events.append(event)
                    try Task.checkCancellation()
                }
                try Task.checkCancellation()
                return (events, nil)
            } catch {
                return (events, error)
            }
        }

        try await Task.sleep(nanoseconds: 80_000_000)
        downloadTask.cancel()
        let result = await downloadTask.value

        XCTAssertNotNil(result.error)
        let errorIsCancel = (result.error is CancellationError)
            || ((result.error as? URLError)?.code == .cancelled)
        XCTAssertTrue(errorIsCancel, "기대: 취소 에러, 실제: \(String(describing: result.error))")
        XCTAssertFalse(result.events.contains { if case .completed = $0 { return true } else { return false } })
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func test_취소시_onTermination이_호출되어_부분_파일이_정리된다() async throws {
        let chunks = (0..<16).map { _ in Data(repeating: 0xCD, count: 64 * 1024) }
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(chunks.count * 64 * 1024)"],
            chunks: chunks,
            interChunkDelay: 0.02
        )

        let parent = tempDir.appendingPathComponent("keep")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let destination = parent.appendingPathComponent("cleanup.bin")
        let api = makeAPI(destination: destination)
        let stream = service.download(api)

        let downloadTask = Task { [stream] () -> (any Error)? in
            do {
                for try await _ in stream {}
                return nil
            } catch {
                return error
            }
        }

        try await Task.sleep(nanoseconds: 60_000_000)
        downloadTask.cancel()
        _ = await downloadTask.value

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        var isDir: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: parent.path, isDirectory: &isDir))
        XCTAssertTrue(isDir.boolValue)
    }

    // MARK: - 보강

    func test_64KB_미만_여러_청크가_유입되면_progress가_최소_1회_방출된다() async {
        let chunks = (0..<8).map { _ in Data(repeating: 0x5A, count: 16) }
        let totalSize = chunks.map(\.count).reduce(0, +)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(totalSize)"],
            chunks: chunks
        )

        let destination = tempDir.appendingPathComponent("small-chunks.bin")
        let api = makeAPI(destination: destination)
        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)
        let progresses = result.events.compactMap { event -> TransferProgress? in
            if case .progress(let progress) = event { return progress }
            return nil
        }
        XCTAssertGreaterThanOrEqual(progresses.count, 1)
        XCTAssertEqual(progresses.last?.bytesTransferred, Int64(totalSize))
        guard case .completed = result.events.last else {
            return XCTFail("마지막 이벤트가 .completed 가 아닙니다")
        }
    }

    func test_progress_이벤트의_bytesTransferred는_단조_비감소이다() async {
        let chunks = (0..<16).map { _ in Data(repeating: 0x42, count: 16 * 1024) }
        let total = chunks.map(\.count).reduce(0, +)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(total)"],
            chunks: chunks
        )

        let destination = tempDir.appendingPathComponent("monotonic.bin")
        let api = makeAPI(destination: destination)
        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)
        let progresses = result.events.compactMap { event -> TransferProgress? in
            if case .progress(let progress) = event { return progress }
            return nil
        }
        XCTAssertFalse(progresses.isEmpty)

        for (prev, next) in zip(progresses, progresses.dropFirst()) {
            XCTAssertLessThanOrEqual(prev.bytesTransferred, next.bytesTransferred)
        }
        XCTAssertEqual(progresses.last?.bytesTransferred, Int64(total))
    }

    func test_completed는_정확히_1번_방출되고_이후_이벤트가_없다() async {
        let body = makeBody(size: 32 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(body.count)"],
            chunks: [body]
        )

        let destination = tempDir.appendingPathComponent("single-completed.bin")
        let api = makeAPI(destination: destination)
        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)

        let completedCount = result.events.reduce(0) { acc, event in
            if case .completed = event { return acc + 1 }
            return acc
        }
        XCTAssertEqual(completedCount, 1)

        guard case .completed = result.events.last else {
            return XCTFail("마지막 이벤트가 .completed 가 아닙니다")
        }
    }

    func test_completed_이후에는_어떠한_이벤트도_방출되지_않는다() async {
        let chunk = Data(repeating: 0x7F, count: 64 * 1024)
        MockURLProtocol.stub(
            status: 200,
            headers: ["Content-Length": "\(chunk.count * 2)"],
            chunks: [chunk, chunk]
        )

        let destination = tempDir.appendingPathComponent("final.bin")
        let api = makeAPI(destination: destination)
        let result = await collectEvents(service.download(api))

        XCTAssertNil(result.error)
        guard let lastEvent = result.events.last else {
            return XCTFail("이벤트가 없습니다")
        }
        guard case .completed = lastEvent else {
            return XCTFail("마지막 이벤트가 .completed 가 아닙니다")
        }

        let progresses = result.events.compactMap { event -> TransferProgress? in
            if case .progress(let progress) = event { return progress }
            return nil
        }
        XCTAssertEqual(progresses.last?.fractionCompleted, 1.0)
    }

    // MARK: - Helpers

    private func collectEvents(
        _ stream: AsyncThrowingStream<DownloadEvent, any Error>
    ) async -> (events: [DownloadEvent], error: (any Error)?) {
        var events: [DownloadEvent] = []
        do {
            for try await event in stream {
                events.append(event)
            }
            return (events, nil)
        } catch {
            return (events, error)
        }
    }

    private func makeBody(size: Int) -> Data {
        Data((0..<size).map { UInt8($0 & 0xFF) })
    }

    private func splitIntoChunks(_ data: Data, chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        while offset < data.count {
            let end = min(offset + chunkSize, data.count)
            chunks.append(data.subdata(in: offset..<end))
            offset = end
        }
        return chunks
    }

    private func makeAPI(destination: URL) -> MockSimpleDownloadAPI {
        MockSimpleDownloadAPI(destination: destination)
    }
}

// MARK: - Test Helpers

private struct MockSimpleDownloadAPI: DownloadAPI {
    typealias Query = EmptyQuery

    var baseURL: String { "https://cdn.example.test" }
    var path: String { "/files/test.bin" }
    let destination: URL
}

private struct MockInvalidDownloadAPI: DownloadAPI {
    typealias Query = EmptyQuery

    var baseURL: String { "http://host:abc/" }
    var path: String { "/x" }
    let destination: URL
}
