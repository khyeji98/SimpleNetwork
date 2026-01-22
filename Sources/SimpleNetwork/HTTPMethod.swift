//
//  HTTPMethod.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// HTTP 요청 메서드를 정의합니다.
public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}
