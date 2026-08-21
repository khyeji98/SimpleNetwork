# SimpleNetwork

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS_15.0+_|_macOS_12.0+-lightgray.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

📖 **한국어** · [English](README.en.md)

> [!IMPORTANT]
> **2.0은 1.x와 호환되지 않습니다.** JSON 키 변환 기본 동작이 바뀌었습니다(1.x: snake_case 자동 변환 → 2.0: 변환 없음).
> 영향을 받는 호출부는 대부분 컴파일 에러로 드러나지만, `QueryParameter`만은 예외입니다.
> [마이그레이션 가이드](MIGRATION.md)를 확인하세요.

**SimpleNetwork**는 iOS·macOS 앱을 위한 가볍고 프로토콜 지향적인 Swift 네트워킹 라이브러리입니다. Swift Concurrency(`async/await`, `AsyncThrowingStream`)를 기반으로, `URLSession`을 직접 다룰 때의 보일러플레이트 없이 HTTP 요청과 파일 다운로드를 타입 안전하게 처리합니다.

## 주요 기능

- 🏗 **프로토콜 지향 설계**: `RequestAPI`, `DownloadAPI`로 엔드포인트를 선언적으로 정의합니다.
- ⚡️ **Swift Concurrency**: 요청은 `async/await`, 다운로드는 `AsyncThrowingStream`으로 처리하며 Strict Concurrency 검사가 활성화되어 있습니다.
- 🛡 **타입 안전성**: 응답, 요청 바디, 쿼리 파라미터, 헤더가 모두 타입으로 표현됩니다 (`Decodable`, `Encodable`, `QueryParameter`, `HTTPHeaders`).
- ⬇️ **진행률 기반 다운로드**: `.progress` 이벤트를 스트리밍하고 마지막에 `.completed(URL)`을 방출하며, 취소 시 부분 파일을 자동으로 정리합니다.
- ⚙️ **API별 코딩 전략**: 서비스에 기본 인코더/디코더를 두고, 특정 API에서만 `BodyEncoder`/`ResponseDecoder`로 재정의할 수 있습니다. 키 변환 전략은 **호출부가 명시**하며, 라이브러리가 임의의 기본값을 정하지 않습니다.
- 📝 **내장 로깅**: `OSLog`를 래핑한 `NetworkLogger`를 서비스 단위로 설정하거나 끌 수 있습니다.
- 🚨 **타입화된 에러**: 모든 실패는 `LocalizedError`를 채택한 `NetworkError`로 전달됩니다.

## 설치

### Swift Package Manager

`Package.swift`에 의존성을 추가합니다.

```swift
dependencies: [
    .package(url: "https://github.com/khyeji98/SimpleNetwork.git", .upToNextMajor(from: "1.2.0"))
]
```

또는 Xcode에서 직접 추가합니다.
1. **File** > **Add Package Dependencies...**
2. 저장소 URL 입력: `https://github.com/khyeji98/SimpleNetwork.git`
3. 버전 규칙 선택 (예: Up to Next Major Version `1.2.0`)

## 사용법

### 1. 모델 정의

```swift
import Foundation

struct User: Decodable, Sendable {
    let id: Int
    let name: String
    let profileImageURL: String?
}

struct CreateUserBody: Encodable, Sendable {
    let name: String
}
```

### 2. `RequestAPI` 채택

`RequestAPI`는 두 개의 associated type을 가집니다 — `Query`(`QueryParameter` 채택)와 `Response`(`Decodable & Sendable`). `query`, `headers`, `body`는 모두 기본값이 `nil`이므로 필요한 것만 선언하면 됩니다. 쿼리 파라미터가 없는 경우 `EmptyQuery`를 사용합니다.

```swift
import SimpleNetwork

// MARK: - GET
struct GetUserAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = User

    let id: Int

    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users/\(id)" }
    var httpMethod: HTTPMethod { .get }
}

// MARK: - 쿼리 파라미터가 있는 GET
struct SearchUsersQuery: QueryParameter {
    let keyword: String
    let page: Int
}

struct SearchUsersAPI: RequestAPI {
    typealias Response = [User]

    let query: SearchUsersQuery?

    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var httpMethod: HTTPMethod { .get }
}

// MARK: - POST
struct CreateUserAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = User

    let newUser: CreateUserBody

    var baseURL: String { "https://api.example.com" }
    var path: String { "/v1/users" }
    var httpMethod: HTTPMethod { .post }
    var headers: HTTPHeaders? { [.authorization(bearer: "YOUR_ACCESS_TOKEN")] }
    var body: (any Encodable & Sendable)? { newUser }
}
```

### 3. 요청 실행

인코더와 디코더는 반드시 명시합니다. 키를 변환하지 않으려면 아래처럼 기본 구성을 그대로 전달하세요.

```swift
let networkService = URLSessionService(
    encoder: JSONBodyEncoder(),
    decoder: JSONResponseDecoder()
)

Task {
    do {
        let user = try await networkService.request(GetUserAPI(id: 1))
        print("조회한 유저: \(user.name)")

        let created = try await networkService.request(
            CreateUserAPI(newUser: CreateUserBody(name: "Alice"))
        )
        print("생성한 유저: \(created.name)")
    } catch let error as NetworkError {
        print("네트워크 에러: \(error.localizedDescription)")
    } catch {
        print("예상치 못한 에러: \(error)")
    }
}
```

`body`가 있고 `Content-Type` 헤더를 직접 지정하지 않은 경우 `application/json`이 자동으로 설정됩니다.

### 4. 파일 다운로드

`DownloadAPI`를 채택하고 `download(_:)`가 반환하는 스트림을 소비합니다. 스트림은 `.progress`를 0회 이상 방출한 뒤, 종료 직전에 `.completed(destination)`을 정확히 한 번 방출합니다.

```swift
struct DownloadFirmwareAPI: DownloadAPI {
    typealias Query = EmptyQuery

    var baseURL: String { "https://cdn.example.com" }
    var path: String { "/firmware/v1.bin" }
    let destination: URL
}

let networkService = URLSessionService(
    encoder: JSONBodyEncoder(),
    decoder: JSONResponseDecoder()
)
let destination = FileManager.default.temporaryDirectory
    .appendingPathComponent("firmware.bin")

Task {
    do {
        let api = DownloadFirmwareAPI(destination: destination)
        for try await event in networkService.download(api) {
            switch event {
            case .progress(let progress):
                if let fraction = progress.fractionCompleted {
                    print("\(Int(fraction * 100))% — \(progress.bytesTransferred) bytes")
                } else {
                    print("\(progress.bytesTransferred) bytes 다운로드됨")
                }

            case .completed(let url):
                print("저장 완료: \(url)")
            }
        }
    } catch {
        print("다운로드 실패: \(error)")
    }
}
```

- `destination`의 상위 디렉터리는 호출자가 미리 생성해야 합니다. 존재하지 않으면 스트림이 `NetworkError.unknown`으로 종료됩니다. 같은 경로에 파일이 있으면 덮어씁니다.
- 소비하는 `Task`가 취소되면 다운로드 태스크가 취소되고 부분 파일이 삭제됩니다. 취소를 자신의 코드로 전파하려면 루프 안에서 `try Task.checkCancellation()`을 호출하세요.
- 응답에 `Content-Length`가 없으면 `TransferProgress.fractionCompleted`는 `nil`입니다.

### 5. 쿼리 파라미터

`QueryParameter`를 채택한 타입은 자동으로 `URLQueryItem` 배열로 변환됩니다. 플랫한 key-value 구조만 지원하며 중첩 객체와 배열은 제외되고, `nil` 값은 생략됩니다. 항목은 이름순으로 정렬되며, 값에 포함된 쉼표는 `%2C`로 퍼센트 인코딩됩니다.

키는 기본적으로 **변환되지 않습니다**. 변환이 필요하면 `keyEncodingStrategy`를 재정의하세요.
`Date` 값의 기본 전략은 `.deferredToDate`이며, 서버 포맷에 맞게 `dateEncodingStrategy`를 재정의할 수 있습니다.

```swift
struct SearchQuery: QueryParameter {
    let keyword: String
    let perPage: Int
    let createdAfter: Date

    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy { .convertToSnakeCase }
    var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy { .iso8601 }
}
// → ?created_after=2026-08-20T00:00:00Z&keyword=swift&per_page=20
```

### 6. 헤더

`HTTPHeaders`는 `HTTPHeader`의 컬렉션입니다. 이름이 중복되면(대소문자 무시) 마지막 값으로 덮어쓰며, `ExpressibleByArrayLiteral`을 채택하고 있습니다.

```swift
var headers: HTTPHeaders? {
    [
        .authorization(bearer: token),
        .contentType(.json),
        .accept(.json),
        .acceptLanguage("ko-KR"),
        .custom(name: "X-Request-ID", value: requestID)
    ]
}
```

제공되는 헬퍼: `authorization(_:)`, `authorization(bearer:)`, `contentType(_:)`, `accept(_:)`, `userAgent(_:)`, `acceptLanguage(_:)`, `custom(name:value:)`. `ContentType`은 `.json`, `.formURLEncoded`, `.multipartFormData`, `.xml`, `.plainText`를 지원합니다.

### 7. 서비스 커스터마이징

```swift
let networkService = URLSessionService(
    session: URLSession(configuration: .default),
    encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase),
    decoder: JSONResponseDecoder(
        keyDecodingStrategy: .convertFromSnakeCase,
        dateDecodingStrategy: .iso8601
    ),
    logger: NetworkLogger(category: "API", isEnabled: true)
)
```

`session`과 `logger`에는 기본값이 있습니다(`.shared` 세션, 활성화된 `NetworkLogger`). 로깅을 끄려면 `NetworkLogger(isEnabled: false)`를 전달하세요.

**`encoder`와 `decoder`에는 기본값이 없습니다.** 올바른 키 변환 전략은 서버 스펙에 달려 있어 라이브러리가 대신 정할 수 없고, 잘못된 기본값은 빌드를 통과한 뒤 런타임 디코딩 실패로만 드러나기 때문입니다. 변환이 필요 없으면 `JSONBodyEncoder()` / `JSONResponseDecoder()`를 그대로 전달하세요.

여기서 지정한 인코더/디코더는 **기본값**입니다. 개별 API가 재정의하면 그쪽이 우선합니다.

### 8. API별 인코더/디코더 재정의

특정 엔드포인트만 다른 코딩 전략이 필요하다면 API 선언부에서 재정의합니다. 호출부는 바뀌지 않습니다.

```swift
struct LegacyUserAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = User

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/legacy/user" }

    // 이 API의 응답만 snake_case로 내려오는 경우
    var decoder: (any ResponseDecoder)? {
        JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)
    }
}
```

`BodyEncoder`/`ResponseDecoder`는 `Sendable`이므로 매번 새로 만들지 않고 공유할 수 있습니다.

```swift
struct UploadAPI: RequestAPI {
    private static let sharedEncoder = JSONBodyEncoder()

    var encoder: (any BodyEncoder)? { Self.sharedEncoder }
    ...
}
```

#### 커스텀 인코더 구현

압축, 서명, 검증 등 JSON 외의 정책이 필요하면 `BodyEncoder`를 직접 구현합니다. 여기서 던진 에러는 `NetworkError.encodingFailed`의 연관값으로 보존됩니다.

바디 크기 제한도 라이브러리의 기본 정책이 아니라 커스텀 인코더에서 정의합니다.

```swift
struct SignedBodyEncoder: BodyEncoder {
    let secret: String

    func encode(_ body: any Encodable & Sendable) throws -> Data {
        let data = try JSONBodyEncoder().encode(body)
        guard let signed = sign(data, with: secret) else { throw SigningError.failed }

        return signed
    }
}
```

테스트 용이성을 위해 구체 타입 대신 `NetworkService` 프로토콜에 의존하는 것을 권장합니다.

```swift
final class UserRepository {
    private let networkService: any NetworkService

    init(networkService: any NetworkService) {
        self.networkService = networkService
    }
}
```

### 9. 로깅

`NetworkLogger`는 `os.Logger`를 래핑하므로 Console.app과 Xcode 콘솔에서 로그를 확인할 수 있습니다. 요청, 응답, 실패가 각각 `debug`/`info`/`error` 레벨로 기록됩니다.

```swift
NetworkLogger(
    subsystem: Bundle.main.bundleIdentifier ?? "SimpleNetwork",
    category: "Network",
    isEnabled: true
)
```

## 에러 처리

`request(_:)`와 `download(_:)`는 `NetworkError`로 실패합니다.

| 케이스 | 설명 |
| --- | --- |
| `.invalidURL` | `baseURL` + `path` + `query`로 유효한 URL을 만들지 못한 경우 |
| `.invalidResponse` | 응답이 `HTTPURLResponse`가 아닌 경우 |
| `.encodingFailed(any Error & Sendable)` | 요청 바디 인코딩에 실패한 경우 |
| `.decodingFailed(any Error & Sendable)` | 응답 바디 디코딩에 실패한 경우 |
| `.httpError(statusCode: Int, data: HTTPErrorData)` | 상태 코드가 `200...299` 범위를 벗어난 경우. 응답 바디와 헤더를 함께 전달 |
| `.unknown(any Error & Sendable)` | 전송 또는 파일시스템 단계에서 실패한 경우 |

`HTTPErrorData.body`와 `HTTPErrorData.headers`는 응답 값이 없거나 비어 있으면 각각 `nil`입니다.

`NetworkError`는 `LocalizedError`를 채택하므로 `errorDescription`으로 사람이 읽을 수 있는 메시지를 얻을 수 있습니다.

## API 개요

| 타입 | 역할 |
| --- | --- |
| `NetworkService` | `request(_:)`와 `download(_:)`를 노출하는 프로토콜 |
| `URLSessionService` | `URLSession` 기반 구현체 |
| `RequestAPI` | 데이터 요청 엔드포인트 정의 |
| `DownloadAPI` | 파일 다운로드 엔드포인트 정의 |
| `QueryParameter` / `EmptyQuery` | `URLQueryItem` 자동 변환 |
| `HTTPHeader` / `HTTPHeaders` | 타입 안전한 헤더 구성 |
| `BodyEncoder` / `JSONBodyEncoder` | 요청 바디 인코딩 전략 |
| `ResponseDecoder` / `JSONResponseDecoder` | 응답 디코딩 전략 |
| `HTTPMethod` | `GET`, `POST`, `PUT`, `DELETE`, `PATCH` |
| `DownloadEvent` | `.progress(TransferProgress)` / `.completed(URL)` |
| `TransferProgress` | 전송된 바이트, 전체 바이트, 완료 비율 |
| `HTTPErrorData` | HTTP 오류 응답의 optional 바디와 헤더 |
| `NetworkError` | 타입화된 네트워킹 실패 |
| `NetworkLogger` | `OSLog` 기반 로깅 |

## 요구 사항

- iOS 15.0+
- macOS 12.0+
- Swift 5.9+

## 라이선스

SimpleNetwork는 MIT 라이선스로 배포됩니다. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
