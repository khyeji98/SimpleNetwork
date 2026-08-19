# SimpleNetwork

![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS_15.0+_|_macOS_12.0+-lightgray.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

📖 [한국어](README.md) · **English**

> [!IMPORTANT]
> **2.0 is not compatible with 1.x.** The default JSON key conversion changed (1.x: automatic snake_case → 2.0: no conversion).
> Most affected call sites fail to compile, with one exception: `QueryParameter`.
> See the [migration guide](MIGRATION.en.md).

**SimpleNetwork** is a lightweight, protocol-oriented Swift networking library for modern iOS and macOS applications. It builds on Swift Concurrency (`async/await`, `AsyncThrowingStream`) to provide a clean, type-safe interface for HTTP requests and file downloads without the boilerplate of raw `URLSession`.

## Features

- 🏗 **Protocol-Oriented Design**: Describe endpoints declaratively with `RequestAPI` and `DownloadAPI`.
- ⚡️ **Swift Concurrency**: `async/await` for requests, `AsyncThrowingStream` for downloads. Strict concurrency checking is enabled.
- 🛡 **Type-Safe**: Responses, request bodies, query parameters, and headers are all strongly typed (`Decodable`, `Encodable`, `QueryParameter`, `HTTPHeaders`).
- ⬇️ **Download with Progress**: Stream `.progress` events and a final `.completed(URL)`, with automatic cleanup of partial files on cancellation.
- ⚙️ **Per-API Coding**: Set a default encoder/decoder on the service and override it on individual APIs with `BodyEncoder`/`ResponseDecoder`. The key strategy is **declared by the call site** — the library never picks one for you.
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

The encoder and decoder are required. Pass the plain instances when no key conversion is needed.

```swift
let networkService = URLSessionService(
    encoder: JSONBodyEncoder(),
    decoder: JSONResponseDecoder()
)

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

`session` and `logger` have defaults (`.shared` session, an enabled `NetworkLogger`). Pass `NetworkLogger(isEnabled: false)` to silence logging.

**`encoder` and `decoder` have no defaults.** The correct key strategy depends on the server, so the library cannot pick one for you — and a wrong default surfaces only as a runtime decoding failure after a successful build. Pass `JSONBodyEncoder()` / `JSONResponseDecoder()` when no conversion is needed.

The encoder and decoder set here are **defaults**. An individual API that overrides them takes precedence.

### 8. Override the encoder/decoder per API

When a single endpoint needs a different coding strategy, override it in the API declaration. Call sites stay the same.

```swift
struct LegacyUserAPI: RequestAPI {
    typealias Query = EmptyQuery
    typealias Response = User

    var httpMethod: HTTPMethod { .get }
    var baseURL: String { "https://api.example.com" }
    var path: String { "/legacy/user" }

    // Only this endpoint responds with snake_case
    var decoder: (any ResponseDecoder)? {
        JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)
    }
}
```

`BodyEncoder`/`ResponseDecoder` are `Sendable`, so an instance can be shared instead of rebuilt on every request.

```swift
struct UploadAPI: RequestAPI {
    private static let sharedEncoder = JSONBodyEncoder(maxByteCount: 1_000_000)

    var encoder: (any BodyEncoder)? { Self.sharedEncoder }
    ...
}
```

#### Body size limit

With `JSONBodyEncoder(maxByteCount:)`, an encoded body over the limit throws `NetworkError.bodyTooLarge` and the request is never sent.

```swift
var encoder: (any BodyEncoder)? { JSONBodyEncoder(maxByteCount: 1_000_000) }
```

```swift
do {
    _ = try await networkService.request(UploadAPI(payload: payload))
} catch NetworkError.bodyTooLarge(let byteCount, let limit) {
    print("Body too large: \(byteCount) / \(limit)")
}
```

> `Encodable` cannot report its size before encoding, so the check runs after encoding completes. It reliably prevents transmission, but it does not prevent the memory used during encoding itself.

#### Custom encoders

For policies beyond JSON — compression, signing, validation — implement `BodyEncoder` directly. Errors thrown here are preserved as the associated value of `NetworkError.encodingFailed`.

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

Depend on the `NetworkService` protocol rather than the concrete type to keep call sites testable:

```swift
final class UserRepository {
    private let networkService: any NetworkService

    init(networkService: any NetworkService) {
        self.networkService = networkService
    }
}
```

### 9. Logging

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
| `.encodingFailed(any Error & Sendable)` | Encoding the request body failed. |
| `.bodyTooLarge(byteCount: Int, limit: Int)` | The encoded body exceeded the allowed size. |
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
| `BodyEncoder` / `JSONBodyEncoder` | Request body encoding strategy (with size limit). |
| `ResponseDecoder` / `JSONResponseDecoder` | Response decoding strategy. |
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
