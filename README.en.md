# SimpleNetwork

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS_15.0+_|_macOS_12.0+-lightgray.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

📖 [한국어](README.md) · **English**

**SimpleNetwork** is a lightweight, protocol-oriented Swift networking library for modern iOS and macOS applications. It builds on Swift Concurrency (`async/await`, `AsyncThrowingStream`) to provide a clean, type-safe interface for HTTP requests and file downloads without the boilerplate of raw `URLSession`.

## Features

- 🏗 **Protocol-Oriented Design**: Describe endpoints declaratively with `RequestAPI` and `DownloadAPI`.
- ⚡️ **Swift Concurrency**: `async/await` for requests, `AsyncThrowingStream` for downloads. Strict concurrency checking is enabled.
- 🛡 **Type-Safe**: Responses, request bodies, query parameters, and headers are all strongly typed (`Decodable`, `Encodable`, `QueryParameter`, `HTTPHeaders`).
- ⬇️ **Download with Progress**: Stream `.progress` events and a final `.completed(URL)`, with automatic cleanup of partial files on cancellation.
- ⚙️ **Customizable Coding**: Inject your own `JSONEncoder`/`JSONDecoder`. Defaults perform **no key conversion** (`.useDefaultKeys`).
- 📝 **Built-in Logging**: `NetworkLogger` wraps `OSLog` and can be tuned or disabled per service.
- 🚨 **Typed Errors**: Failures surface as `NetworkError` with `LocalizedError` descriptions.

## Installation

### Swift Package Manager

Add `SimpleNetwork` as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/khyeji98/SimpleNetwork.git", .upToNextMajor(from: "1.2.0"))
]
```

Or add it via Xcode:
1. **File** > **Add Package Dependencies...**
2. Enter the repository URL: `https://github.com/khyeji98/SimpleNetwork.git`
3. Choose a version rule (e.g. Up to Next Major Version `1.2.0`)

## Usage

### 1. Define your models

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

### 2. Conform to `RequestAPI`

`RequestAPI` has two associated types — `Query` (a `QueryParameter`) and `Response` (`Decodable & Sendable`). `query`, `headers`, and `body` all default to `nil`, so you only declare what you need. Use `EmptyQuery` when there are no query parameters.

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

// MARK: - GET with query parameters
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

### 3. Execute a request

```swift
let networkService = URLSessionService()

Task {
    do {
        let user = try await networkService.request(GetUserAPI(id: 1))
        print("Fetched user: \(user.name)")

        let created = try await networkService.request(
            CreateUserAPI(newUser: CreateUserBody(name: "Alice"))
        )
        print("Created user: \(created.name)")
    } catch let error as NetworkError {
        print("Network error: \(error.localizedDescription)")
    } catch {
        print("Unexpected error: \(error)")
    }
}
```

`Content-Type: application/json` is set automatically when a `body` is present and the header is not already provided.

### 4. Download a file

Conform to `DownloadAPI` and consume the stream returned by `download(_:)`. The stream emits `.progress` zero or more times, then exactly one `.completed(destination)` before finishing.

```swift
struct DownloadFirmwareAPI: DownloadAPI {
    typealias Query = EmptyQuery

    var baseURL: String { "https://cdn.example.com" }
    var path: String { "/firmware/v1.bin" }
    let destination: URL
}

let networkService = URLSessionService()
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
                    print("downloaded \(progress.bytesTransferred) bytes")
                }

            case .completed(let url):
                print("saved to \(url)")
            }
        }
    } catch {
        print("Download failed: \(error)")
    }
}
```

- The parent directory of `destination` must exist beforehand; otherwise the stream finishes with `NetworkError.unknown`. An existing file at `destination` is overwritten.
- When the consuming `Task` is cancelled, the download task is cancelled and the partial file is removed. Call `try Task.checkCancellation()` inside the loop if you need cancellation propagated to your own code.
- `TransferProgress.fractionCompleted` is `nil` when the response carries no `Content-Length`.

### 5. Query parameters

Types conforming to `QueryParameter` are converted to `URLQueryItem`s automatically. Only flat key-value structures are supported — nested objects and arrays are skipped, and `nil` values are omitted. Items are sorted by name, and commas in values are percent-encoded as `%2C`.

Keys are **not** transformed by default. Override `keyEncodingStrategy` to change that:

```swift
struct SearchQuery: QueryParameter {
    let keyword: String
    let perPage: Int

    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy { .convertToSnakeCase }
}
// → ?keyword=swift&per_page=20
```

### 6. Headers

`HTTPHeaders` is a collection of `HTTPHeader` values. Duplicate names (case-insensitive) are overwritten by the last value, and it conforms to `ExpressibleByArrayLiteral`.

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

Available helpers: `authorization(_:)`, `authorization(bearer:)`, `contentType(_:)`, `accept(_:)`, `userAgent(_:)`, `acceptLanguage(_:)`, `custom(name:value:)`. `ContentType` covers `.json`, `.formURLEncoded`, `.multipartFormData`, `.xml`, `.plainText`.

### 7. Customize the service

```swift
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let networkService = URLSessionService(
    session: URLSession(configuration: .default),
    encoder: encoder,
    decoder: decoder,
    logger: NetworkLogger(category: "API", isEnabled: true)
)
```

Every parameter has a default: `.shared` session, plain `JSONEncoder()`/`JSONDecoder()` (no key conversion), and an enabled `NetworkLogger`. Pass `NetworkLogger(isEnabled: false)` to silence logging.

Depend on the `NetworkService` protocol rather than the concrete type to keep call sites testable:

```swift
final class UserRepository {
    private let networkService: any NetworkService

    init(networkService: any NetworkService = URLSessionService()) {
        self.networkService = networkService
    }
}
```

### 8. Logging

`NetworkLogger` wraps `os.Logger`, so output is visible in Console.app and Xcode. Requests, responses, and failures are logged at `debug`/`info`/`error` levels.

```swift
NetworkLogger(
    subsystem: Bundle.main.bundleIdentifier ?? "SimpleNetwork",
    category: "Network",
    isEnabled: true
)
```

## Error Handling

`request(_:)` and `download(_:)` fail with `NetworkError`:

| Case | Description |
| --- | --- |
| `.invalidURL` | `baseURL` + `path` + `query` could not form a valid URL. |
| `.invalidResponse` | The response was not an `HTTPURLResponse`. |
| `.encodingFailed` | Encoding the request body failed. |
| `.decodingFailed(any Error & Sendable)` | Decoding the response body failed. |
| `.httpError(statusCode: Int)` | The status code was outside `200...299`. |
| `.unknown(any Error & Sendable)` | Transport or file-system failure. |

`NetworkError` conforms to `LocalizedError`, so `errorDescription` returns a human-readable message.

## API Overview

| Type | Role |
| --- | --- |
| `NetworkService` | Protocol exposing `request(_:)` and `download(_:)`. |
| `URLSessionService` | `URLSession`-backed implementation. |
| `RequestAPI` | Endpoint definition for data requests. |
| `DownloadAPI` | Endpoint definition for file downloads. |
| `QueryParameter` / `EmptyQuery` | Automatic `URLQueryItem` conversion. |
| `HTTPHeader` / `HTTPHeaders` | Type-safe header construction. |
| `HTTPMethod` | `GET`, `POST`, `PUT`, `DELETE`, `PATCH`. |
| `DownloadEvent` | `.progress(TransferProgress)` / `.completed(URL)`. |
| `TransferProgress` | Transferred bytes, total bytes, completion fraction. |
| `NetworkError` | Typed networking failures. |
| `NetworkLogger` | `OSLog`-based logging. |

## Requirements

- iOS 15.0+
- macOS 12.0+
- Swift 5.9+

## License

SimpleNetwork is released under the MIT license. See [LICENSE](LICENSE) for details.
