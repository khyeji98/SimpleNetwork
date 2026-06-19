//
//  DownloadTaskDelegate.swift
//  SimpleNetwork
//
//  Created by 김혜지.
//

import Foundation

/// `URLSessionDownloadTask`의 진행률·완료·에러 콜백을 `AsyncThrowingStream`으로 중계하는 델리게이트입니다.
///
/// `AsyncBytes`를 바이트 단위로 순회하는 방식은 바이트마다 suspension point가 발생해
/// 대용량 파일에서 CPU 과부하를 유발합니다. 전송을 시스템 다운로드 태스크에 위임하여
/// 임시 파일에 기록하게 하고, 완료 시점에 `destination`으로 이동시킵니다.
///
/// 델리게이트 콜백은 세션의 직렬 `delegateQueue`에서 호출되므로 내부 가변 상태
/// 접근은 직렬화됩니다. `URLSession` 타입이 Sendable로 표시되지 않아 `@unchecked Sendable`로 선언합니다.
final class DownloadTaskDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let destination: URL
    private let logger: NetworkLogger
    private let continuation: AsyncThrowingStream<DownloadEvent, any Error>.Continuation

    private var didFinish = false
    private var lastBytesWritten: Int64 = 0

    init(
        destination: URL,
        logger: NetworkLogger,
        continuation: AsyncThrowingStream<DownloadEvent, any Error>.Continuation
    ) {
        self.destination = destination
        self.logger = logger
        self.continuation = continuation
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard isSuccessResponse(downloadTask.response) else { return }

        lastBytesWritten = totalBytesWritten
        continuation.yield(.progress(TransferProgress(
            bytesTransferred: totalBytesWritten,
            totalBytes: expectedTotal(totalBytesExpectedToWrite)
        )))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let httpResponse = downloadTask.response as? HTTPURLResponse else {
            logger.error("다운로드 실패: 유효하지 않은 응답")
            finish(throwing: NetworkError.invalidResponse)
            return
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            logger.error("다운로드 응답 실패 [\(httpResponse.statusCode)] \(httpResponse.url?.absoluteString ?? "")")
            finish(throwing: NetworkError.httpError(statusCode: httpResponse.statusCode))
            return
        }

        do {
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
        } catch {
            finish(throwing: NetworkError.unknown(error))
            return
        }

        let total = expectedTotal(httpResponse.expectedContentLength)
        let finalBytes = total ?? lastBytesWritten
        continuation.yield(.progress(TransferProgress(
            bytesTransferred: finalBytes,
            totalBytes: total
        )))
        logger.info("다운로드 완료: \(finalBytes) bytes → \(destination.path)")
        continuation.yield(.completed(destination))
        continuation.finish()
        didFinish = true
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: (any Error)?
    ) {
        guard let error else {
            if !didFinish { continuation.finish() }
            return
        }

        if (error as? URLError)?.code == .cancelled {
            logger.debug("다운로드 취소됨")
            continuation.finish(throwing: CancellationError())
        } else {
            logger.error("다운로드 실패: \(error.localizedDescription)")
            continuation.finish(throwing: NetworkError.unknown(error))
        }
    }

    private func finish(throwing error: any Error) {
        didFinish = true
        continuation.finish(throwing: error)
    }

    private func isSuccessResponse(_ response: URLResponse?) -> Bool {
        guard let httpResponse = response as? HTTPURLResponse else { return false }

        return (200...299).contains(httpResponse.statusCode)
    }

    private func expectedTotal(_ value: Int64) -> Int64? {
        value > 0 ? value : nil
    }
}
