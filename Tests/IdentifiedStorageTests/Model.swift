import Dependencies
import IdentifiedStorage
import Foundation

struct Todo: Equatable, Identifiable {
  var id: UUID
  var description: String
  var isComplete: Bool = true
}

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
  typealias ID = Todo.ID
  func transform() -> Todo {
    @Dependency(\.uuid) var uuid;
    return .init(id: uuid(), description: description)
  }
}

extension TodoClient.UpdateRequest: UpdateRequestConvertible {
  typealias ID = Todo.ID
  func apply(to state: inout Todo) {
    state.description = description
  }
}

enum TodoFetchOneRequest: FetchOneRequestConvertible {
  case first
  case last
  
  func fetchOne(from values: IdentifiedArrayOf<Todo>) -> Todo? {
    self == .first ? values.first : values.last
  }
}

extension TodoClient {
  static func mock(
    initialValues todos: [Todo],
    timeDelays: IdentifiedStorageDelays? = .default
  ) -> Self {
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
