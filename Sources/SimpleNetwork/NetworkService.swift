//
//  NetworkService.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 네트워크 요청을 수행하는 서비스 프로토콜입니다.
public protocol NetworkService {
    func request<API: RequestAPI>(_ api: API) async throws -> API.Response
}
