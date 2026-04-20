//
//  NetworkError.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 네트워크 요청 중 발생할 수 있는 에러를 정의합니다.
public enum NetworkError: Error, Sendable {
    case invalidURL
    case invalidResponse
    case encodingFailed
    case noData
    case decodingFailed(any Error & Sendable)
    case httpError(statusCode: Int)
    case unknown(any Error & Sendable)
}

extension NetworkError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "유효하지 않은 URL입니다."
        case .invalidResponse:
            return "유효하지 않은 URLResponse입니다."
        case .encodingFailed:
            return "요청 데이터 인코딩에 실패했습니다."
        case .noData:
            return "서버로부터 데이터를 받지 못했습니다."
        case .decodingFailed(let error):
            return "응답 데이터 디코딩에 실패했습니다: \(error.localizedDescription)"
        case .httpError(let statusCode):
            return "HTTP 에러가 발생했습니다. 상태 코드: \(statusCode)"
        case .unknown(let error):
            return "알 수 없는 에러가 발생했습니다: \(error.localizedDescription)"
        }
    }
}
