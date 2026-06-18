//
//  URLSessionService.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// URLSession을 사용하여 네트워크 요청을 수행하는 구현체입니다.
///
/// 모든 저장 프로퍼티가 `let`이며 내부 상태를 변경하지 않으므로 동시성 안전합니다.
/// `JSONDecoder`가 non-Sendable 클래스이지만 인스턴스를 외부와 공유하지 않으므로
/// `@unchecked Sendable`로 선언합니다.
public final class URLSessionService: NetworkService, @unchecked Sendable {
    private enum Metric {
        static let downloadBufferSize = 64 * 1024
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    /// URLSessionService를 초기화합니다.
    /// - Parameters:
    ///   - session: 사용할 URLSession 인스턴스 (기본값: .shared)
    ///   - decoder: JSON 디코딩에 사용할 JSONDecoder (기본값: snake_case 변환)
    public init(
        session: URLSession = .shared,
        decoder: JSONDecoder? = nil
    ) {
        self.session = session
        
        if let decoder = decoder {
            self.decoder = decoder
        } else {
            let defaultDecoder = JSONDecoder()
            defaultDecoder.keyDecodingStrategy = .convertFromSnakeCase
            self.decoder = defaultDecoder
        }
    }

    public func download<API: DownloadAPI>(
        _ api: API
    ) -> AsyncThrowingStream<DownloadEvent, any Error> {
        AsyncThrowingStream { continuation in
            let destination = api.destination
            let session = self.session

            let task = Task {
                await Self.performDownload(
                    api: api,
                    session: session,
                    continuation: continuation
                )
            }

            continuation.onTermination = { @Sendable termination in
                task.cancel()
                if case .cancelled = termination {
                    try? FileManager.default.removeItem(at: destination)
                }
            }
        }
    }

    private static func performDownload<API: DownloadAPI>(
        api: API,
        session: URLSession,
        continuation: AsyncThrowingStream<DownloadEvent, any Error>.Continuation
    ) async {
        guard let url = api.url else {
            continuation.finish(throwing: NetworkError.invalidURL)
            return
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = api.httpMethod.rawValue

        if let headers = api.headers {
            for (key, value) in headers.dictionary {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        let asyncBytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (asyncBytes, response) = try await session.bytes(for: urlRequest)
        } catch let urlError as URLError where urlError.code == .cancelled {
            continuation.finish(throwing: CancellationError())
            return
        } catch {
            continuation.finish(throwing: NetworkError.unknown(error))
            return
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            continuation.finish(throwing: NetworkError.invalidResponse)
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            continuation.finish(throwing: NetworkError.httpError(statusCode: httpResponse.statusCode))
            return
        }

        let totalBytes: Int64? = {
            let length = httpResponse.expectedContentLength
            return length > 0 ? length : nil
        }()

        let destination = api.destination
        try? FileManager.default.removeItem(at: destination)

        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            continuation.finish(throwing: NetworkError.unknown(
                DownloadFileSystemError.cannotCreateFile(path: destination.path)
            ))
            return
        }

        let fileHandle: FileHandle
        do {
            fileHandle = try FileHandle(forWritingTo: destination)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            continuation.finish(throwing: NetworkError.unknown(error))
            return
        }

        var bytesTransferred: Int64 = 0
        var buffer = Data()
        buffer.reserveCapacity(Metric.downloadBufferSize)

        do {
            for try await byte in asyncBytes {
                buffer.append(byte)
                if buffer.count >= Metric.downloadBufferSize {
                    try fileHandle.write(contentsOf: buffer)
                    bytesTransferred += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    continuation.yield(.progress(TransferProgress(
                        bytesTransferred: bytesTransferred,
                        totalBytes: totalBytes
                    )))
                }
            }

            if !buffer.isEmpty {
                try fileHandle.write(contentsOf: buffer)
                bytesTransferred += Int64(buffer.count)
                buffer.removeAll(keepingCapacity: true)
            }

            continuation.yield(.progress(TransferProgress(
                bytesTransferred: bytesTransferred,
                totalBytes: totalBytes
            )))
            try? fileHandle.close()
            continuation.yield(.completed(destination))
            continuation.finish()
        } catch is CancellationError {
            try? fileHandle.close()
            try? FileManager.default.removeItem(at: destination)
            continuation.finish(throwing: CancellationError())
        } catch let urlError as URLError where urlError.code == .cancelled {
            try? fileHandle.close()
            try? FileManager.default.removeItem(at: destination)
            continuation.finish(throwing: CancellationError())
        } catch {
            try? fileHandle.close()
            try? FileManager.default.removeItem(at: destination)
            continuation.finish(throwing: NetworkError.unknown(error))
        }
    }

    public func request<API: RequestAPI>(_ api: API) async throws -> API.Response {
        guard let url = api.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = api.httpMethod.rawValue
        
        // 1. 헤더 설정
        if let headers = api.headers {
            for (key, value) in headers.dictionary {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // 2. 바디 설정
        if let body = api.body {
            do {
                let encoder = JSONEncoder()
                encoder.keyEncodingStrategy = .convertToSnakeCase // 기본값 설정 (필요시 주입받도록 개선 가능)
                let bodyData = try encoder.encode(body)
                urlRequest.httpBody = bodyData
                if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } catch {
                throw NetworkError.encodingFailed
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            let decodedResponse = try decoder.decode(API.Response.self, from: data)
            return decodedResponse
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
