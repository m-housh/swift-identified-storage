import Dependencies
import IdentifiedStorage
import XCTest

final class IdentifiedStorageTests: XCTestCase {
  
  let duration: ContinuousClock.Duration = .seconds(1)
  
  let mockTodos = IdentifiedArrayOf<Todo>(
    uniqueElements: [
      Todo(id: UUID(0), description: "Buy milk"),
      Todo(id: UUID(1), description: "Pickup blob from school."),
      Todo(id: UUID(2), description: "Walk the dog.", isComplete: false)
    ]
  )
  
  func makeStorage(useMocks: Bool = true) -> TodoClient {
    withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      TodoClient.mock(
        initialValues: useMocks ? mockTodos : [],
        timeDelays: .init(duration)
      )
    }
  }
  
  func makeIdentifiedStorage(useMocks: Bool = true) -> IdentifiedStorageOf<Todo> {
    withDependencies {
      $0.continuousClock = ImmediateClock()
    } operation: {
      .init(
        initialValues: useMocks ? mockTodos : [],
        timeDelays: .init(duration)
      )
    }
  }
   
  func testDelete() async throws {
    let storage = makeStorage()
    try await storage.delete(UUID(0))
    let fetched = try await storage.fetch()
    XCTAssertEqual(fetched, .init(uniqueElements: mockTodos.suffix(from: 1)))
  } 
  
  func testDeleteWhere() async throws {
    let storage = makeIdentifiedStorage()
    try await storage.delete { $0.isComplete == false }
    let fetched = try await storage.fetch()
    XCTAssertEqual(fetched, .init(uniqueElements: mockTodos.prefix(through: 1)))
  }
  
  func testFetch() async throws {
    let storage = makeStorage()
    let fetched = try await storage.fetch()
    XCTAssertEqual(fetched, mockTodos)
    
    let completed = try await storage.fetch(.filtered(by: .complete))
    XCTAssertEqual(
      completed,
      .init(uniqueElements: mockTodos.prefix(through: 1))
    )
    
    let inclomplete = try await storage.fetch(.filtered(by: .incomplete))
    XCTAssertEqual(
      inclomplete,
      [mockTodos.last!]
    )
   
  }
  
  func testFetchOne() async throws {
    let storage = makeIdentifiedStorage()
    let fetched = try await storage.fetchOne(id: UUID(0))
    XCTAssertNotNil(fetched)
    XCTAssertEqual(fetched, mockTodos.first!)
    
    let last = try await storage.fetchOne(request: TodoFetchOneRequest.last)
    XCTAssertNotNil(last)
    XCTAssertEqual(last, mockTodos.last!)
  }
  
  func testInsert() async throws {
    try await withDependencies {
      $0.uuid = .incrementing
    } operation: {
      let storage = makeStorage(useMocks: false)
      let inserted = try await storage.insert(.init(description: "Buy milk"))
      let fetched = try await storage.fetch()
      
      XCTAssertEqual(inserted, .init(id: UUID(0), description: "Buy milk"))
      XCTAssertEqual(fetched, [inserted])
    }
  }
  
  func testInsertAndUpdateElement() async throws {
    let storage = makeIdentifiedStorage(useMocks: false)
    var todo = try await storage.insert(.init(id: UUID(0), description: "Buy milk"))
    let fetched = try await storage.fetch()
    
    XCTAssertEqual(todo, .init(id: UUID(0), description: "Buy milk"))
    XCTAssertEqual(fetched, [todo])
    
    todo.isComplete = false
    let updated = try await storage.update(todo)
    let fetchedAfterUpdates = try await storage.fetch()
    XCTAssertEqual(updated, .init(id: UUID(0), description: "Buy milk", isComplete: false))
    XCTAssertEqual(fetchedAfterUpdates, [updated])
  }
  
  func testUpdate() async throws {
    let storage = makeStorage()
    let updated = try await storage.update(
      UUID(0),
      .init(description: "Buy milk, eggs, and flour.")
    )
    let fetched = try await storage.fetch()
    
    XCTAssertEqual(updated, .init(id: UUID(0), description: "Buy milk, eggs, and flour."))
    XCTAssertEqual(
      fetched,
      .init(uniqueElements: [updated] + mockTodos.suffix(from: 1))
    )
  }
  
  // `XCTExpectFailure` currently does not work on linux, so we exclude these tests.
  #if DEBUG && !canImport(FoundationNetworking)
  func testUpdateFailsWhenIdIsNotFound() async throws {
    let storage = makeStorage(useMocks: false)
    XCTExpectFailure()
    do {
      _ = try await storage.update(UUID(0), .init(description: "Should fail with no id's."))
      XCTFail()
    } catch {
      XCTAssert(true)
    }
  }
  
  func testUpdateElementFailsWhenIdIsNotFound() async throws {
    let storage = makeIdentifiedStorage(useMocks: false)
    XCTExpectFailure()
    do {
      _ = try await storage.update(.init(id: UUID(0), description: "Should fail with no id's."))
      XCTFail()
    } catch {
      XCTAssert(true)
    }
  }
  #endif
  
  func testStream() async throws {
    let storage = makeIdentifiedStorage()
    
    var fetched: [Todo] = []
    for try await todo in await storage.stream() {
      fetched.append(todo)
    }
    
    XCTAssertEqual(mockTodos, .init(uniqueElements: fetched))
    
    let completedStream = await storage.stream(
      request: TodoClient.FetchRequest.filtered(by: .complete)
    )
    var completed: IdentifiedArrayOf<Todo> = []
    for try await todo in completedStream {
      completed.append(todo)
    }
    XCTAssertEqual(
      completed,
      .init(uniqueElements: mockTodos.prefix(through: 1))
    )
  }
  
  func testWithValues() async throws {
    let storage = makeIdentifiedStorage()
    let second = await storage.withValues {
      $0[1]
    }
    XCTAssertEqual(second, mockTodos[1])
    
    do {
      _ = try await storage.withValues { _ in
        throw TestError()
      }
      XCTFail()
    } catch {
      XCTAssert(true)
    }
  }
}

struct TestError: Error { }
