[한국어](MIGRATION.md) · 📖 English

# Migration Guide

## 1.x → 2.0

2.0 **changes the default JSON key conversion.** 1.x automatically converted requests, responses, and queries to snake_case; 2.0 performs no conversion at all.

If this change slips through, it surfaces only as a runtime decoding failure after a successful build. So 2.0 is designed to stop affected call sites **at compile time**. Work through the items below and the migration is complete.

---

### ① Creating `URLSessionService` — compile error

The defaults for `encoder`/`decoder` were removed. Calls that omitted them in 1.x no longer compile.

```swift
// 1.x — compile error in 2.0
let service = URLSessionService()
let service = URLSessionService(session: session)
```

**To keep 1.x behavior** (when your server uses snake_case):

```swift
let service = URLSessionService(
    encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase),
    decoder: JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)
)
```

**When no key conversion is needed:**

```swift
let service = URLSessionService(
    encoder: JSONBodyEncoder(),
    decoder: JSONResponseDecoder()
)
```

Not restoring a default is deliberate. The correct strategy depends on the server, so the library cannot choose for you — and whichever default it picked, the other half of its users would discover the problem only at runtime.

### ② Injecting `JSONEncoder`/`JSONDecoder` directly — compile error

Encoding and decoding are now abstracted behind the `BodyEncoder`/`ResponseDecoder` protocols, which makes `URLSessionService` concurrency-safe without `@unchecked Sendable`.

```swift
// 1.x
let encoder = JSONEncoder()
encoder.keyEncodingStrategy = .convertToSnakeCase

let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
decoder.dateDecodingStrategy = .iso8601

let service = URLSessionService(encoder: encoder, decoder: decoder)
```

```swift
// 2.0
let service = URLSessionService(
    encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase),
    decoder: JSONResponseDecoder(
        keyDecodingStrategy: .convertFromSnakeCase,
        dateDecodingStrategy: .iso8601
    )
)
```

If you need a strategy `JSONBodyEncoder`/`JSONResponseDecoder` does not expose, implement `BodyEncoder`/`ResponseDecoder` yourself — see "Override the encoder/decoder per API" in the README.

### ③ `NetworkError.noData` removed — compile error

The case was never thrown anywhere, so it was removed. Delete any code that referenced it.

### ④ `NetworkError.encodingFailed` gained an associated value — mostly harmless

It now carries the underlying error.

```swift
case encodingFailed(any Error & Sendable)
```

Pattern matching that ignores the associated value **still works**:

```swift
case .encodingFailed:            // 1.x code compiles unchanged
case .encodingFailed(let error): // when you need the cause
```

Only code that constructed `NetworkError.encodingFailed` as a value needs updating.

### ⑤ `NetworkError.httpError` associated value changed — update pattern matching

An `HTTPErrorData` associated value now preserves the body and headers of HTTP error responses. Each value is `nil` when it is unavailable or empty.

```swift
case .httpError(let statusCode, let data):
    print(statusCode, data.body as Any, data.headers as Any)
```

Existing `case .httpError(let statusCode)` patterns must accept or ignore the second associated value.

---

## ⚠️ The one change the compiler cannot catch: `QueryParameter`

**This is the only item the compiler will not flag.** Check it manually.

1.x converted query parameter keys to snake_case; the 2.0 default performs no conversion (`.useDefaultKeys`). Because the protocol extension supplies a default implementation, your existing `QueryParameter` types **compile unchanged while the transmitted query keys silently change.**

```swift
struct UserQuery: QueryParameter {
    let perPage: Int
}

// 1.x sent: ?per_page=20
// 2.0 sends: ?perPage=20
```

If your server expects snake_case queries, declare the strategy on the type:

```swift
struct UserQuery: QueryParameter {
    let perPage: Int

    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy {
        .convertToSnakeCase
    }
}
```

If every property name is already a single word (`page`, `limit`, …), both strategies produce the same result and nothing changes.

---

## Checklist

- [ ] Specified `encoder`/`decoder` at every `URLSessionService` call site
- [ ] Set `.convertToSnakeCase` / `.convertFromSnakeCase` if the server uses snake_case
- [ ] **Audited every type conforming to `QueryParameter`** (the item with no compile error)
- [ ] Removed references to `NetworkError.noData`
- [ ] Verified request and response keys once against a real server or integration test
