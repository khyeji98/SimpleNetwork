//
//  MockURLProtocol.swift
//  SimpleNetworkTests
//
//  Created by 김혜지.
//

import Foundation

/// 테스트용 URLProtocol 스텁.
///
/// `URLSession.bytes(for:)` / `URLSession.data(for:)` 경로 위에서 응답을
/// 청크 단위로 재현하고, 원하는 청크 이후에 에러를 주입할 수 있다.
/// iOS 15 / macOS 12 하한 준수를 위해 `NSLock` + `@unchecked Sendable`를 사용한다.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    enum ResponseKind {
        case http(status: Int, headers: [String: String])
        case nonHTTP(URL)
    }

    struct Stub {
        var responseKind: ResponseKind
        var chunks: [Data]
        var errorAfterChunk: Int?
        var error: Error?
        var interChunkDelay: TimeInterval?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var _stub: Stub?

    static func stub(
        status: Int = 200,
        headers: [String: String] = [:],
        chunks: [Data] = [],
        errorAfterChunk: Int? = nil,
        error: Error? = nil,
        interChunkDelay: TimeInterval? = nil
    ) {
        lock.lock()
        defer { lock.unlock() }
        _stub = Stub(
            responseKind: .http(status: status, headers: headers),
            chunks: chunks,
            errorAfterChunk: errorAfterChunk,
            error: error,
            interChunkDelay: interChunkDelay
        )
    }

    static func stubNonHTTPResponse(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        _stub = Stub(
            responseKind: .nonHTTP(url),
            chunks: [],
            errorAfterChunk: nil,
            error: nil,
            interChunkDelay: nil
        )
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        _stub = nil
    }

    private static func currentStub() -> Stub? {
        lock.lock()
        defer { lock.unlock() }
        return _stub
    }

    private let stateLock = NSLock()
    private var isStopped = false

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let client else { return }

        guard let stub = Self.currentStub() else {
            client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        switch stub.responseKind {
        case .http(let status, let headers):
            let url = request.url ?? URL(string: "https://mock.invalid")!
            guard let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: headers
            ) else {
                client.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        case .nonHTTP(let url):
            let response = URLResponse(
                url: url,
                mimeType: nil,
                expectedContentLength: -1,
                textEncodingName: nil
            )
            client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }

        for (index, chunk) in stub.chunks.enumerated() {
            if isStoppedThreadSafe() { return }

            if let delay = stub.interChunkDelay, delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }

            if isStoppedThreadSafe() { return }

            client.urlProtocol(self, didLoad: chunk)

            if
                let errorAfter = stub.errorAfterChunk,
                index >= errorAfter,
                let error = stub.error
            {
                client.urlProtocol(self, didFailWithError: error)
                return
            }
        }

        if isStoppedThreadSafe() { return }

        if let error = stub.error, stub.errorAfterChunk == nil {
            client.urlProtocol(self, didFailWithError: error)
            return
        }

        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {
        stateLock.lock()
        defer { stateLock.unlock() }
        isStopped = true
    }

    private func isStoppedThreadSafe() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isStopped
    }
}
