//
//  URLSessionService.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// URLSession을 사용하여 네트워크 요청을 수행하는 구현체입니다.
public final class URLSessionService: NetworkService {
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

    public func request<API: RequestAPI>(_ api: API) async throws -> API.Response {
        guard let url = api.url else {
            throw NetworkError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = api.httpMethod.rawValue
        
        // 1. 헤더 설정
        if let headers = api.headers {
            for (key, value) in headers {
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
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
