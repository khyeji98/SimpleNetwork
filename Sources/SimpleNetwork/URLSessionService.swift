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
public final class URLSessionService: NetworkService {
    private let session: URLSession
    private let encoder: any BodyEncoder
    private let decoder: any ResponseDecoder
    private let logger: NetworkLogger

    /// URLSessionService를 초기화합니다.
    ///
    /// `encoder`/`decoder`에는 기본값이 없습니다. 키 변환 전략은 서버 스펙에 따라 달라지므로
    /// 라이브러리가 임의로 정하지 않고 호출부가 명시하도록 합니다.
    /// 여기 지정한 값은 서비스 기본값이며, `RequestAPI`가 재정의하면 해당 API에는 그쪽이 우선합니다.
    ///
    /// 키를 변환하지 않으려면 `JSONBodyEncoder()` / `JSONResponseDecoder()`를 그대로 전달하세요.
    /// - Parameters:
    ///   - session: 사용할 URLSession 인스턴스 (기본값: .shared)
    ///   - encoder: 요청 바디 인코딩에 사용할 기본 인코더
    ///   - decoder: 응답 디코딩에 사용할 기본 디코더
    ///   - logger: 통신 로그를 기록할 NetworkLogger (기본값: 활성화된 기본 로거)
    public init(
        session: URLSession = .shared,
        encoder: any BodyEncoder,
        decoder: any ResponseDecoder,
        logger: NetworkLogger = NetworkLogger()
    ) {
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
        self.logger = logger
    }

    /// 1.x에서 인코더/디코더를 생략하던 호출을 가로채 마이그레이션을 안내합니다.
    ///
    /// 1.x는 생략 시 snake_case 변환을 적용했습니다. 그대로 두면 빌드는 성공한 채
    /// 런타임 디코딩만 깨지므로, 호출 자체를 컴파일 에러로 막습니다.
    @available(*, unavailable, message: """
        2.0부터 encoder/decoder를 명시해야 합니다. \
        1.x와 동일하게 동작시키려면 encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase), \
        decoder: JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)를 전달하세요. \
        키를 변환하지 않으려면 JSONBodyEncoder(), JSONResponseDecoder()를 전달하세요.
        """)
    public convenience init(
        session: URLSession = .shared,
        logger: NetworkLogger = NetworkLogger()
    ) { fatalError("unavailable") }

    /// 1.x의 `JSONEncoder`/`JSONDecoder` 직접 주입 호출을 가로채 마이그레이션을 안내합니다.
    @available(*, unavailable, message: """
        JSONEncoder/JSONDecoder 직접 주입은 BodyEncoder/ResponseDecoder로 대체되었습니다. \
        JSONBodyEncoder(keyEncodingStrategy:) / JSONResponseDecoder(keyDecodingStrategy:)를 사용하세요.
        """)
    public convenience init(
        session: URLSession = .shared,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        logger: NetworkLogger = NetworkLogger()
    ) { fatalError("unavailable") }

    public func download<API: DownloadAPI>(
        _ api: API
    ) -> AsyncThrowingStream<DownloadEvent, any Error> {
        AsyncThrowingStream { continuation in
            let destination = api.destination
            let downloadTask = Self.startDownload(
                api: api,
                session: session,
                logger: logger,
                continuation: continuation
            )

            continuation.onTermination = { @Sendable [weak downloadTask] termination in
                downloadTask?.cancel()
                if case .cancelled = termination {
                    try? FileManager.default.removeItem(at: destination)
                }
            }
        }
    }

    private static func startDownload<API: DownloadAPI>(
        api: API,
        session: URLSession,
        logger: NetworkLogger,
        continuation: AsyncThrowingStream<DownloadEvent, any Error>.Continuation
    ) -> URLSessionDownloadTask? {
        guard let url = api.url else {
            logger.error("다운로드 실패: 유효하지 않은 URL")
            continuation.finish(throwing: NetworkError.invalidURL)
            return nil
        }

        let destination = api.destination
        let parentDirectory = destination.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: parentDirectory.path) else {
            continuation.finish(throwing: NetworkError.unknown(
                DownloadFileSystemError.cannotCreateFile(path: destination.path)
            ))
            return nil
        }

        logger.debug("다운로드 시작: \(api.httpMethod.rawValue) \(url.absoluteString)")

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = api.httpMethod.rawValue

        if let headers = api.headers {
            for (key, value) in headers.dictionary {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        let delegate = DownloadTaskDelegate(
            destination: destination,
            logger: logger,
            continuation: continuation
        )
        let task = session.downloadTask(with: urlRequest)
        task.delegate = delegate
        task.resume()
        return task
    }

    public func request<API: RequestAPI>(_ api: API) async throws -> API.Response {
        guard let url = api.url else {
            logger.error("요청 실패: 유효하지 않은 URL")
            throw NetworkError.invalidURL
        }

        logger.debug("요청 시작: \(api.httpMethod.rawValue) \(url.absoluteString)")

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
            let bodyEncoder = api.encoder ?? encoder
            do {
                urlRequest.httpBody = try bodyEncoder.encode(body)
                if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } catch {
                let networkError = error as? NetworkError ?? .encodingFailed(error)
                logger.error("요청 바디 인코딩 실패: \(networkError.localizedDescription)")
                throw networkError
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            logger.error("요청 실패: \(url.absoluteString) - \(error.localizedDescription)")
            throw NetworkError.unknown(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("요청 실패: 유효하지 않은 응답 - \(url.absoluteString)")
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("응답 실패 [\(httpResponse.statusCode)] \(url.absoluteString) - \(String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>")")
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                data: HTTPErrorData(body: data, response: httpResponse)
            )
        }

        logger.info("응답 성공 [\(httpResponse.statusCode)] \(url.absoluteString)")
        logger.debug("응답 본문: \(String(data: data, encoding: .utf8) ?? "<\(data.count) bytes>")")

        let responseDecoder = api.decoder ?? decoder
        do {
            let decodedResponse = try responseDecoder.decode(API.Response.self, from: data)
            return decodedResponse
        } catch {
            logger.error("디코딩 실패: \(API.Response.self) - \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}
