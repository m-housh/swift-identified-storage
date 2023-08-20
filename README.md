# swift-identified-storage

A swift package for mocking remote storage with a `CRUD` like interface.

# Motivation

It is often required to mock database clients for purposes of Xcode previews or testing
code without using a live client.  This package is built on top of the `IdentifiedArray` type
from [swift-identified-collections](https://github.com/pointfreeco/swift-identified-collections) and
the [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).

# Installation

Install this as a swift package into your project.

```swift
import PackageDescription

let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/m-housh/swift-identified-storage.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "<My Target>",
            dependencies: [
                .product(name: "IdentifiedStorage", package: "swift-identified-storage")
            ]
        )
    ]
)
```

# Basic Usage

Given the following `Todo` model.

```swift
struct Todo: Equatable, Identifiable {
  var id: UUID
  var description: String
  var isComplete: Bool = true
}
```

And the todo client interface.

```swift
struct TodoClient {

  var delete: (Todo.ID) async throws -> Void
  var fetch: (FetchRequest) async throws -> IdentifiedArrayOf<Todo>
  var insert: (InsertRequest) async throws -> Todo
  var update: (Todo.ID, UpdateRequest) async throws -> Todo

  func fetch() async throws -> IdentifiedArrayOf<Todo> {
    try await self.fetch(.all)
  }

  enum FetchRequest {
    case all
    case filtered(by: Filter)

    enum Filter {
      case complete
      case incomplete
    }
  }

  struct InsertRequest {
    let description: String
  }

  struct UpdateRequest {
    let description: String
  }
}
```

Conform the request types to the appropriate conversion types.

```swift
#if DEBUG
extension TodoClient.FetchRequest: FetchRequestConvertible {

  func fetch(from values: IdentifiedArrayOf<Todo>) -> IdentifiedArrayOf<Todo> {
    switch self {
    case .all:
      return values
    case let .filtered(by: filter):
      return values.filter {
        $0.isComplete == (filter == .complete ? true : false)
      }
    }
  }
}

extension TodoClient.InsertRequest: InsertRequestConvertible {
  func transform() -> Todo {
    @Dependency(\.uuid) var uuid;
    return .init(id: uuid(), description: description)
  }
}

extension TodoClient.UpdateRequest: UpdateRequestConvertible {
  func apply(to state: inout Todo) {
    state.description = description
  }
}
#endif
```

Create a mock client factory.

```swift
#if DEBUG
extension TodoClient {
  static func mock(
    initialValues todos: IdentifiedArrayOf<Todo>,
    timeDelays: IdentifiedStorageDelays? = .default
  ) -> Self {

    // using the `IdentifiedStorage` as the storage for the mock client.
    // this uses the passed in time delays to simulate a remote data store for
    // use in previews and tests.
    let storage = IdentifiedStorageOf<Todo>(
      initialValues: todos,
      timeDelays: timeDelays
    )

    return .init(
      delete: { try await storage.delete(id: $0) },
      fetch: { try await storage.fetch(request: $0) },
      insert: { try await storage.insert(request: $0) },
      update: { try await storage.update(id: $0, request: $1) }
    )
  }
}
#endif
```

# Documentation

View the api documentation [here](https://m-housh.github.io/swift-identified-storage/documentation/identifiedstorage/).
