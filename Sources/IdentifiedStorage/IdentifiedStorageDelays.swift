import Foundation

/// Represents time delays that can be used for operations to simulate real life storage from a remote source.
///
public struct IdentifiedStorageDelays {

  /// The time delay used for delete operations.
  let delete: ContinuousClock.Duration

  /// The time delay used for fetch operations.
  let fetch: ContinuousClock.Duration

  /// The time delay used for insert operations.
  let insert: ContinuousClock.Duration

  /// The time delay used for update operations.
  let update: ContinuousClock.Duration

  /// Create a new time delay instance with the given durations.
  ///
  /// - Parameters:
  ///   - delete: The time delay used for delete operations.
  ///   - fetch: The time delay used for fetch operations.
  ///   - insert: The time delay used for insert operations.
  ///   - update: The time delay used for update operations.
  public init(
    delete: ContinuousClock.Duration,
    fetch: ContinuousClock.Duration,
    insert: ContinuousClock.Duration,
    update: ContinuousClock.Duration
  ) {
    self.delete = delete
    self.fetch = fetch
    self.insert = insert
    self.update = update
  }

  /// Create a new time delay instance with the given duration used for all operations.
  ///
  /// - Parameters:
  ///  - duration: The time delay used for all operations.
  public init(_ duration: ContinuousClock.Duration) {
    self.init(delete: duration, fetch: duration, insert: duration, update: duration)
  }

  /// The default time delays of `1 second`.
  public static var `default`: Self { .init(.seconds(1)) }
}
