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
    try await repoHarness { repository in
      let createdRounds = try await (0..<3).asyncMap { index in
        let testFields = RoundFields(title: "Test \(index)", order: index)
        return try await repository.create(testFields)
      }
      
      guard let firstRound = createdRounds.first else {
        Issue.record("No rounds created")
        return
      }
      
      do {
        guard let fetchedRound = try await repository.get(id: firstRound.id) else {
          Issue.record("Failed to fetch round")
          return
        }
        
        #expect(fetchedRound == firstRound)
      } catch {
        print(String(reflecting: error))
        Issue.record("Failed to fetch round")
      }
    }
  }
  
  @Test
  func getAll() async throws {
    try await repoHarness { repository in
      let createdRounds = try await (0..<3).asyncMap { index in
        let testFields = RoundFields(title: "Test \(index)", order: index)
        return try await repository.create(testFields)
      }
      
      do {
        let fetchedRounds = try await repository.getAll()
        
        #expect(fetchedRounds == createdRounds)
      } catch {
        print(String(reflecting: error))
        Issue.record("Failed to fetch round")
      }
    }
  }
  
  @Test
  func update() async throws {
    try await repoHarness { repository in
      let createdRounds = try await (0..<3).asyncMap { index in
        let testFields = RoundFields(title: "Test \(index)", order: index)
        return try await repository.create(testFields)
      }
      
      guard let firstRound = createdRounds.first else {
        Issue.record("No rounds created")
        return
      }
      
      do {
        let newRound = Round(id: firstRound.id, title: "New title", order: firstRound.order)
        let updatedRound = try await repository.update(newRound)
        
        #expect(updatedRound == newRound)
      } catch {
        print(String(reflecting: error))
        Issue.record("Failed to fetch round")
      }
    }
  }
  
  @Test
  func delete() async throws {
    try await repoHarness { repository in
      let createdRounds = try await (0..<3).asyncMap { index in
        let testFields = RoundFields(title: "Test \(index)", order: index)
        return try await repository.create(testFields)
      }
      
      guard let firstRound = createdRounds.first else {
        Issue.record("No rounds created")
        return
      }
      
      do {
        let isDeleted = try await repository.delete(id: firstRound.id)
        
        #expect(isDeleted)
        
        let nonExistingRound: Round? = try await repository.get(id: firstRound.id)
        #expect(nonExistingRound == nil)
      } catch {
        print(String(reflecting: error))
        Issue.record("Failed to fetch round")
      }
    }
  }
  
  @Test
  func deleteAll() async throws {
    try await repoHarness { repository in
      let _ = try await (0..<3).asyncMap { index in
        let testFields = RoundFields(title: "Test \(index)", order: index)
        return try await repository.create(testFields)
      }
      
      do {
        try await repository.deleteAll()
        
        
        let existingRounds: [Round] = try await repository.getAll()
        #expect(existingRounds.isEmpty)
      } catch {
        print(String(reflecting: error))
        Issue.record("Failed to fetch round")
      }
    }
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
    
    try await repo.deleteAll()
    
    clientTask.cancel()
  }
}
