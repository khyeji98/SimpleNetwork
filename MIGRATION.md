📖 한국어 · [English](MIGRATION.en.md)

# 마이그레이션 가이드

## 1.x → 2.0

2.0은 **JSON 키 변환 기본 동작을 바꿉니다.** 1.x는 요청·응답·쿼리 모두 snake_case로 자동 변환했지만, 2.0은 어떤 변환도 하지 않습니다.

이 변경은 잘못 넘어가면 빌드가 성공한 뒤 런타임 디코딩 실패로만 드러납니다. 그래서 2.0은 영향을 받는 호출부가 **컴파일 단계에서 멈추도록** 설계했습니다. 아래 항목을 모두 처리하면 마이그레이션이 끝납니다.

---

### ① `URLSessionService` 생성 — 컴파일 에러

`encoder`/`decoder`에서 기본값을 제거했습니다. 1.x에서 생략하던 호출은 이제 컴파일되지 않습니다.

```swift
// 1.x — 2.0에서 컴파일 에러
let service = URLSessionService()
let service = URLSessionService(session: session)
```

**1.x와 동일하게 동작시키려면** (서버가 snake_case인 경우):

```swift
let service = URLSessionService(
    encoder: JSONBodyEncoder(keyEncodingStrategy: .convertToSnakeCase),
    decoder: JSONResponseDecoder(keyDecodingStrategy: .convertFromSnakeCase)
)
```

**키 변환이 필요 없다면:**

```swift
let service = URLSessionService(
    encoder: JSONBodyEncoder(),
    decoder: JSONResponseDecoder()
)
```

기본값을 되살리지 않은 것은 의도된 선택입니다. 올바른 전략은 서버 스펙에 달려 있어 라이브러리가 대신 정할 수 없고, 어느 쪽을 기본값으로 삼든 나머지 절반의 사용자는 런타임에야 문제를 발견하게 됩니다.

### ② `JSONEncoder`/`JSONDecoder` 직접 주입 — 컴파일 에러

인코딩·디코딩이 `BodyEncoder`/`ResponseDecoder` 프로토콜로 추상화되었습니다. `URLSessionService`가 `@unchecked Sendable` 없이 동시성 안전해집니다.

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

`JSONBodyEncoder`/`JSONResponseDecoder`가 지원하지 않는 전략이 필요하면 `BodyEncoder`/`ResponseDecoder`를 직접 구현하세요. 자세한 내용은 README의 "API별 인코더/디코더 재정의"를 참고하세요.

### ③ `NetworkError.noData` 제거 — 컴파일 에러

어디서도 던져지지 않던 케이스라 제거했습니다. 참조하던 코드는 삭제하면 됩니다.

### ④ `NetworkError.encodingFailed` 연관값 추가 — 대부분 영향 없음

원인 에러를 담도록 바뀌었습니다.

```swift
case encodingFailed(any Error & Sendable)
```

연관값을 무시하는 패턴 매칭은 **그대로 동작합니다.**

```swift
case .encodingFailed:            // 1.x 코드 그대로 컴파일됨
case .encodingFailed(let error): // 원인 에러가 필요하면
```

`NetworkError.encodingFailed`를 값으로 직접 생성하던 코드만 수정이 필요합니다.

### ⑤ `NetworkError.httpError` 연관값 변경 — 패턴 매칭 수정

HTTP 오류 응답의 바디와 헤더를 보존하도록 `HTTPErrorData` 연관값이 추가되었습니다. 두 값은 응답에 없거나 비어 있으면 각각 `nil`입니다.

```swift
case .httpError(let statusCode, let data):
    print(statusCode, data.body as Any, data.headers as Any)
```

기존 `case .httpError(let statusCode)` 패턴은 두 번째 연관값을 받거나 무시하도록 수정해야 합니다.

---

## ⚠️ 컴파일 에러가 나지 않는 유일한 변경: `QueryParameter`

**이 항목만은 컴파일러가 잡아주지 못합니다.** 반드시 직접 확인하세요.

1.x는 쿼리 파라미터 키를 snake_case로 변환했지만, 2.0의 기본값은 변환하지 않음(`.useDefaultKeys`)입니다. 프로토콜 확장에 기본 구현이 있어 기존 `QueryParameter` 타입은 **수정 없이 컴파일되고, 전송되는 쿼리 키만 조용히 바뀝니다.**

```swift
struct UserQuery: QueryParameter {
    let perPage: Int
}

// 1.x가 보내던 것: ?per_page=20
// 2.0이 보내는 것: ?perPage=20
```

서버가 snake_case 쿼리를 기대한다면 해당 타입에 전략을 명시하세요.

```swift
struct UserQuery: QueryParameter {
    let perPage: Int

    var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy {
        .convertToSnakeCase
    }
}
```

프로퍼티 이름이 이미 전부 단일 단어(`page`, `limit` 등)라면 두 전략의 결과가 같으므로 영향이 없습니다.

---

## 점검 목록

- [ ] `URLSessionService` 생성부에서 `encoder`/`decoder`를 명시했다
- [ ] 서버가 snake_case라면 두 전략에 `.convertToSnakeCase` / `.convertFromSnakeCase`를 지정했다
- [ ] **모든 `QueryParameter` 채택 타입을 확인했다** (컴파일 에러가 나지 않는 항목)
- [ ] `NetworkError.noData` 참조를 제거했다
- [ ] 통합 테스트 또는 실제 서버 호출로 요청·응답 키를 한 번 검증했다
