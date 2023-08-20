import Dependencies
import Foundation
@_exported import IdentifiedCollections
import OrderedCollections
import XCTestDynamicOverlay

/// An identified array storage type that offers a `CRUD` like interface.
///
/// This is often useful for mocking remote data stores for previews or testing.
///
public actor IdentifiedStorage<ID, Element> where ID: Hashable {

  @Dependency(\.continuousClock) var clock

  // The element storage.
  @usableFromInline
  var storage: IdentifiedArray<ID, Element>

  // The time delays.
  @usableFromInline
  var timeDelays: IdentifiedStorageDelays?

  /// Create a new storage instance with the initial values and time delays.
  ///
  ///  - Parameters:
  ///   - storage: The initial values for the storage.
  ///   - timeDelays: Time delays used in the query operations.
  @inlinable
  @inline(__always)
  public init(
    id: KeyPath<Element, ID>,
    initialValues storage: [Element] = [],
    timeDelays: IdentifiedStorageDelays? = .default
  ) {
    self.storage = .init(uniqueElements: storage, id: id)
    self.timeDelays = timeDelays
  }

  /// Delete an element by it's id.
  @inlinable
  public func delete(id: ID) async throws {
    self.storage[id: id] = nil
    try await self.sleep(using: \.delete)
  }

  /// Delete all elements matching the predicate.
  ///
  /// - Parameters:
  ///   - shouldDelete: The predicate which returns `true` for elements to remove.
  @inlinable
  public func delete(where shouldDelete: @escaping (Element) -> Bool) async throws {
    self.storage.removeAll(where: shouldDelete)
    try await self.sleep(using: \.delete)
  }

  /// Inserts a new element in the storage.
  ///
  /// - Parameters:
  ///   - request: The insert request.
  @inlinable
  public func insert<R: InsertRequestConvertible>(
    request: R
  ) async throws -> Element where R.Value == Element {
    let element = request.transform()
    storage.append(element)
    return element
  }

  /// Fetches all the elements in the storage.
  @inlinable
  public func fetch() async throws -> IdentifiedArray<ID, Element> {
    try await self.sleep(using: \.fetch)
    return storage
  }

  /// Fetches all the elements in the storage for the given fetch request.
  ///
  ///  - Parameters:
  ///   - request: The fetch request to perform.
  @inlinable
  public func fetch<R: FetchRequestConvertible>(
    request: R
  ) async throws -> IdentifiedArray<ID, Element> where R.Value == Element, R.ID == ID {
    try await self.sleep(using: \.fetch)
    return request.fetch(from: storage)
  }

  /// Fetches an element by it's id from the storage, if it exists.
  ///
  ///  - Parameters:
  ///   - id: The element to fetch from the storage, if it exists.
  @inlinable
  public func fetchOne(id: ID) async throws -> Element? {
    try await self.sleep(using: \.fetch)
    return storage[id: id]
  }

  /// Fetches an element for the given request from the storage, if it exists.
  ///
  ///  - Parameters:
  ///   - request: The element to fetch from the storage, if it exists.
  @inlinable
  public func fetchOne<R: FetchOneRequestConvertible>(
    request: R
  ) async throws -> Element? where R.Value == Element, R.ID == ID {
    try await self.sleep(using: \.fetch)
    return request.fetchOne(from: storage)
  }

  // Helper for sleeping for a duration to mimick a remote storage container.
  @usableFromInline
  func sleep(
    using keyPath: KeyPath<IdentifiedStorageDelays, ContinuousClock.Duration>,
    tolerance: ContinuousClock.Duration? = nil
  ) async throws {
    guard let timeDelays else { return }
    try await clock.sleep(for: timeDelays[keyPath: keyPath], tolerance: tolerance)
  }

  /// Set new elements in the storage, discarding any existing elements.
  ///
  ///  - Parameters:
  ///   - elements: The new elements for the storage.
  @inlinable
  @discardableResult
  public func set(
    elements: IdentifiedArray<ID, Element>
  ) async -> IdentifiedArray<ID, Element> {
    self.storage = elements
    return elements
  }

  /// Access all the elements in the storage as an async stream of elements.
  @inlinable
  public func stream() -> AsyncThrowingStream<Element, Error> {
    .init { continuation in
      Task {
        for element in storage {
          try await sleep(using: \.fetch)
          continuation.yield(element)
        }
        continuation.finish()
      }
    }
  }

  /// Access all the elements in the storage for the given request as an async stream of elements.
  ///
  ///  - Parameters:
  ///   - request: The fetch request for the elements to stream.
  @inlinable
  public func stream<R: FetchRequestConvertible>(
    request: R
  ) -> AsyncThrowingStream<Element, Error> where R.Value == Element, R.ID == ID {
    .init { continuation in
      Task {
        let values = try await self.fetch(request: request)
        for value in values {
          try await sleep(using: \.fetch)
          continuation.yield(value)
        }
        continuation.finish()
      }
    }
  }

  /// Update an element in the storage, throwing an error and runtime warning if it does not exist.
  ///
  ///  - Parameters:
  ///   - id: The element id to update.
  ///   - request: The element to update request conversion.
  @inlinable
  public func update<R: UpdateRequestConvertible>(
    id: R.ID,
    request: R
  ) async throws -> Element where R.Value == Element, R.ID == ID {

    guard var element = self.storage[id: id] else {
      XCTFail("Update called on an element that was not found in the storage. \(id)")
      throw ElementNotFoundError(id: id, ids: storage.ids)
    }

    request.apply(to: &element)
    self.storage[id: id] = element
    try await self.sleep(using: \.update)
    return element
  }

  /// Access the values in storage for a custom response type.
  ///
  /// This is useful if you need to provide an extension or custom query to the storage container.
  ///
  ///  - Parameters:
  ///   - perform: The closure to build your custom response from the values in storage.
  @inlinable
  @discardableResult
  public func withValues<Response>(
    perform: @escaping @Sendable (IdentifiedArray<ID, Element>) async throws -> Response
  ) async rethrows -> Response {
    try await perform(storage)
  }
}

extension IdentifiedStorage where Element: Identifiable, ID == Element.ID {

  /// Create a new storage instance with the initial values and time delays.
  ///
  ///  - Parameters:
  ///   - storage: The initial values for the storage.
  ///   - timeDelays: Time delays used in the query operations.
  @inlinable
  public init(
    initialValues storage: [Element] = [],
    timeDelays: IdentifiedStorageDelays? = .default
  ) {
    self.init(
      id: \.id,
      initialValues: storage,
      timeDelays: timeDelays
    )
  }

  /// Inserts a new element in the storage, throwing an error if the element id already exists.
  ///
  /// - Parameters:
  ///   - element: The element to insert.
  @inlinable
  public func insert(_ element: Element) async throws -> Element {
    guard storage[id: element.id] == nil else {
      throw ElementExistsError(id: element.id)
    }
    self.storage[id: element.id] = element
    try await self.sleep(using: \.insert)
    return element
  }

  /// Update an element in the storage, throwing an error and runtime warning if it does not exist.
  ///
  ///  - Parameters:
  ///   - element: The element to update in the storage.
  @inlinable
  public func update(_ element: Element) async throws -> Element {
    guard storage[id: element.id] != nil else {
      XCTFail("Update called on an element that was not found in the storage. \(element.id)")
      throw ElementNotFoundError(id: element.id, ids: storage.ids)
    }
    self.storage[id: element.id] = element
    try await self.sleep(using: \.update)
    return element
  }
}

/// Convenience for declaring an ``IdentifiedStorage`` of an `Element` type.
///
public typealias IdentifiedStorageOf<Element: Identifiable> = IdentifiedStorage<Element.ID, Element>

@usableFromInline
struct ElementNotFoundError<ID: Hashable>: Error {

  @usableFromInline
  let id: ID

  @usableFromInline
  let ids: OrderedSet<ID>

  @usableFromInline
  init(id: ID, ids: OrderedSet<ID>) {
    self.id = id
    self.ids = ids
  }
}

@usableFromInline
struct ElementExistsError<ID>: Error {

  @usableFromInline
  let id: ID

  @usableFromInline
  init(id: ID) {
    self.id = id
  }
}
