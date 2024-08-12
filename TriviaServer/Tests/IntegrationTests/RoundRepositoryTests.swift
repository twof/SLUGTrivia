import Testing
@testable import Server
import PostgresNIO

struct TestRoundRepository {
  @Test
  func create() async throws {
    try await repoHarness { repository in
      let testFields = RoundFields(title: "Test", order: 15)
      let createdRound = try await repository.create(testFields)
      #expect(createdRound.order == testFields.order)
      #expect(createdRound.title == testFields.title)
    }
  }
  
  @Test
  func get() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  }
  
  @Test
  func getAll() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  }
  
  @Test
  func update() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  }
  
  @Test
  func delete() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  }
  
  @Test
  func deleteAll() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
  }
  
  private func repoHarness(operation: @Sendable @escaping (RoundRepository) async throws -> Void) async throws {
    let client = PostgresClient(
      configuration: .init(host: "localhost", username: "postgres", password: "", database: "Trivia", tls: .disable),
      backgroundLogger: Logger(label: "test-client")
    )
    
    let repo = RoundRepository(client: client, logger: Logger(label: "test-repo"))
    
    let clientTask = Task {
      await client.run()
    }
    
    try await repo.createTable()
    try await repo.deleteAll()

    try await operation(repo)
    
    clientTask.cancel()
    
//    try await withThrowingTaskGroup(of: Void.self) { group in
//      let repo = RoundRepository(client: client, logger: Logger(label: "test-repo"))
//      group.addTask {
//        await client.run()
//      }
//      
//      try await repo.createTable()
//      try await repo.deleteAll()
//      
//      try await operation(repo)
//      
//      for try await _ in group {
//        group.cancelAll()
//      }
//    }
  }
}
