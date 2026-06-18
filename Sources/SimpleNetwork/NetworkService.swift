//
//  NetworkService.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// 네트워크 요청을 수행하는 서비스 프로토콜입니다.
public protocol NetworkService: Sendable {
    func request<API: RequestAPI>(_ api: API) async throws -> API.Response

    /// 파일 다운로드를 수행하고 진행률/완료 이벤트를 스트림으로 방출합니다.
    ///
    /// 스트림은 `.progress`를 0회 이상, `.completed(destination)`을 정확히 1회 방출한 뒤 종료합니다.
    /// 소비자 Task가 취소되면 `CancellationError` 등으로 throw 종료하며, 부분 파일은 삭제됩니다.
    func download<API: DownloadAPI>(
        _ api: API
    ) -> AsyncThrowingStream<DownloadEvent, any Error>
}
