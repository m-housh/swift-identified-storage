import Foundation
import IdentifiedCollections

/// Represents a conversion for a custom insert request for an ``IdentifiedStorage`` container.
public protocol InsertRequestConvertible<Value> {
  associatedtype Value: Identifiable
  
  /// Transform the insert request into an element that can be stored in the
  /// ``IdentifiedStorage``.
  func transform() -> Value
}

/// Represents a conversion for a custom fetch request for an ``IdentifiedStorage`` container.
public protocol FetchRequestConvertible<Value> {
  associatedtype Value: Identifiable
  
  /// Return the elements for the custom fetch request from the values in the ``IdentifiedStorage`` container.
  func fetch(from values: IdentifiedArrayOf<Value>) -> IdentifiedArrayOf<Value>
}

/// Represents a conversion for a custom fetch one request for an ``IdentifiedStorage`` container.
public protocol FetchOneRequestConvertible<Value> {
  associatedtype Value: Identifiable
  
  /// Return an element if it exists for the custom fetch one request from the values in the ``IdentifiedStorage`` contianer.
  func fetchOne(from values: IdentifiedArrayOf<Value>) -> Value?
}

/// Represents a conversion for a custom update request for an ``IdentifiedStorage`` container.
public protocol UpdateRequestConvertible<Value> {
  associatedtype Value: Identifiable
  
  /// Apply the updates to the element in the ``IdentifiedStorage`` container.
  func apply(to state: inout Value) -> Void
}
