import Testing
@testable import Server
import PostgresNIO
import Foundation

struct TeamRepositoryTests {
//  @Test
//  func create() async throws {
//    try await repoHarness { repository in
//      let testFields = RoundFields(title: "Test", order: 15)
//      let createdRound = try await repository.create(testFields)
//      #expect(createdRound.order == testFields.order)
//      #expect(createdRound.title == testFields.title)
//    }
//  }
//  
//  @Test
//  func get() async throws {
//    try await repoHarness { repository in
//      let createdRounds = try await (0..<3).asyncMap { index in
//        let testFields = RoundFields(title: "Test \(index)", order: index)
//        return try await repository.create(testFields)
//      }
//      
//      guard let firstRound = createdRounds.first else {
//        Issue.record("No rounds created")
//        return
//      }
//      
//      do {
//        guard let fetchedRound = try await repository.get(id: firstRound.id) else {
//          Issue.record("Failed to fetch round")
//          return
//        }
//        
//        #expect(fetchedRound == firstRound)
//      } catch {
//        print(String(reflecting: error))
//        Issue.record("Failed to fetch round")
//      }
//    }
//  }
//  
//  @Test
//  func getAll() async throws {
//    try await repoHarness { repository in
//      let createdRounds = try await (0..<3).asyncMap { index in
//        let testFields = RoundFields(title: "Test \(index)", order: index)
//        return try await repository.create(testFields)
//      }
//      
//      do {
//        let fetchedRounds = try await repository.getAll()
//        
//        #expect(fetchedRounds == createdRounds)
//      } catch {
//        print(String(reflecting: error))
//        Issue.record("Failed to fetch round")
//      }
//    }
//  }
//  
//  @Test
//  func update() async throws {
//    try await repoHarness { repository in
//      let createdRounds = try await (0..<3).asyncMap { index in
//        let testFields = RoundFields(title: "Test \(index)", order: index)
//        return try await repository.create(testFields)
//      }
//      
//      guard let firstRound = createdRounds.first else {
//        Issue.record("No rounds created")
//        return
//      }
//      
//      do {
//        let newRound = Round(id: firstRound.id, title: "New title", order: firstRound.order)
//        let updatedRound = try await repository.update(newRound)
//        
//        #expect(updatedRound == newRound)
//      } catch {
//        print(String(reflecting: error))
//        Issue.record("Failed to fetch round")
//      }
//    }
//  }
//  
//  @Test
//  func delete() async throws {
//    try await repoHarness { repository in
//      let createdRounds = try await (0..<3).asyncMap { index in
//        let testFields = RoundFields(title: "Test \(index)", order: index)
//        return try await repository.create(testFields)
//      }
//      
//      guard let firstRound = createdRounds.first else {
//        Issue.record("No rounds created")
//        return
//      }
//      
//      do {
//        let isDeleted = try await repository.delete(id: firstRound.id)
//        
//        #expect(isDeleted)
//        
//        let nonExistingRound: Round? = try await repository.get(id: firstRound.id)
//        #expect(nonExistingRound == nil)
//      } catch {
//        print(String(reflecting: error))
//        Issue.record("Failed to fetch round")
//      }
//    }
//  }
//  
//  @Test
//  func deleteAll() async throws {
//    try await repoHarness { repository in
//      let _ = try await (0..<3).asyncMap { index in
//        let testFields = RoundFields(title: "Test \(index)", order: index)
//        return try await repository.create(testFields)
//      }
//      
//      do {
//        try await repository.deleteAll()
//        
//        
//        let existingRounds: [Round] = try await repository.getAll()
//        #expect(existingRounds.isEmpty)
//      } catch {
//        print(String(reflecting: error))
//        Issue.record("Failed to fetch round")
//      }
//    }
//  }
  
  @Test
  func scoreZeroNoAnswers() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == 0)
    }
  }
  
  @Test
  func scoreZeroNoTeam() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let score = try await teamRepo.getScore(id: UUID())
      #expect(score == 0)
    }
  }
  
  @Test
  func scoreIncorrectAnswersZero() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let round = try await roundRepo.create(RoundFields(title: "Test round", order: 0))
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let questions = try await (0...3).asyncMap { index in
        let questionFields = QuestionFields(roundId: round.id, order: index, text: "Question \(index)", correctAnswer: "")
        return try await questionRepo.create(questionFields)
      }
      
      for question in questions {
        _ = try await answerRepo.create(AnswerFields(questionId: question.id, teamId: team.id, text: "", isCorrect: false))
      }
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == 0)
    }
  }
  
  @Test
  func scoreAllCorrect() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let round = try await roundRepo.create(RoundFields(title: "Test round", order: 0))
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let questions = try await (0...3).asyncMap { index in
        let questionFields = QuestionFields(roundId: round.id, order: index, text: "Question \(index)", correctAnswer: "")
        return try await questionRepo.create(questionFields)
      }
      
      for question in questions {
        _ = try await answerRepo.create(AnswerFields(questionId: question.id, teamId: team.id, text: "", isCorrect: true))
      }
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == questions.count)
    }
  }
  
  @Test
  func scoreMixedCorrectness() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let round = try await roundRepo.create(RoundFields(title: "Test round", order: 0))
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let questions = try await (0...3).asyncMap { index in
        let questionFields = QuestionFields(roundId: round.id, order: index, text: "Question \(index)", correctAnswer: "")
        return try await questionRepo.create(questionFields)
      }
      
      for (id, question) in questions.enumerated() {
        _ = try await answerRepo.create(AnswerFields(questionId: question.id, teamId: team.id, text: "", isCorrect: id % 2 == 0))
      }
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == 2)
    }
  }
  
  private func repoHarness(operation: @Sendable @escaping (TeamRepository, AnswerRepository, QuestionRepository, RoundRepository) async throws -> Void) async throws {
    let client = PostgresClient(
      configuration: .init(host: "localhost", username: "postgres", password: "", database: "Trivia", tls: .disable),
      backgroundLogger: Logger(label: "test-client")
    )
    let teamRepo = TeamRepository(client: client, logger: Logger(label: "test-repo"))
    let answerRepo = AnswerRepository(client: client, logger: Logger(label: "test-repo"))
    let questionRepo = QuestionRepository(client: client, logger: Logger(label: "test-repo"))
    let roundRepo = RoundRepository(client: client, logger: Logger(label: "test-repo"))
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await client.run()
      }
      
      do {
        try await teamRepo.createTable()
        try await teamRepo.deleteAll()
        
        try await roundRepo.createTable()
        try await roundRepo.deleteAll()
        
        try await questionRepo.createTable()
        try await questionRepo.deleteAll()
        
        try await answerRepo.createTable()
        try await answerRepo.deleteAll()
        
        try await operation(teamRepo, answerRepo, questionRepo, roundRepo)
        
        try await teamRepo.deleteAll()
        try await answerRepo.deleteAll()
        try await questionRepo.deleteAll()
        try await roundRepo.deleteAll()
      } catch {
        Issue.record("Failed to setup database: \(String(reflecting: error))")
        group.cancelAll()
        return
      }
      
      group.cancelAll()
    }
  }
}
